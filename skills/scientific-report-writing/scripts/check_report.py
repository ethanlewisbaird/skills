#!/usr/bin/env python3
"""Check the mechanical presentation of a rendered local HTML report."""

import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit


WORDS = re.compile(r"\b\w+(?:[’'-]\w+)*\b")
PLACEHOLDERS = re.compile(r"\{\{[^{}\n]+\}\}|\{%[^%\n]+%\}|<%[^%\n]+%>")
VOID_TAGS = {"area", "base", "br", "col", "embed", "hr", "img", "input",
             "link", "meta", "param", "source", "track", "wbr"}
NON_TEXT = {"head", "title", "script", "style", "template", "svg", "canvas"}


class ReportHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.words = []
        self.ids = set()
        self.targets = []
        self.figures = []
        self.tables = 0
        self.unwrapped_displays = 0
        self.issues = []

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if attrs.get("id"):
            if attrs["id"] in self.ids:
                self.issues.append(f"Duplicate HTML id: {attrs['id']}")
            self.ids.add(attrs["id"])
        if tag == "a" and attrs.get("name"):
            self.ids.add(attrs["name"])
        for key in ("href", "src"):
            if attrs.get(key):
                self.targets.append(attrs[key])
        if tag == "base":
            self.issues.append("HTML base URLs need manual link review; use report-relative URLs for this checker")

        figure = next((f[2] for f in reversed(self.stack) if f[0] == "figure"), None)
        if tag == "figure":
            if figure is not None:
                self.issues.append("Nested figures need separate, non-overlapping panel annotations")
            value = attrs.get("data-report-panels", "")
            panels = int(value) if re.fullmatch(r"[1-9][0-9]*", value) else None
            figure = {"panels": panels, "caption": []}
            self.figures.append(figure)
            if panels is None:
                self.issues.append(f"Figure {len(self.figures)} needs a positive integer data-report-panels")
        if tag == "table" and figure is None:
            self.tables += 1
        if tag == "img":
            if not attrs.get("alt", "").strip():
                self.issues.append("Report image needs descriptive alt text")
            if not attrs.get("src", "").strip():
                self.issues.append("Report image needs a src")
            if figure is None:
                self.unwrapped_displays += 1
                self.issues.append("Image outside an annotated figure needs panel/caption review")
        if tag in {"svg", "canvas", "object", "embed", "iframe"} and figure is None:
            self.unwrapped_displays += 1
            self.issues.append(f"{tag} display outside an annotated figure needs panel review")

        excluded = (any(f[1] for f in self.stack) or tag in NON_TEXT
                    or attrs.get("data-report-exclude") == "references")
        if tag not in VOID_TAGS:
            self.stack.append((tag, excluded, figure if tag == "figure" else None))

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID_TAGS:
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                del self.stack[index:]
                break

    def handle_data(self, data):
        if not any(f[1] for f in self.stack):
            self.words.append(data)
        if any(f[0] == "figcaption" for f in self.stack):
            figure = next((f[2] for f in reversed(self.stack) if f[0] == "figure"), None)
            if figure is not None:
                figure["caption"].append(data)


def parse_html(path):
    document = ReportHTML()
    document.feed(path.read_text(encoding="utf-8-sig"))
    document.close()
    return document


def audit_report(path, max_words=3000, max_panels=8):
    path = Path(path).resolve()
    raw = path.read_bytes()
    html = raw.decode("utf-8-sig")
    document = ReportHTML()
    document.feed(html)
    document.close()
    issues = list(document.issues)
    words = len(WORDS.findall(" ".join(document.words)))
    known_panels = document.tables + sum(f["panels"] or 0 for f in document.figures)
    unknown = sum(f["panels"] is None for f in document.figures) + document.unwrapped_displays
    for number, figure in enumerate(document.figures, 1):
        if not "".join(figure["caption"]).strip():
            issues.append(f"Figure {number} needs a nonempty figcaption")
    if words > max_words:
        issues.append(f"Word limit exceeded: {words} > {max_words}")
    if known_panels > max_panels:
        issues.append(f"Display limit exceeded: at least {known_panels} > {max_panels}")
    placeholders = PLACEHOLDERS.findall(html)
    if placeholders:
        issues.append(f"Unresolved template placeholders: {len(placeholders)}")

    cache = {path: document}
    local_checked = 0
    external_skipped = 0
    other_fragments = []
    for target in sorted(set(document.targets)):
        url = urlsplit(target)
        if url.scheme == "file" and url.netloc in {"", "localhost"}:
            destination = Path(unquote(url.path)).resolve()
        elif url.scheme or url.netloc:
            external_skipped += 1
            continue
        else:
            destination = (path.parent / unquote(url.path)).resolve() if url.path else path
        local_checked += 1
        if not destination.exists():
            issues.append(f"Missing local target: {target}")
            continue
        if url.fragment:
            if destination.suffix.lower() not in {".html", ".htm"}:
                # Markdown heading slugs and PDF page links need their own renderer.
                other_fragments.append(target)
                continue
            if destination not in cache:
                cache[destination] = parse_html(destination)
            if unquote(url.fragment) not in cache[destination].ids:
                issues.append(f"Missing HTML fragment: {target}")

    return {
        "report": str(path), "report_sha256": hashlib.sha256(raw).hexdigest(),
        "checker_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "passed": not issues, "words": words, "max_words": max_words,
        "display_panels": known_panels if not unknown else None,
        "known_display_panels": known_panels, "unverified_displays": unknown,
        "max_panels": max_panels, "figures": len(document.figures),
        "tables_outside_figures": document.tables,
        "local_targets_checked": local_checked, "nonlocal_targets_skipped": external_skipped,
        "non_html_fragments_skipped": other_fragments,
        "issues": issues,
    }


def positive_integer(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--max-words", type=positive_integer, default=3000)
    parser.add_argument("--max-panels", type=positive_integer, default=8)
    parser.add_argument("--json", action="store_true", help="Print results for an existing validation record")
    args = parser.parse_args()
    try:
        result = audit_report(args.report, args.max_words, args.max_panels)
    except (OSError, UnicodeError, ValueError) as error:
        parser.error(str(error))
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        panels = result["display_panels"]
        count = str(panels) if panels is not None else f"at least {result['known_display_panels']} (incomplete)"
        print(f"{'PASS' if result['passed'] else 'FAIL'} {result['report']}: "
              f"{result['words']}/{args.max_words} words; {count}/{args.max_panels} display panels")
        print(f"Local targets checked: {result['local_targets_checked']}; "
              f"nonlocal/data URLs skipped: {result['nonlocal_targets_skipped']}; "
              f"non-HTML fragments unchecked: {len(result['non_html_fragments_skipped'])}")
        for issue in result["issues"]:
            print(f"- {issue}")
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
