#!/usr/bin/env python3
"""Private, atomic local learning evidence storage (Python standard library, Linux)."""
import argparse
from contextlib import contextmanager
from datetime import date
import fcntl
import json
import os
from pathlib import Path
import sys
import tempfile

STATUSES = {
    'not-assessed', 'exposure-only', 'developing', 'guided',
    'independent', 'transfer', 'review-recommended',
}
TYPES = {'none', 'teach-back', 'coding', 'prediction', 'debugging', 'interpretation', 'method-selection'}
OUTCOMES = {'not-assessed', 'exposure', 'justified', 'incomplete', 'partial', 'misconception', 'unable', 'skipped'}
FIELDS = {
    'concept', 'domain', 'subdomain', 'required_level', 'last_assessed',
    'exercise_type', 'status', 'outcome', 'evidence', 'misconceptions',
    'hint_dependence', 'transfer_performance', 'confidence', 'next_review',
    'project',
}


def check_record(record):
    """Reject malformed evidence and obvious overstatement; content still needs human sanitization."""
    if not isinstance(record, dict) or set(record) != FIELDS:
        raise ValueError('Record must contain exactly the documented fields')
    for key in ('concept', 'domain', 'subdomain', 'evidence'):
        if not isinstance(record[key], str) or not record[key].strip() or len(record[key]) > 1200:
            raise ValueError('Invalid conceptual summary field: ' + key)
    if type(record['required_level']) is not int or record['required_level'] not in range(4):
        raise ValueError('required_level must be 0–3')
    if record['status'] not in STATUSES or record['exercise_type'] not in TYPES or record['outcome'] not in OUTCOMES:
        raise ValueError('Unknown status, exercise type or outcome')
    if record['confidence'] not in {'low', 'moderate', 'high'}:
        raise ValueError('Unknown confidence')
    if type(record['hint_dependence']) is not int or record['hint_dependence'] not in range(4):
        raise ValueError('hint_dependence must be 0–3 (3 includes full scaffolding/solution)')
    if record['transfer_performance'] not in {'not-tested', 'guided', 'independent', 'unsuccessful'}:
        raise ValueError('Unknown transfer performance')
    if not isinstance(record['misconceptions'], list) or any(not isinstance(x, str) or len(x) > 1200 for x in record['misconceptions']):
        raise ValueError('misconceptions must be short conceptual strings')
    if record['project'] is not None and (not isinstance(record['project'], str) or not record['project'] or len(record['project']) > 80):
        raise ValueError('project must be null or a sanitized alias of at most 80 characters')
    for key in ('last_assessed', 'next_review'):
        if record[key] is not None:
            date.fromisoformat(record[key])
    if record['outcome'] in {'not-assessed', 'exposure', 'skipped', 'unable'}:
        if record['status'] not in {'not-assessed', 'exposure-only', 'review-recommended'}:
            raise ValueError('Unassessed/exposure/skipped/unable is not demonstrated understanding')
        if record['last_assessed'] is not None or record['next_review'] is not None:
            raise ValueError('No assessment/review date may be inferred from exposure or skipping')
    elif record['last_assessed'] is None or record['exercise_type'] == 'none':
        raise ValueError('An assessment requires a date and exercise type')
    if record['status'] == 'exposure-only' and record['outcome'] != 'exposure':
        raise ValueError('Exposure-only requires exposure outcome')
    if record['status'] in {'guided', 'independent', 'transfer'} and record['outcome'] != 'justified':
        raise ValueError('Demonstration requires justified reasoning')
    if record['status'] in {'independent', 'transfer'} and record['hint_dependence']:
        raise ValueError('Hinted work cannot be marked independent')
    if record['status'] == 'transfer' and record['transfer_performance'] != 'independent':
        raise ValueError('Transfer status requires independent transfer evidence')
    return record


def check_document(data):
    if not isinstance(data, dict) or set(data) != {'version', 'enabled', 'records'}:
        raise ValueError('Invalid learning record document')
    if type(data['version']) is not int or data['version'] != 1 or type(data['enabled']) is not bool or not isinstance(data['records'], list):
        raise ValueError('Unsupported schema or invalid settings')
    for record in data['records']:
        check_record(record)
    return data


def read_document(path):
    if path.is_symlink() or path.parent.is_symlink():
        raise ValueError('Refusing a symlinked record file or memory directory')
    if not path.exists():
        return {'version': 1, 'enabled': True, 'records': []}
    return check_document(json.loads(path.read_text()))


def atomic_write(path, data):
    """Replace only after complete validated content is flushed; leave the old file on failure."""
    check_document(data)
    if path.is_symlink():
        raise ValueError('Refusing a symlinked record file')
    name = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, prefix='.record-', delete=False) as stream:
            name = stream.name
            os.chmod(name, 0o600)
            json.dump(data, stream, indent=2, ensure_ascii=False)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        name = None
        directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if name is not None:
            Path(name).unlink(missing_ok=True)


@contextmanager
def locked(directory):
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    if directory.is_symlink():
        raise ValueError('Refusing a symlinked memory directory')
    if directory.stat().st_mode & 0o077:
        raise ValueError('Memory directory must be private (chmod 700)')
    fd = os.open(directory / '.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    default = Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex'))) / 'learning' / 'bioinformatics-socratic-mentor'
    parser.add_argument('--directory', type=Path, default=default, help='User-controlled local memory directory')
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('inspect', 'export', 'validate', 'disable', 'enable', 'erase'):
        sub.add_parser(name)
    for name in ('add', 'correct'):
        action = sub.add_parser(name)
        action.add_argument('--sanitized', action='store_true', required=True, help='Confirm conceptual input contains no private data or identifiers')
        if name == 'correct':
            action.add_argument('index', type=int, help='Zero-based record index from inspect/export')
    args = parser.parse_args()
    path = args.directory / 'record.json'
    if args.command in {'inspect', 'export', 'validate'}:
        data = read_document(path)
        print('Valid schema' if args.command == 'validate' else json.dumps(data, indent=2, ensure_ascii=False))
        return
    # Parse and validate input before creating a directory or taking the write lock.
    record = check_record(json.load(sys.stdin)) if args.command in {'add', 'correct'} else None
    with locked(args.directory):
        # Erasure intentionally also works for malformed records, without reading their contents.
        data = {'version': 1, 'enabled': False, 'records': []} if args.command == 'erase' else read_document(path)
        if args.command in {'add', 'correct'}:
            if not data['enabled']:
                raise ValueError('Learning memory disabled; no evidence written')
            if args.command == 'add':
                data['records'].append(record)
            else:
                if args.index < 0 or args.index >= len(data['records']):
                    raise ValueError('Correction index does not exist')
                data['records'][args.index] = record
        elif args.command in {'enable', 'disable'}:
            data['enabled'] = args.command == 'enable'
        atomic_write(path, data)
        if args.command == 'erase':
            # A killed writer may leave a private temporary copy of evidence.
            for leftover in args.directory.glob('.record-*'):
                if leftover.is_file() or leftover.is_symlink():
                    leftover.unlink()
    print('Stored locally' if args.command != 'erase' else 'Records erased; persistence disabled')


if __name__ == '__main__':
    os.umask(0o077)
    try:
        main()
    except (OSError, ValueError, TypeError, KeyError) as error:
        # Do not echo input content: validation errors may concern accidentally sensitive input.
        print('Learning record operation failed (' + type(error).__name__ + '); no save is claimed.', file=sys.stderr)
        sys.exit(1)
