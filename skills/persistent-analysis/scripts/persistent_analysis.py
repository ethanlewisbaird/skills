#!/usr/bin/env python3
"""Private shared-filesystem execution queue for persistent Slurm R/Python interpreters."""
import argparse
import ast
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import socket
import subprocess
import sys
import tempfile
import time
import traceback
import uuid

BASE = Path(__file__).resolve().parent.parent
TERMINAL = {'successful', 'failed'}
NAME = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$')
TASK = re.compile(r'^\d{20}-[a-f0-9]{32}$')


def private(path, create=False):
    path = Path(path).absolute()
    if create:
        path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.is_symlink() or path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o077:
        raise ValueError('Execution directories must be user-owned, non-symlinked and mode 700: ' + str(path))
    return path


def atomic(path, value):
    """Same-filesystem replacement; readers see an old or complete new JSON document."""
    path = Path(path)
    name = None
    try:
        with tempfile.NamedTemporaryFile('w', dir=path.parent, prefix='.write-', delete=False) as stream:
            name = stream.name
            os.chmod(name, 0o600)
            json.dump(value, stream)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        name = None
    finally:
        if name is not None:
            Path(name).unlink(missing_ok=True)


def read(path):
    return json.loads(Path(path).read_text())


def prepare(root, name, language, project, init=None):
    if not NAME.fullmatch(name):
        raise ValueError('Session name must be 1–80 letters/digits/underscores/hyphens')
    root = private(root, create=True)
    session = root / name
    session.mkdir(mode=0o700)  # Never reset or silently reuse a previous interpreter generation.
    for folder in ('queue', 'tasks'):
        (session / folder).mkdir(mode=0o700)
    project = Path(project).resolve(strict=True)
    if not project.is_dir():
        raise ValueError('Project must be a directory')
    metadata = dict(name=name, language=language, project=str(project), created=time.time())
    if init:
        source = Path(init).resolve(strict=True)
        destination = session / ('init.R' if language == 'r' else 'init.py')
        destination.write_bytes(source.read_bytes())
        destination.chmod(0o600)
        metadata['init_source'] = str(source)
        metadata['init_sha256'] = hashlib.sha256(destination.read_bytes()).hexdigest()
    (session / 'project.txt').write_text(str(project))
    (session / 'language.txt').write_text(language)
    (session / 'bridge.txt').write_text(str(Path(__file__).resolve()))
    atomic(session / 'session.json', metadata)
    atomic(session / 'worker.json', {'state': 'prepared'})
    return session


def begin(session, pid):
    session = private(session)
    if not os.environ.get('SLURM_JOB_ID'):
        raise ValueError('Workers must run inside a Slurm allocation; refusing login-node execution')
    (session / 'worker-claimed').mkdir(mode=0o700)  # One worker ever per generation, even after crash.
    info = dict(state='initializing', pid=int(pid), host=socket.gethostname(),
                job_id=os.environ['SLURM_JOB_ID'], started=time.time(),
                python_executable=sys.executable, conda_prefix=os.environ.get('CONDA_PREFIX'),
                cpus_per_task=os.environ.get('SLURM_CPUS_PER_TASK'),
                memory_per_node_mb=os.environ.get('SLURM_MEM_PER_NODE'))
    atomic(session / 'worker.json', info)
    atomic(session / 'heartbeat.json', {'at': time.time()})
    subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '_monitor', str(session), str(pid)],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


def set_worker(session, state):
    info = read(session / 'worker.json')
    info.update(state=state, changed=time.time())
    atomic(session / 'worker.json', info)


def process_identity(pid):
    try:
        # Linux /proc: field 22 is process start time; distinguish PID reuse and zombies.
        fields = Path('/proc/' + str(pid) + '/stat').read_text().rsplit(')', 1)[1].split()
        return None if fields[0] == 'Z' else fields[19]
    except FileNotFoundError:
        return None


def monitor(session, pid):
    identity = process_identity(pid)
    while identity is not None and process_identity(pid) == identity:
        atomic(session / 'heartbeat.json', {'at': time.time()})
        time.sleep(2)
    info = read(session / 'worker.json')
    if info['state'] not in {'stopped', 'failed'}:
        info.update(state='terminated', changed=time.time())
        atomic(session / 'worker.json', info)


def status(session):
    private(session)
    launch_info = read(session / 'launch.json') if (session / 'launch.json').exists() else {}
    info = {**read(session / 'session.json'), **launch_info, **read(session / 'worker.json')}
    if info['state'] == 'prepared' and info.get('submitted_job_id'):
        info['job_id'] = info['submitted_job_id']
    if info['state'] in {'initializing', 'ready'} or (info['state'] == 'prepared' and info.get('job_id')):
        # Check scheduler even with a recent heartbeat: the entire allocation can end abruptly.
        try:
            result = subprocess.run(['squeue', '-h', '-j', str(info['job_id']), '-o', '%T'],
                                    capture_output=True, text=True, timeout=5)
            if result.returncode == 0 and not result.stdout.strip():
                info['state'] = 'allocation-ended'
            elif result.returncode == 0:
                info['slurm_state'] = result.stdout.strip()
                if info['state'] == 'prepared':
                    info['state'] = 'allocation-pending' if 'PENDING' in result.stdout else 'starting'
            elif 'invalid job id' in result.stderr.lower():
                info['state'] = 'allocation-ended'
            else:
                info['scheduler_check'] = 'unavailable'
        except (OSError, subprocess.TimeoutExpired):
            info['scheduler_check'] = 'unavailable'
        if (session / 'heartbeat.json').exists():
            heartbeat = read(session / 'heartbeat.json')['at']
            info['heartbeat_age_seconds'] = round(time.time() - heartbeat, 1)
            if info['state'] in {'initializing', 'ready'} and time.time() - heartbeat > 12:
                info['state'] = 'unresponsive'
    try:
        info['active_task'] = read(session / 'active.json')['task_id']
    except FileNotFoundError:
        pass  # Task completion removes this advisory pointer atomically.
    info['session_directory'] = str(session)
    return info


def available(session):
    info = status(session)
    if info['state'] != 'ready':
        raise ValueError('Worker unavailable (' + info['state'] + '); no job or object reload was started')
    if (session / 'stop-requested').exists():
        raise ValueError('Worker shutdown requested; refusing new work')
    return info


def submit(session, code, original=None):
    info = available(session)
    task_id = f'{time.time_ns():020d}-' + uuid.uuid4().hex
    staging = Path(tempfile.mkdtemp(prefix='.submit-', dir=session))
    try:
        extension = '.R' if info['language'] == 'r' else '.py'
        (staging / ('code' + extension)).write_text(code)
        for filename in ('stdout.txt', 'stderr.txt', 'paths.txt'):
            (staging / filename).touch(mode=0o600)
        (staging / 'cwd.txt').write_text(info['project'])
        atomic(staging / 'state.json', dict(task_id=task_id, state='queued', submitted=time.time(),
                                          source=original, sha256=hashlib.sha256(code.encode()).hexdigest()))
        for file in staging.iterdir():
            file.chmod(0o600)
        staging.rename(session / 'queue' / task_id)
    finally:
        if staging.exists():
            import shutil
            shutil.rmtree(staging)
    return task_id


def claim(session):
    if (session / 'stop-requested').exists():
        return None
    for path in sorted((session / 'queue').iterdir()):
        if not TASK.fullmatch(path.name) or path.is_symlink():
            continue
        destination = session / 'tasks' / path.name
        try:
            path.rename(destination)  # Claimed tasks are NEVER automatically requeued.
        except FileNotFoundError:
            continue
        metadata = read(destination / 'state.json')
        metadata.update(state='running', started=time.time())
        atomic(destination / 'state.json', metadata)
        atomic(session / 'active.json', {'task_id': path.name})
        return destination
    return None


def finish(task, state):
    metadata = read(task / 'state.json')
    metadata.update(state=state, finished=time.time())
    atomic(task / 'state.json', metadata)
    active = task.parent.parent / 'active.json'
    if active.exists() and read(active)['task_id'] == task.name:
        active.unlink()


def task_path(session, task_id):
    if not TASK.fullmatch(task_id):
        raise ValueError('Invalid task ID')
    for parent in ('queue', 'tasks'):
        path = session / parent / task_id
        if path.is_dir() and not path.is_symlink():
            return path
    raise ValueError('Unknown task ID for this session')


def limited(path, limit=16384):
    with path.open('rb') as stream:
        data = stream.read(limit)
    text = data.decode(errors='replace')
    if path.stat().st_size > limit:
        text += '\n[truncated; full output: ' + str(path) + ']'
    return text


def _result(session, task_id, include_logs=True):
    path = task_path(session, task_id)
    data = read(path / 'state.json')
    if data['state'] not in TERMINAL:
        worker = status(session)
        if worker['state'] in {'stopped', 'failed', 'terminated', 'allocation-ended'}:
            data['execution_state'] = data['state']
            data['state'] = 'interrupted' if data['state'] == 'running' else 'not-executed'
            data['worker_state'] = worker['state']
        elif worker['state'] == 'unresponsive':
            data['worker_state'] = 'unresponsive'  # Do not assert a long-running task has failed.
    data['task_directory'] = str(path)
    data['files'] = (path / 'paths.txt').read_text().splitlines()
    if include_logs:
        data['stdout'] = limited(path / 'stdout.txt')
        data['stderr'] = limited(path / 'stderr.txt')
    return data


def result(session, task_id, include_logs=True):
    # A queued directory can move to tasks/ between any two reads. It moves only once.
    try:
        return _result(session, task_id, include_logs)
    except FileNotFoundError:
        return _result(session, task_id, include_logs)


def wait(session, task_id, timeout):
    deadline = time.monotonic() + timeout
    while True:
        data = result(session, task_id)
        if data['state'] in TERMINAL | {'interrupted', 'not-executed'}:
            return data
        if time.monotonic() >= deadline:
            data['wait_timed_out'] = True
            return data
        time.sleep(min(1, max(0, deadline - time.monotonic())))


@contextlib.contextmanager
def capture(task):
    """Capture Python and native file-descriptor output, restoring the existing REPL afterward."""
    sys.stdout.flush()
    sys.stderr.flush()
    saved = os.dup(1), os.dup(2)
    try:
        with (task / 'stdout.txt').open('w', buffering=1) as out, (task / 'stderr.txt').open('w', buffering=1) as err:
            os.dup2(out.fileno(), 1)
            os.dup2(err.fileno(), 2)
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                yield
    finally:
        os.dup2(saved[0], 1)
        os.dup2(saved[1], 2)
        os.close(saved[0])
        os.close(saved[1])


def execute_python(code, filename, namespace):
    tree = ast.parse(code, filename=filename)
    if tree.body and isinstance(tree.body[-1], ast.Expr):
        last = tree.body.pop()
        exec(compile(tree, filename, 'exec'), namespace, namespace)
        value = eval(compile(ast.Expression(last.value), filename, 'eval'), namespace, namespace)
        if value is not None:
            print(repr(value))
    else:
        exec(compile(tree, filename, 'exec'), namespace, namespace)


def serve_python(session, namespace=None, initialize=False):
    """Call from Python/IPython with globals() to reuse the caller's exact object namespace."""
    session = private(session)
    if read(session / 'session.json')['language'] != 'python':
        raise ValueError('Session is not configured for Python')
    namespace = namespace if namespace is not None else {'__name__': '__main__'}
    if 'persistent_paths' in namespace:
        raise ValueError('The name persistent_paths is reserved; rename it before attaching')
    begin(session, os.getpid())
    old_cwd = Path.cwd()
    active = None
    try:
        os.chdir(read(session / 'session.json')['project'])
        if initialize and (session / 'init.py').exists():
            exec(compile((session / 'init.py').read_text(), str(session / 'init.py'), 'exec'), namespace, namespace)
        runtime = session / 'runtime.txt'
        runtime.write_text(sys.version + '\n' + sys.executable + '\n' + sys.prefix + '\n')
        runtime.chmod(0o600)
        set_worker(session, 'ready')
        while not (session / 'stop-requested').exists():
            active = claim(session)
            if active is None:
                time.sleep(1)
                continue
            def paths(*files):
                with (active / 'paths.txt').open('a') as stream:
                    for file in files:
                        stream.write(str(Path(file).resolve(strict=True)) + '\n')
            namespace['persistent_paths'] = paths
            os.chdir((active / 'cwd.txt').read_text())
            outcome = 'successful'
            with capture(active):
                try:
                    execute_python((active / 'code.py').read_text(), str(active / 'code.py'), namespace)
                except Exception:
                    traceback.print_exc()
                    outcome = 'failed'
            finish(active, outcome)
            active = None
    except KeyboardInterrupt:
        if active is not None:
            finish(active, 'failed')
    except BaseException:
        set_worker(session, 'failed')
        raise
    finally:
        namespace.pop('persistent_paths', None)
        os.chdir(old_cwd)
        if read(session / 'worker.json')['state'] != 'failed':
            set_worker(session, 'stopped')


R_OBJECTS = '''local({
  nms <- setdiff(ls(.GlobalEnv), "persistent_paths")
  for (nm in head(nms, 200L)) {
    x <- get(nm, .GlobalEnv)
    d <- tryCatch(paste(dim(x), collapse=" x "), error=function(e) "unknown")
    cat(nm, paste(class(x), collapse=","), d, sep="\\t"); cat("\\n")
  }
})'''
PY_OBJECTS = '''def _persistent_inventory():
    import types
    for name, value in list(globals().items()):
        if name.startswith("_") or name == "persistent_paths" or isinstance(value, types.ModuleType) or callable(value):
            continue
        print(name, type(value).__name__, getattr(value, "shape", ""), sep="\\t")
_persistent_inventory()
del _persistent_inventory
'''


def bootstrap(session):
    if read(session / 'session.json')['language'] == 'r':
        return 'source(' + json.dumps(str(BASE / 'worker/worker.R')) + '); persistent_serve(' + json.dumps(str(session)) + ')'
    return 'import runpy; runpy.run_path(' + repr(str(Path(__file__).resolve())) + ')["serve_python"](' + repr(str(session)) + ', globals())'


def launch(args, session):
    command = ['--ntasks=1', '--cpus-per-task=' + str(args.cpus), '--mem=' + args.mem,
               '--time=' + args.time, '--job-name=pa-' + args.session]
    if args.partition:
        command.append('--partition=' + args.partition)
    script = str(BASE / 'slurm/start-worker.sbatch')
    arguments = [script, str(session), str(Path(args.env_script).resolve(strict=True)) if args.env_script else '', str(BASE)]
    if args.launcher == 'sbatch':
        output = subprocess.check_output(['sbatch', '--parsable', '--no-requeue', '--output=' + str(session / 'startup.log'),
                                          *command, *arguments], text=True).strip()
        record = {'launcher': 'sbatch', 'submitted_job_id': output.split(';')[0]}
        atomic(session / 'launch.json', record)
        print(json.dumps({'session': str(session), **record}))
    else:
        # The multiplexer lives on the login node; only srun's interpreter lives on the compute node.
        shell = shlex.join(['srun', *command, *arguments]) + ' > ' + shlex.quote(str(session / 'startup.log')) + ' 2>&1'
        title = 'pa-' + args.session
        mux = ['tmux', '-L', 'persistent-analysis', '-f', '/dev/null', 'new-session', '-d', '-s', title, shell] if args.launcher == 'tmux' else ['screen', '-dmS', title, 'bash', '-c', shell]
        subprocess.run(mux, check=True)
        record = {'launcher': args.launcher, 'terminal_session': title}
        atomic(session / 'launch.json', record)
        print(json.dumps({'session': str(session), **record}))


def main():
    # Private internal commands are used by the R worker; no user R data goes through JSON.
    if len(sys.argv) > 1 and sys.argv[1].startswith('_'):
        command, session = sys.argv[1], private(Path(sys.argv[2]))
        if command == '_monitor':
            monitor(session, int(sys.argv[3]))
        elif command == '_begin':
            begin(session, int(sys.argv[3]))
        elif command == '_ready':
            set_worker(session, 'ready')
        elif command in {'_stopped', '_failed'}:
            set_worker(session, command[1:])
        elif command == '_claim':
            path = claim(session)
            print(str(path) if path else '')
        elif command == '_finish':
            finish(Path(sys.argv[3]), sys.argv[4])
        elif command == '_worker':
            language = read(session / 'session.json')['language']
            if language == 'python':
                serve_python(session, initialize=True)
            else:
                os.execvp('Rscript', ['Rscript', str(BASE / 'worker/worker.R'), str(session), sys.executable])
        else:
            raise ValueError('Unknown internal command')
        return 0
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(os.environ.get('PERSISTENT_ANALYSIS_ROOT', str(Path.home() / '.local/state/persistent-analysis'))))
    parser.add_argument('--session', default=os.environ.get('PERSISTENT_ANALYSIS_SESSION'))
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('prepare', 'start'):
        p = sub.add_parser(name)
        p.add_argument('--language', choices=('r', 'python'), required=True)
        p.add_argument('--project', type=Path, default=Path.cwd())
        p.add_argument('--init', type=Path)
        if name == 'start':
            p.add_argument('--launcher', choices=('tmux', 'screen', 'sbatch'), required=True)
            p.add_argument('--mem', required=True)
            p.add_argument('--time', required=True)
            p.add_argument('--cpus', type=int, default=1)
            p.add_argument('--partition')
            p.add_argument('--env-script', type=Path)
    for name in ('status', 'objects', 'shutdown', 'list'):
        p = sub.add_parser(name)
        if name == 'shutdown':
            p.add_argument('--confirm', action='store_true', required=True)
        if name == 'objects':
            p.add_argument('--timeout', type=float, default=30)
    for name in ('eval', 'run', 'submit', 'result', 'logs'):
        p = sub.add_parser(name)
        p.add_argument('value')
        if name in {'eval', 'run', 'result'}:
            p.add_argument('--timeout', type=float, default=30 if name != 'result' else 0)
    args = parser.parse_args()
    if args.command == 'list':
        if args.root.exists():
            private(args.root)
            print(json.dumps([status(path) for path in sorted(args.root.iterdir()) if (path / 'session.json').exists()], indent=2))
        else:
            print('[]')
        return 0
    if not args.session or not NAME.fullmatch(args.session):
        raise ValueError('Select a session explicitly with --session NAME or PERSISTENT_ANALYSIS_SESSION; use list to discover')
    session = args.root.absolute() / args.session
    if args.command in {'prepare', 'start'}:
        if args.command == 'prepare' and args.init:
            raise ValueError('Existing-session bootstrap never initializes/reloads objects; use start --init for new workers')
        if args.command == 'start':
            if not re.fullmatch(r'[1-9]\d*(?:[KMGTP])', args.mem, re.I) or args.cpus < 1:
                raise ValueError('Use positive CPUs and explicit memory units, for example 8G (not 64)')
        session = prepare(args.root, args.session, args.language, args.project, args.init)
        if args.command == 'prepare':
            print(json.dumps({'session_directory': str(session), 'bootstrap': bootstrap(session)}, indent=2))
        else:
            launch(args, session)
        return 0
    private(session)
    if args.command == 'status':
        print(json.dumps(status(session), indent=2))
        return 0
    if args.command == 'shutdown':
        (session / 'stop-requested').touch(mode=0o600)
        print('Graceful stop requested; current task finishes, then the bridge returns to its caller. No scancel was issued.')
        return 0
    if args.command == 'logs':
        data = result(session, args.value)
    elif args.command == 'result':
        data = wait(session, args.value, args.timeout) if args.timeout > 0 else result(session, args.value)
    else:
        if args.command == 'objects':
            language = read(session / 'session.json')['language']
            code = R_OBJECTS if language == 'r' else PY_OBJECTS
            original = '<inventory>'
        elif args.command == 'eval':
            code, original = args.value, '<expression>'
        else:
            source = Path(args.value).resolve(strict=True)
            code, original = source.read_text(), str(source)
        task_id = submit(session, code, original)
        if args.command == 'submit':
            print(json.dumps({'task_id': task_id, 'state': 'queued', 'session': args.session}))
            return 0
        print('Submitted task ' + task_id, file=sys.stderr, flush=True)
        data = wait(session, task_id, args.timeout)
    print(json.dumps(data, indent=2))
    if data.get('wait_timed_out'):
        return 124
    return 0 if data['state'] == 'successful' else 1


if __name__ == '__main__':
    os.umask(0o077)
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('persistent-analysis: ' + str(error), file=sys.stderr)
        sys.exit(2)
