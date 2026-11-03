"""Login-node orchestration only: each test creates its OWN short Slurm allocation."""
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import time
import unittest

BASE = Path(__file__).resolve().parents[1]
CLI = BASE / 'bin/persistent-analysis'


class LauncherTests(unittest.TestCase):
    def test_explicit_slurm_launchers(self):
        if os.environ.get('SLURM_JOB_ID'):
            self.skipTest('Run from login node, not inside an existing allocation')
        # Must be visible on both login and compute nodes: never use login-node /tmp.
        with tempfile.TemporaryDirectory(prefix='.persistent-analysis-launch-', dir=Path.home()) as work:
            root = Path(work) / 'sessions'
            env = {key: value for key, value in os.environ.items() if not key.startswith('SLURM_')}
            prefix = [sys.executable, str(CLI), '--root', str(root)]
            for launcher in ('tmux', 'screen'):
                with self.subTest(launcher=launcher):
                    if not shutil.which(launcher):
                        self.skipTest(launcher + ' unavailable')
                    name = 'test-' + launcher
                    selected = prefix + ['--session', name]
                    launched = subprocess.run(selected + ['start', '--language', 'python', '--project', work,
                                                           '--launcher', launcher, '--mem', '1G', '--time', '00:02:00',
                                                           '--cpus', '1', '--partition', os.environ.get('PERSISTENT_TEST_PARTITION', 'fast')],
                                              env=env, capture_output=True, text=True, timeout=20)
                    self.assertEqual(launched.returncode, 0, launched.stderr)
                    session = root / name
                    recorded = json.loads((session / 'launch.json').read_text())
                    self.assertEqual(recorded['launcher'], launcher)
                    expected_monitor = ['tmux', '-L', 'persistent-analysis', 'attach', '-t', 'pa-' + name] if launcher == 'tmux' else ['screen', '-r', 'pa-' + name]
                    self.assertEqual(shlex.split(recorded['monitor_command']), expected_monitor)
                    self.assertEqual(json.loads(launched.stdout)['monitor_command'], recorded['monitor_command'])
                    try:
                        deadline = time.monotonic() + 60
                        while time.monotonic() < deadline:
                            state = json.loads((session / 'worker.json').read_text())
                            if state['state'] == 'ready':
                                break
                            time.sleep(1)
                        else:
                            self.fail('Startup failed: ' + (session / 'startup.log').read_text())
                        result = subprocess.run(selected + ['eval', 'retained = 123\nretained'], env=env, capture_output=True, text=True, timeout=35)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertIn('123', json.loads(result.stdout)['stdout'])
                        again = subprocess.run(selected + ['eval', 'retained'], env=env, capture_output=True, text=True, timeout=35)
                        self.assertEqual(again.returncode, 0, again.stderr)
                        self.assertIn('123', json.loads(again.stdout)['stdout'])
                    finally:
                        # Graceful queue stop, not scancel: does not touch any pre-existing allocation.
                        subprocess.run(selected + ['shutdown', '--confirm'], env=env, capture_output=True, text=True)
                        deadline = time.monotonic() + 15
                        while time.monotonic() < deadline:
                            state = json.loads((session / 'worker.json').read_text())
                            if state['state'] in {'stopped', 'terminated', 'failed'}:
                                break
                            time.sleep(0.5)
                        self.assertEqual(state['state'], 'stopped', state)
                        job = state['job_id']
                        deadline = time.monotonic() + 15
                        while time.monotonic() < deadline:
                            check = subprocess.run(['squeue', '-h', '-j', job], capture_output=True, text=True)
                            if not check.stdout.strip():
                                break
                            time.sleep(0.5)
                        self.assertFalse(check.stdout.strip(), 'Test allocation did not finish')
                        time.sleep(2.2)  # Let monitor finish before deleting its shared queue.


if __name__ == '__main__':
    unittest.main(verbosity=2)
