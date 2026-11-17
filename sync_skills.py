#!/usr/bin/env python3
"""Install the skills in this repository into the agent discovery roots.

The repository is the source of truth. Agent hosts read skills from separate
directories, so without an install step the copies drift: a fixed helper or a
corrected path never reaches the host that loads it.

    ./sync_skills.py check      # per-skill state in every root, no changes
    ./sync_skills.py install    # copy each skill, replacing stale copies

Only skills present in `skills/` are managed. Directories in a root that this
repository does not contain are reported as unmanaged and never modified.
"""

import fnmatch
import hashlib
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent
SKILL_ROOT = REPO / "skills"

# Discovery roots of the installed agent hosts.
ROOTS = [
    Path.home() / ".agents" / "skills",
    Path.home() / ".codex" / "skills",
    Path.home() / ".config" / "opencode" / "skills",
]

# Runtime noise that must not be installed or counted in the comparison.
IGNORE_PATTERNS = ("__pycache__", "*.pyc", ".Rhistory", ".RData", ".git", ".DS_Store", "*.log")
IGNORE = shutil.ignore_patterns(*IGNORE_PATTERNS)


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
    if not target.exists():
        return "absent"
    return "same" if digest(source) == digest(target) else "differs"


def report(skills):
    width = max(len(name) for name in skills) + 2
    print(f"{'skill'.ljust(width)}" + "".join(r.parent.name.ljust(20) for r in ROOTS))
    for name, source in skills.items():
        print(name.ljust(width) + "".join(state(source, root / name).ljust(20) for root in ROOTS))

    managed = set(skills)
    for root in ROOTS:
        extras = sorted(p.name for p in root.iterdir() if p.is_dir()) if root.is_dir() else []
        extras = [name for name in extras if name not in managed]
        if extras:
            print(f"unmanaged in {root}: {', '.join(extras)}")


def install(skills):
    for root in ROOTS:
        root.mkdir(parents=True, exist_ok=True)
        for name, source in skills.items():
            target = root / name
            if state(source, target) == "same":
                continue
            if target.exists():
                shutil.rmtree(target)
            shutil.copytree(source, target, ignore=IGNORE)
            print(f"installed {name} -> {target}")


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "check"
    skills = skill_dirs()
    if not skills:
        sys.exit(f"no SKILL.md found under {SKILL_ROOT}")
    if action == "check":
        report(skills)
    elif action == "install":
        install(skills)
        report(skills)
    else:
        sys.exit(f"unknown action {action!r}; use 'check' or 'install'")


if __name__ == "__main__":
    main()
