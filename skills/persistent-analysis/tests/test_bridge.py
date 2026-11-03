"""Integration tests: run through Slurm; synthetic objects only, no existing workers/jobs."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
CORE = Path(__file__).resolve().parents[1] / 'scripts/persistent_analysis.py'
spec = importlib.util.spec_from_file_location('persistent_analysis', CORE)
pa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pa)


class WorkerTests:
    language = None

    def setUp(self):
        if not os.environ.get('SLURM_JOB_ID'):
            self.skipTest('Run integration tests inside Slurm')
        self.tmp = tempfile.TemporaryDirectory(prefix='persistent-analysis-test-')
        self.directory = Path(self.tmp.name)
        self.root = self.directory / 'sessions'
        self.session = pa.prepare(self.root, 'test', self.language, self.directory)
        suffix = 'R' if self.language == 'r' else 'py'
        (self.session / ('init.' + suffix)).write_text('initial_value <- 40\n' if self.language == 'r' else 'initial_value = 40\n')
        self.log = (self.directory / 'worker.log').open('w')
        self.worker = subprocess.Popen([sys.executable, str(CORE), '_worker', str(self.session)],
                                       stdout=self.log, stderr=self.log)
        self.await_ready()

    def tearDown(self):
        if not hasattr(self, 'worker'):
            return
        (self.session / 'stop-requested').touch()
        try:
            self.worker.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.worker.kill()  # Only this test's interpreter; never scancel any Slurm job.
            self.worker.wait(timeout=5)
        # Allow the isolated monitor to observe the interpreter exit before removing fixtures.
        time.sleep(2.2)
        self.log.close()
        self.tmp.cleanup()

    def await_ready(self):
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline:
            if pa.read(self.session / 'worker.json')['state'] == 'ready':
                return
            if self.worker.poll() is not None:
                self.fail((self.directory / 'worker.log').read_text())
            time.sleep(0.2)
        self.fail('Worker did not become ready')

    def code(self, r, python):
        return r if self.language == 'r' else python

    def run_code(self, code, timeout=15):
        task = pa.submit(self.session, code)
        return pa.wait(self.session, task, timeout)

    def test_initialization_expression_and_persistence(self):
        pid = pa.status(self.session)['pid']
        first = self.run_code(self.code('answer <- initial_value + 2; answer', 'answer = initial_value + 2\nanswer'))
        self.assertEqual(first['state'], 'successful', first)
        self.assertIn('42', first['stdout'])
        second = self.run_code('answer')
        self.assertEqual(second['state'], 'successful', second)
        self.assertIn('42', second['stdout'])
        self.assertEqual(pa.status(self.session)['pid'], pid)
        self.assertTrue((self.session / 'runtime.txt').read_text())

    def test_independent_cli_calls(self):
        prefix = [sys.executable, str(CORE), '--root', str(self.root), '--session', 'test']
        first = subprocess.run(prefix + ['eval', self.code('cli_value <- 91', 'cli_value = 91')], capture_output=True, text=True, timeout=20)
        self.assertEqual(first.returncode, 0, first.stderr)
        second = subprocess.run(prefix + ['eval', 'cli_value'], capture_output=True, text=True, timeout=20)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn('91', json.loads(second.stdout)['stdout'])

    def test_error_recovery_and_partial_mutation(self):
        failed = self.run_code(self.code('survives <- 7; stop("synthetic-error")', 'survives = 7\nraise ValueError("synthetic-error")'))
        self.assertEqual(failed['state'], 'failed', failed)
        self.assertIn('synthetic-error', failed['stderr'])
        recovered = self.run_code('survives')
        self.assertEqual(recovered['state'], 'successful', recovered)
        self.assertIn('7', recovered['stdout'])

    def test_warnings_messages_and_logs(self):
        output = self.run_code(self.code('cat("output-line\\n"); message("message-line"); warning("warning-line")',
                                        'import sys, warnings\nprint("output-line")\nprint("message-line", file=sys.stderr)\nwarnings.warn("warning-line")'))
        self.assertEqual(output['state'], 'successful', output)
        self.assertIn('output-line', output['stdout'])
        self.assertIn('message-line', output['stderr'])
        self.assertIn('warning-line', output['stderr'])

    def test_sequential_and_no_duplicate_replay(self):
        first = pa.submit(self.session, self.code('Sys.sleep(1); sequence <- c(1)', 'import time\ntime.sleep(1)\nsequence = [1]'))
        second = pa.submit(self.session, self.code('sequence <- c(sequence, 2); sequence', 'sequence.append(2)\nsequence'))
        one, two = pa.wait(self.session, first, 15), pa.wait(self.session, second, 15)
        self.assertEqual(one['state'], 'successful', one)
        self.assertEqual(two['state'], 'successful', two)
        self.assertLessEqual(one['finished'], two['started'])
        self.assertIn('2', two['stdout'])
        self.assertIsNone(pa.claim(self.session))
        state = pa.read(self.session / 'worker.json')
        duplicate = subprocess.run([sys.executable, str(CORE), '_worker', str(self.session)], capture_output=True, text=True, timeout=10)
        self.assertNotEqual(duplicate.returncode, 0)
        self.assertEqual(pa.read(self.session / 'worker.json')['pid'], state['pid'])

    def test_timeout_leaves_calculation_running(self):
        task = pa.submit(self.session, self.code('Sys.sleep(3); finished_later <- TRUE', 'import time\ntime.sleep(3)\nfinished_later = True'))
        early = pa.wait(self.session, task, 0.1)
        self.assertTrue(early['wait_timed_out'])
        self.assertIn(early['state'], {'queued', 'running'})
        self.assertEqual(pa.status(self.session)['state'], 'ready')
        self.assertEqual(pa.wait(self.session, task, 15)['state'], 'successful')

    def test_file_paths_inventory_and_bounded_output(self):
        output = self.run_code(self.code('writeLines("result", "out.txt"); persistent_paths("out.txt"); cat(paste(rep("x", 20000), collapse=""))',
                                        'from pathlib import Path\nPath("out.txt").write_text("result")\npersistent_paths("out.txt")\nprint("x" * 20000)'))
        self.assertEqual(output['state'], 'successful', output)
        self.assertEqual(output['files'], [str(self.directory / 'out.txt')])
        self.assertIn('[truncated;', output['stdout'])
        inventory = self.run_code(pa.R_OBJECTS if self.language == 'r' else pa.PY_OBJECTS)
        self.assertIn('initial_value', inventory['stdout'])
        self.assertEqual(inventory['state'], 'successful', inventory)
        path = pa.task_path(self.session, output['task_id'])
        self.assertEqual((path / 'state.json').stat().st_mode & 0o777, 0o600)

    def test_worker_death_and_allocation_end(self):
        task = pa.submit(self.session, self.code('Sys.sleep(60)', 'import time\ntime.sleep(60)'))
        deadline = time.monotonic() + 10
        while pa.result(self.session, task)['state'] == 'queued' and time.monotonic() < deadline:
            time.sleep(0.1)
        self.assertEqual(pa.result(self.session, task)['state'], 'running')
        self.worker.kill()
        self.worker.wait(timeout=5)
        time.sleep(2.2)
        self.assertEqual(pa.status(self.session)['state'], 'terminated')
        self.assertEqual(pa.result(self.session, task)['state'], 'interrupted')
        self.assertIsNone(pa.claim(self.session))
        with self.assertRaises(ValueError):
            pa.submit(self.session, '1')

    def test_scheduler_expiration_detection(self):
        with patch.object(pa.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '', '')):
            self.assertEqual(pa.status(self.session)['state'], 'allocation-ended')
        with patch.object(pa.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'Invalid job id specified')):
            self.assertEqual(pa.status(self.session)['state'], 'allocation-ended')

    def test_existing_session_keeps_preloaded_objects_and_returns_control(self):
        # Stop only the dedicated fixture worker, then attach a fresh simulated manual REPL.
        (self.session / 'stop-requested').touch()
        self.worker.wait(timeout=10)
        session = pa.prepare(self.root, 'manual', self.language, self.directory)
        if self.language == 'python':
            source = 'import runpy\npreloaded = [1,2,3]\nns=globals()\nrunpy.run_path(' + repr(str(CORE)) + ')["serve_python"](' + repr(str(session)) + ', ns)\nassert preloaded == [1,2,3]\nopen(' + repr(str(self.directory / 'returned')) + ',"w").write("returned")'
            command = [sys.executable, '-c', source]
        else:
            worker_r = CORE.parent.parent / 'worker/worker.R'
            source = 'preloaded <- c(1,2,3); source(' + json.dumps(str(worker_r)) + '); persistent_serve(' + json.dumps(str(session)) + '); stopifnot(identical(preloaded,c(1,2,3))); writeLines("returned",' + json.dumps(str(self.directory / 'returned')) + ')'
            command = ['Rscript', '-e', source]
        manual = subprocess.Popen(command, stdout=self.log, stderr=self.log)
        try:
            deadline = time.monotonic() + 15
            while pa.read(session / 'worker.json')['state'] != 'ready' and time.monotonic() < deadline:
                time.sleep(0.2)
            data = pa.wait(session, pa.submit(session, 'preloaded'), 10)
            self.assertEqual(data['state'], 'successful', data)
            self.assertIn('3', data['stdout'])
            (session / 'stop-requested').touch()
            self.assertEqual(manual.wait(timeout=10), 0)
            self.assertEqual((self.directory / 'returned').read_text().strip(), 'returned')
        finally:
            if manual.poll() is None:
                manual.kill()
                manual.wait()
            time.sleep(2.2)


class PythonTests(WorkerTests, unittest.TestCase):
    language = 'python'

    def test_heartbeat_during_long_running_code(self):
        task = pa.submit(self.session, 'import time\ntime.sleep(15)\nlong_result = 88')
        time.sleep(13)
        state = pa.status(self.session)
        self.assertEqual(state['state'], 'ready', state)
        self.assertLess(state['heartbeat_age_seconds'], 5)
        self.assertEqual(state['active_task'], task)
        self.assertEqual(pa.wait(self.session, task, 10)['state'], 'successful')


@unittest.skipUnless(shutil.which('Rscript'), 'Rscript unavailable')
class RTests(WorkerTests, unittest.TestCase):
    language = 'r'

    def test_synthetic_seurat_and_png(self):
        code = '''
if (!requireNamespace("Seurat", quietly=TRUE)) stop("Seurat unavailable")
set.seed(12)
counts <- matrix(rpois(20L * 12L, lambda=5), nrow=20L,
                 dimnames=list(paste0("gene",1:20), paste0("cell",1:12)))
toy <- Seurat::CreateSeuratObject(counts)
toy <- Seurat::NormalizeData(toy, verbose=FALSE)
SeuratObject::Idents(toy) <- factor(rep(c("3","5"), each=6))
markers <- Seurat::FindMarkers(toy, ident.1="3", ident.2="5", min.pct=0,
                               logfc.threshold=0, test.use="wilcox", verbose=FALSE)
write.csv(markers, "markers.csv")
local({
    grDevices::png("synthetic.png", width=400, height=400)
    tryCatch(plot(1:3, 1:3), finally=grDevices::dev.off())
})
persistent_paths("markers.csv", "synthetic.png")
'''
        output = self.run_code(code, timeout=60)
        self.assertEqual(output['state'], 'successful', output)
        pid = pa.status(self.session)['pid']
        check = self.run_code('stopifnot(inherits(toy, "Seurat"), is.data.frame(markers)); dim(markers)')
        self.assertEqual(check['state'], 'successful', check)
        self.assertEqual(pa.status(self.session)['pid'], pid)
        self.assertTrue((self.directory / 'synthetic.png').read_bytes().startswith(b'\x89PNG'))
        self.assertEqual(len(output['files']), 2)


class ProtocolTests(unittest.TestCase):
    def test_private_root_and_traversal(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work) / 'sessions'
            root.mkdir(mode=0o777)
            root.chmod(0o777)
            with self.assertRaises(ValueError):
                pa.prepare(root, 'test', 'python', work)
            with self.assertRaises(ValueError):
                pa.prepare(Path(work) / 'safe', '../escape', 'python', work)

    def test_no_worker_outside_slurm(self):
        with tempfile.TemporaryDirectory() as work:
            session = pa.prepare(Path(work) / 'sessions', 'test', 'python', work)
            environment = dict(os.environ)
            environment.pop('SLURM_JOB_ID', None)
            result = subprocess.run([sys.executable, str(CORE), '_worker', str(session)], env=environment, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((session / 'worker-claimed').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
