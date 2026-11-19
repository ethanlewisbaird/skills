#!/usr/bin/env python3
"""Check a skill folder's structure against the repository's authoring rules.

Read-only: reports errors and warnings, never edits a skill. A passing check
means the mechanical contract holds. It does not judge scope, scientific
validity, prose quality or whether the description actually triggers.

    python3 scripts/check_skill.py skills/bioinformatics-skill-authoring
    python3 scripts/check_skill.py skills --json
"""

import argparse
import json
import re
from pathlib import Path


FRONTMATTER = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.S)
KEBAB = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PLACEHOLDERS = re.compile(r"\b(?:TODO|TBD|FIXME)\b|\{\{[^{}\n]+\}\}|<skill-name>")
LOCAL_LINK = re.compile(r"\]\(\s*([^)\s]+)")
BUNDLED_TOKEN = re.compile(
    r"(?<![\w./-])(?:references|scripts|assets|tests)/"
    r"[A-Za-z0-9_][A-Za-z0-9_./-]*\.[A-Za-z0-9]+"
)
CODE_SPAN = re.compile(r"`([^`\n]+)`")
FENCE = re.compile(r"```.*?```", re.S)
TRIGGER = re.compile(r"\b(?:Use|Apply|Triggers)\b", re.I)
EXCLUSION = re.compile(r"\bseparate\b|\bexcludes?\b|\bnot for\b", re.I)
SECOND_PERSON = re.compile(r"\byou\b|\byour\b", re.I)
H2 = re.compile(r"^##\s+(.+?)\s*$", re.M)


def parse_frontmatter(text):
    """Return (fields, body, errors) for a SKILL.md string."""
    match = FRONTMATTER.match(text)
    if not match:
        return {}, text, ["SKILL.md needs YAML frontmatter delimited by ---"]
    fields = {}
    errors = []
    key = None
    for raw in match.group(1).splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if raw[:1].isspace():
            if key:
                fields[key] = f"{fields[key]} {raw.strip()}".strip()
            continue
        if ":" not in raw:
            errors.append(f"unparseable frontmatter line: {raw!r}")
            continue
        key, value = raw.split(":", 1)
        key = key.strip()
        value = value.strip().strip("'\"")
        if key in fields:
            errors.append(f"duplicate frontmatter key: {key}")
        fields[key] = value
    return fields, text[match.end():], errors


def parse_openai_yaml(path):
    """Parse the one-level interface mapping in agents/openai.yaml."""
    data = {}
    section = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#") or ":" not in raw:
            continue
        key, value = raw.strip().split(":", 1)
        key = key.strip()
        value = value.strip().strip("'\"")
        if raw[:1].isspace():
            if section:
                data[section][key] = value
        else:
            section = key
            data[section] = {}
    return data


def markdown_files(skill):
    """Every Markdown file in the skill, for orphan checks."""
    return sorted(skill.rglob("*.md"))


def mentions(skill, relative):
    text = "\n".join(p.read_text(encoding="utf-8", errors="replace")
                     for p in markdown_files(skill))
    return relative in text


def check_skill(skill, max_words=1800):
    """Return a read-only structural report for one skill directory."""
    skill = Path(skill).resolve()
    result = {
        "skill": str(skill),
        "name": "",
        "words": 0,
        "sections": 0,
        "references": 0,
        "completion": 0,
        "errors": [],
        "warnings": [],
    }
    errors = result["errors"]
    warnings = result["warnings"]
    skill_md = skill / "SKILL.md"
    if not skill_md.is_file():
        errors.append("SKILL.md is missing")
        return result

    fields, body, frontmatter_errors = parse_frontmatter(
        skill_md.read_text(encoding="utf-8"))
    errors.extend(frontmatter_errors)
    name = fields.get("name", "")
    description = fields.get("description", "")
    result["name"] = name

    if not name:
        errors.append("frontmatter needs name")
    else:
        if len(name) > 64:
            errors.append("name exceeds 64 characters")
        if not KEBAB.match(name):
            errors.append("name must be lowercase kebab-case")
        if name != skill.name:
            errors.append(f"name {name!r} does not match directory {skill.name!r}")

    if not description:
        errors.append("frontmatter needs description")
    else:
        if len(description) > 1024:
            errors.append("description exceeds 1,024 characters")
        if not TRIGGER.search(description):
            warnings.append("description has no Use when/for, Apply to or Triggers branch")
        if not EXCLUSION.search(description):
            warnings.append("description has no exclusion clause for neighbouring work")
        if SECOND_PERSON.search(description):
            warnings.append("description uses second person; keep it third person")
    if not fields.get("license"):
        warnings.append("frontmatter has no license")

    result["words"] = len(body.split())
    sections = [heading for heading in H2.findall(body)]
    result["sections"] = len(sections)
    result["completion"] = len(re.findall(r"Completion", body))
    result["references"] = len(set(re.findall(r"references/[A-Za-z0-9_./-]+", body)))

    if not body.strip():
        errors.append("SKILL.md body is empty")
    placeholders = PLACEHOLDERS.findall(skill_md.read_text(encoding="utf-8"))
    if placeholders:
        errors.append(f"unresolved placeholders: {len(placeholders)}")
    if result["words"] > max_words:
        warnings.append(f"body is {result['words']} words; disclose detail into references/")
    if result["words"] > 2500:
        warnings.append("body is above 2,500 words; split it by branch or sequence")
    if result["sections"] > 12:
        warnings.append(f"body has {result['sections']} H2 sections; consider a split")
    duplicates = sorted({h for h in sections if sections.count(h) > 1})
    if duplicates:
        warnings.append(f"duplicate H2 headings: {', '.join(duplicates)}")
    if result["sections"] >= 4 and result["completion"] == 0:
        warnings.append("no Completion criteria; name a saved artifact per step")

    bundled = set()
    for path in markdown_files(skill):
        if path.name == "validation.md":
            # The validation record reports findings about other skills and may
            # quote their paths; it is not a pointer source for this skill.
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for span in CODE_SPAN.findall(text):
            bundled.update(BUNDLED_TOKEN.findall(span))
        for block in FENCE.findall(text):
            bundled.update(BUNDLED_TOKEN.findall(block))
    for target in sorted(bundled):
        if not (skill / target).exists():
            errors.append(f"dead bundled pointer: {target}")

    for target in sorted(set(LOCAL_LINK.findall(body))):
        if target.startswith(("#", "http://", "https://", "mailto:")):
            continue
        path = target.split("#", 1)[0]
        if not path or "<" in path or ">" in path or "*" in path:
            continue
        if not (skill / path).exists():
            errors.append(f"dead local link: {target}")

    for folder in ("references", "assets"):
        root = skill / folder
        if not root.is_dir():
            continue
        for path in sorted(p for p in root.rglob("*") if p.is_file()):
            relative = path.relative_to(skill).as_posix()
            if not mentions(skill, relative):
                warnings.append(f"orphan file, never mentioned: {relative}")

    scripts = [p for p in (skill / "scripts").rglob("*")
               if p.is_file() and not p.name.startswith("__")] if (skill / "scripts").is_dir() else []
    if scripts and "## Validation" not in body:
        warnings.append("scripts/ exists but SKILL.md has no ## Validation section")
    if scripts:
        tests = [p for p in skill.rglob("*")
                 if p.is_file() and (p.name.startswith("test_") or "_test." in p.name)]
        if not tests:
            warnings.append("scripts/ exists but no test file was found")

    openai = skill / "agents" / "openai.yaml"
    if openai.is_file():
        interface = parse_openai_yaml(openai).get("interface", {})
        display = interface.get("display_name", "")
        short = interface.get("short_description", "")
        prompt = interface.get("default_prompt", "")
        if not display:
            errors.append("agents/openai.yaml needs interface.display_name")
        if not short:
            errors.append("agents/openai.yaml needs interface.short_description")
        elif not 25 <= len(short) <= 64:
            warnings.append("openai short_description should be 25-64 characters")
        if prompt and f"${name}" not in prompt:
            warnings.append("openai default_prompt should mention $<skill-name>")

    return result


def discover(paths):
    """Every directory containing a SKILL.md under the given paths."""
    found = set()
    for path in paths:
        path = Path(path).resolve()
        if (path / "SKILL.md").is_file():
            found.add(path)
        elif path.is_dir():
            found.update(p.parent for p in path.rglob("SKILL.md"))
        else:
            raise SystemExit(f"not a directory: {path}")
    return sorted(found)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path, default=[Path(".")],
                        help="skill directory or a tree containing skills")
    parser.add_argument("--max-words", type=int, default=1800)
    parser.add_argument("--json", action="store_true", help="print the full report")
    args = parser.parse_args()
    skills = discover(args.paths)
    if not skills:
        parser.error("no SKILL.md found")
    results = [check_skill(skill, args.max_words) for skill in skills]
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for result in results:
            status = "PASS" if not result["errors"] else "FAIL"
            print(f"{status} {result['name'] or Path(result['skill']).name}: "
                  f"{result['words']} words, {result['sections']} sections, "
                  f"{result['completion']} completion criteria, "
                  f"{result['references']} reference pointers, "
                  f"{len(result['errors'])} errors, {len(result['warnings'])} warnings")
            for message in result["errors"]:
                print(f"  error: {message}")
            for message in result["warnings"]:
                print(f"  warning: {message}")
    return 1 if any(result["errors"] for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
