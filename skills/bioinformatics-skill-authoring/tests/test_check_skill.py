"""Synthetic checks for the skill structure checker."""

import json
import sys
from pathlib import Path
import subprocess
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import check_skill


DESCRIPTION = (
    "Audit a demo workflow and report its checks. Use when a demo needs "
    "auditing; report writing is a separate workflow."
)

BODY = """# Demo skill

Audit one demo workflow and keep the result.

## Audit the demo

1. Read the input and record its provenance.

Completion: a saved audit table.

## Validation

```bash
python3 tests/test_demo.py
```

Methods: [methods](references/methods.md).
"""


class SkillChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def make_skill(self, directory="demo-skill", name="demo-skill",
                   description=DESCRIPTION, body=BODY, license_line="license: MIT\n",
                   openai=True, files=True):
        skill = self.root / directory
        skill.mkdir(parents=True, exist_ok=True)
        (skill / "SKILL.md").write_text(
            f"---\nname: {name}\ndescription: {description}\n{license_line}---\n\n{body}"
        )
        if files:
            (skill / "references").mkdir(exist_ok=True)
            (skill / "references" / "methods.md").write_text("# Methods\n\nDetails.\n")
            (skill / "scripts").mkdir(exist_ok=True)
            (skill / "scripts" / "helper.py").write_text("def check():\n    return True\n")
            (skill / "tests").mkdir(exist_ok=True)
            (skill / "tests" / "test_demo.py").write_text("def test_check():\n    assert True\n")
        if openai:
            (skill / "agents").mkdir(exist_ok=True)
            (skill / "agents" / "openai.yaml").write_text(
                'interface:\n'
                '  display_name: "Demo skill"\n'
                '  short_description: "Audit demo workflows and report checks"\n'
                '  default_prompt: "Use $demo-skill to audit this workflow."\n'
            )
        return skill

    def check(self, skill, **kwargs):
        return check_skill.check_skill(skill, **kwargs)

    def test_valid_skill_passes_without_warnings(self):
        result = self.check(self.make_skill())
        self.assertEqual(result["errors"], [])
        self.assertEqual(result["warnings"], [])

    def test_name_must_be_kebab_and_match_the_directory(self):
        result = self.check(self.make_skill(directory="wrong-dir"))
        self.assertIn("does not match directory", " ".join(result["errors"]))
        result = self.check(self.make_skill(directory="Other_Name", name="Other_Name"))
        self.assertIn("kebab-case", " ".join(result["errors"]))

    def test_missing_or_unparseable_frontmatter_fails(self):
        skill = self.make_skill()
        (skill / "SKILL.md").write_text("# No frontmatter\n")
        self.assertIn("frontmatter", " ".join(self.check(skill)["errors"]))
        (skill / "SKILL.md").write_text("---\nname demo\n---\nBody\n")
        self.assertIn("unparseable", " ".join(self.check(skill)["errors"]))

    def test_description_length_and_license(self):
        result = self.check(self.make_skill(description="x" * 1100))
        self.assertIn("1,024", " ".join(result["errors"]))
        result = self.check(self.make_skill(license_line=""))
        self.assertIn("license", " ".join(result["warnings"]))

    def test_trigger_exclusion_and_second_person_are_warnings(self):
        result = self.check(self.make_skill(description="Audit a demo workflow."))
        messages = " ".join(result["warnings"])
        self.assertIn("Use when", messages)
        self.assertIn("exclusion", messages)
        result = self.check(self.make_skill(
            description="Audit your demo workflow. Use when needed; reports are separate."))
        self.assertIn("second person", " ".join(result["warnings"]))

    def test_dead_bundled_pointer_and_local_link_fail(self):
        result = self.check(self.make_skill(body=BODY + "\n`references/gone.md`\n"))
        self.assertIn("dead bundled pointer", " ".join(result["errors"]))
        result = self.check(self.make_skill(body=BODY + "\n[gone](references/gone.md)\n"))
        self.assertIn("dead local link", " ".join(result["errors"]))

    def test_orphan_reference_is_a_warning_not_an_error(self):
        skill = self.make_skill()
        (skill / "references" / "orphan.md").write_text("# Orphan\n")
        result = self.check(skill)
        self.assertEqual(result["errors"], [])
        self.assertIn("orphan", " ".join(result["warnings"]))

    def test_validation_record_is_not_a_pointer_source(self):
        skill = self.make_skill()
        (skill / "references" / "validation.md").write_text(
            "# Development validation\n\n"
            "Another skill's scan flagged `assets/config_template.R`.\n")
        result = self.check(skill)
        self.assertNotIn("dead bundled pointer", " ".join(result["errors"]))

    def test_placeholders_fail(self):
        for placeholder in ("TODO", "TBD", "{{ name }}", "<skill-name>"):
            with self.subTest(placeholder=placeholder):
                result = self.check(self.make_skill(body=BODY + f"\n{placeholder}\n"))
                self.assertIn("placeholder", " ".join(result["errors"]))

    def test_missing_completion_and_validation_are_warnings(self):
        body = "# Demo\n\n## One\n\nText.\n\n## Two\n\nText.\n\n## Three\n\nText.\n\n## Four\n\nText.\n"
        skill = self.make_skill(body=body)
        result = self.check(skill)
        messages = " ".join(result["warnings"])
        self.assertIn("Completion", messages)
        self.assertIn("Validation", messages)

    def test_openai_metadata_contract(self):
        skill = self.make_skill()
        (skill / "agents" / "openai.yaml").write_text(
            'interface:\n  display_name: "Demo"\n')
        self.assertIn("short_description", " ".join(self.check(skill)["errors"]))
        (skill / "agents" / "openai.yaml").write_text(
            'interface:\n  display_name: "Demo"\n'
            '  short_description: "Short"\n'
            '  default_prompt: "Audit this."\n')
        messages = " ".join(self.check(skill)["warnings"])
        self.assertIn("25-64", messages)
        self.assertIn("$<skill-name>", messages)

    def test_long_body_and_too_many_sections_warn(self):
        body = BODY + "\n" + ("word " * 1900)
        result = self.check(self.make_skill(body=body))
        self.assertIn("words", " ".join(result["warnings"]))
        body = "# Demo\n\n" + "\n".join(f"## Section {n}\n\nText.\n" for n in range(14))
        result = self.check(self.make_skill(body=body))
        self.assertIn("H2 sections", " ".join(result["warnings"]))

    def test_discovery_finds_nested_skills(self):
        self.make_skill()
        nested = self.root / "group" / "second-skill"
        nested.mkdir(parents=True)
        (nested / "SKILL.md").write_text(
            "---\nname: second-skill\ndescription: A second skill. Use when needed; other work is separate.\n"
            "license: MIT\n---\n\nBody.\n")
        found = check_skill.discover([self.root])
        self.assertEqual([p.name for p in found], ["demo-skill", "second-skill"])

    def test_cli_json_status_and_read_only(self):
        script = Path(check_skill.__file__)
        good = self.make_skill()
        bad = self.make_skill(directory="bad-skill", name="wrong-name")
        for skill, expected in ((good, 0), (bad, 1)):
            original = (skill / "SKILL.md").read_bytes()
            run = subprocess.run(
                [sys.executable, str(script), str(skill), "--json"],
                capture_output=True, text=True)
            self.assertEqual(run.returncode, expected, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(report[0]["skill"], str(skill.resolve()))
            self.assertEqual(report[0]["errors"] == [], expected == 0)
            self.assertEqual(original, (skill / "SKILL.md").read_bytes())


if __name__ == "__main__":
    unittest.main()
