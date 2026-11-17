#!/usr/bin/env python3
"""Install the skills in this repository into the agent discovery roots.

The repository is the source of truth. Agent hosts read skills from separate
directories, so an install step is required; linking rather than copying keeps a
single copy of every helper, reference and test.

    ./sync_skills.py check                  # per-skill state in every root
    ./sync_skills.py install                # create or repoint links
    ./sync_skills.py install --replace-copies   # also replace real copies

Only skills present in `skills/` are managed. Directories in a root that this
repository does not contain are reported as unmanaged and never modified.
"""

import fnmatch
import hashlib
import os
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent
SKILL_ROOT = REPO / "skills"

# Discovery roots of the installed agent hosts. `~/.codex/skills` still holds
# stale copies but the 2026-11-16 migration record retired Codex as an install
# target, so it is not written to; add it back here if that changes.
ROOTS = [
    Path.home() / ".agents" / "skills",
    Path.home() / ".config" / "opencode" / "skills",
]

# Runtime noise that must not be compared or copied.
IGNORE_PATTERNS = ("__pycache__", "*.pyc", ".Rhistory", ".RData", ".git", ".DS_Store", "*.log")


def ignored(rel):
    return any(fnmatch.fnmatch(part, pattern) for part in rel.parts for pattern in IGNORE_PATTERNS)


def skill_dirs():
    """Every directory holding a SKILL.md, keyed by install name (folder name)."""
    return {p.parent.name: p.parent for p in sorted(SKILL_ROOT.rglob("SKILL.md"))}


def digest(tree):
    """Hash of every file path and content, so a copy can be compared to its source."""
    h = hashlib.sha256()
    for path in sorted(p for p in tree.rglob("*") if p.is_file()):
        rel = path.relative_to(tree)
        if ignored(rel):
            continue
        h.update(rel.as_posix().encode())
        h.update(b"\0")
        h.update(path.read_bytes())
    return h.hexdigest()


def state(source, target):
    if target.is_symlink():
        return "linked" if target.resolve() == source.resolve() else f"stale-link"
    if not target.exists():
        return "absent"
    return "copy" if digest(source) == digest(target) else "copy-differs"


def replace_with_link(source, target):
    if target.is_symlink() or target.is_file():
        target.unlink()
    elif target.exists():
        shutil.rmtree(target)
    os.symlink(source, target)


def report(skills):
    width = max(len(name) for name in skills) + 2
    print(f"{'skill'.ljust(width)}" + "".join(r.parent.name.ljust(14) for r in ROOTS))
    for name, source in skills.items():
        print(name.ljust(width) + "".join(state(source, root / name).ljust(14) for root in ROOTS))
    managed = set(skills)
    for root in ROOTS:
        extras = sorted(p.name for p in root.iterdir()) if root.is_dir() else []
        extras = [name for name in extras if name not in managed]
        if extras:
            print(f"unmanaged in {root}: {', '.join(extras)}")


def install(skills, replace_copies=False):
    for root in ROOTS:
        root.mkdir(parents=True, exist_ok=True)
        for name, source in skills.items():
            target = root / name
            current = state(source, target)
            if current == "linked":
                continue
            if current in ("copy", "copy-differs") and not replace_copies:
                print(f"left {target}: real directory (rerun with --replace-copies to link it)")
                continue
            replace_with_link(source, target)
            print(f"{'repointed' if current.startswith('stale') else 'linked'} {name} -> {target}")


def main():
    actions = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    action = actions[0] if actions else "check"
    skills = skill_dirs()
    if not skills:
        sys.exit(f"no SKILL.md found under {SKILL_ROOT}")
    if action == "check":
        report(skills)
    elif action == "install":
        install(skills, replace_copies="--replace-copies" in flags)
        report(skills)
    else:
        sys.exit(f"unknown action {action!r}; use 'check' or 'install'")


if __name__ == "__main__":
    main()
