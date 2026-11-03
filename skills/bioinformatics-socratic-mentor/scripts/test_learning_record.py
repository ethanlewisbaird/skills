#!/usr/bin/env python3
"""Deterministic storage/evidence tests, isolated from real learning records."""
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

SCRIPT = Path(__file__).with_name('learning_record.py')
spec = importlib.util.spec_from_file_location('learning_record', SCRIPT)
record_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(record_module)


def example():
    return dict(concept='experimental-unit', domain='statistics', subdomain='replication',
                required_level=3, last_assessed='2026-11-03', exercise_type='teach-back',
                status='independent', outcome='justified', evidence='Identified independent assignment and within-unit dependence.',
                misconceptions=[], hint_dependence=0, transfer_performance='not-tested',
                confidence='moderate', next_review='2026-11-24', project=None)


class RecordTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.directory = Path(self.tmp.name) / 'private'
        self.path = self.directory / 'record.json'

    def tearDown(self):
        self.tmp.cleanup()

    def run_cli(self, command, value=None, *extra):
        return subprocess.run([sys.executable, str(SCRIPT), '--directory', str(self.directory),
                               command, *extra], input=json.dumps(value) if value else '',
                              text=True, capture_output=True)

    def add(self, value=None):
        result = self.run_cli('add', value or example(), '--sanitized')
        self.assertEqual(result.returncode, 0, result.stderr)

    def read(self):
        return json.loads(self.path.read_text())

    def test_inspection_does_not_create_memory(self):
        self.assertEqual(self.run_cli('inspect').returncode, 0)
        self.assertFalse(self.directory.exists())

    def test_roundtrip_and_validation(self):
        self.add()
        self.assertEqual(self.read()['records'], [example()])
        self.assertEqual(self.run_cli('validate').returncode, 0)

    def test_existing_evidence_preserved(self):
        self.add()
        second = example()
        second['project'] = 'synthetic-project'
        self.add(second)
        self.assertEqual(self.read()['records'], [example(), second])

    def test_correct_only_requested_observation(self):
        self.add()
        self.add()
        revised = example()
        revised['evidence'] = 'Corrected conceptual summary.'
        self.assertEqual(self.run_cli('correct', revised, '0', '--sanitized').returncode, 0)
        self.assertEqual(self.read()['records'], [revised, example()])

    def test_invalid_correction_preserves_file(self):
        self.add()
        previous = self.path.read_bytes()
        self.assertNotEqual(self.run_cli('correct', example(), '-1', '--sanitized').returncode, 0)
        self.assertEqual(self.path.read_bytes(), previous)

    def test_export_matches_evidence(self):
        self.add()
        self.assertEqual(json.loads(self.run_cli('export').stdout), self.read())

    def test_disabled_blocks_writes_and_enable_restores(self):
        self.add()
        self.assertEqual(self.run_cli('disable').returncode, 0)
        self.assertNotEqual(self.run_cli('add', example(), '--sanitized').returncode, 0)
        self.assertEqual(len(self.read()['records']), 1)
        self.assertEqual(self.run_cli('enable').returncode, 0)
        self.add()

    def test_erase_clears_evidence_and_disables(self):
        self.add()
        (self.directory / '.record-interrupted').write_text('synthetic conceptual evidence')
        self.assertEqual(self.run_cli('erase').returncode, 0)
        self.assertEqual(self.read(), {'version': 1, 'enabled': False, 'records': []})
        self.assertFalse(list(self.directory.glob('.record-*')))

    def test_erase_corrupt_record(self):
        self.add()
        self.path.write_text('{broken')
        self.assertEqual(self.run_cli('erase').returncode, 0)
        self.assertEqual(self.read()['records'], [])

    def test_corrupt_existing_file_is_not_overwritten(self):
        self.add()
        self.path.write_text('{broken')
        self.assertNotEqual(self.run_cli('add', example(), '--sanitized').returncode, 0)
        self.assertEqual(self.path.read_text(), '{broken')

    def test_unjustified_correct_answer_rejected(self):
        value = example()
        value['outcome'] = 'incomplete'
        with self.assertRaises(ValueError):
            record_module.check_record(value)

    def test_hinted_independence_rejected(self):
        value = example()
        value['hint_dependence'] = 1
        with self.assertRaises(ValueError):
            record_module.check_record(value)

    def test_transfer_requires_transfer_evidence(self):
        value = example()
        value['status'] = 'transfer'
        with self.assertRaises(ValueError):
            record_module.check_record(value)
        value['transfer_performance'] = 'independent'
        record_module.check_record(value)

    def test_skipped_not_a_demonstration(self):
        value = example()
        value['outcome'] = 'skipped'
        with self.assertRaises(ValueError):
            record_module.check_record(value)
        value.update(status='not-assessed', last_assessed=None, next_review=None)
        record_module.check_record(value)

    def test_exposure_not_assessment(self):
        value = example()
        value.update(status='exposure-only', outcome='exposure', exercise_type='none')
        with self.assertRaises(ValueError):
            record_module.check_record(value)
        value.update(last_assessed=None, next_review=None)
        record_module.check_record(value)

    def test_schema_rejects_unknown_fields_and_bad_dates(self):
        for changes in ({'raw_answer': 'unwanted'}, {'last_assessed': 'yesterday'}, {'required_level': True}):
            value = example()
            value.update(changes)
            with self.assertRaises((ValueError, TypeError)):
                record_module.check_record(value)

    def test_explicit_sanitization_required(self):
        self.assertNotEqual(self.run_cli('add', example()).returncode, 0)
        self.assertFalse(self.directory.exists())

    def test_private_permissions(self):
        self.add()
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_symlink_record_refused(self):
        self.directory.mkdir(mode=0o700)
        target = Path(self.tmp.name) / 'other'
        target.write_text('untouched')
        self.path.symlink_to(target)
        self.assertNotEqual(self.run_cli('add', example(), '--sanitized').returncode, 0)
        self.assertEqual(target.read_text(), 'untouched')

    def test_symlink_directory_refused_for_reads_and_writes(self):
        target = Path(self.tmp.name) / 'target'
        target.mkdir(mode=0o700)
        self.directory.symlink_to(target, target_is_directory=True)
        self.assertNotEqual(self.run_cli('inspect').returncode, 0)
        self.assertNotEqual(self.run_cli('add', example(), '--sanitized').returncode, 0)
        self.assertFalse((target / 'record.json').exists())

    def test_schema_version_is_an_integer(self):
        with self.assertRaises(ValueError):
            record_module.check_document({'version': True, 'enabled': True, 'records': []})

    def test_replace_failure_preserves_record_and_cleans_temp(self):
        self.add()
        previous = self.path.read_bytes()
        data = self.read()
        data['records'].append(example())
        with patch.object(record_module.os, 'replace', side_effect=OSError('synthetic failure')):
            with self.assertRaises(OSError):
                record_module.atomic_write(self.path, data)
        self.assertEqual(self.path.read_bytes(), previous)
        self.assertFalse(list(self.directory.glob('.record-*')))

    def test_file_creation_failure_does_not_claim_save(self):
        self.directory.write_text('not a directory')
        result = self.run_cli('add', example(), '--sanitized')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('no save is claimed', result.stderr)

    def test_concurrent_writers_keep_all_observations(self):
        def write(index):
            value = example()
            value['concept'] = 'concept-' + str(index)
            return self.run_cli('add', value, '--sanitized').returncode
        with ThreadPoolExecutor(max_workers=4) as pool:
            self.assertEqual(list(pool.map(write, range(12))), [0] * 12)
        self.assertEqual(len({x['concept'] for x in self.read()['records']}), 12)


if __name__ == '__main__':
    unittest.main(verbosity=2)
