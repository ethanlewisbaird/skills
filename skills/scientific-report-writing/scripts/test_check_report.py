"""Synthetic checks for report budgets, declared panel counts and local links."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from check_report import audit_report


class ReportChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.path = self.root / "analysis.html"
        # The checker verifies file existence, not raster decoding.
        (self.root / "plot.jpeg").write_bytes(b"fixture")

    def check(self, html, **limits):
        self.path.write_text(html)
        return audit_report(self.path, **limits)

    def figure(self, panels="1", caption="Evidence", alt="RNA expression"):
        return (f'<figure data-report-panels="{panels}"><img src="plot.jpeg" alt="{alt}">'
                f'<figcaption>{caption}</figcaption></figure>')

    def test_words_include_caption_and_table_but_exclude_metadata_and_references(self):
        report = self.check('<head><title>Not counted</title><style>body { color: red }</style></head>'
                            '<h1>Question</h1><p>Observed change</p>' + self.figure(caption="Two words") +
                            '<table><tr><td>Count this too</td></tr></table>'
                            '<section data-report-exclude="references"><h2>Sources</h2><p>Many source words</p></section>'
                            '<script>some code words</script><template>Template words</template>')
        self.assertEqual(report["words"], 8)
        self.assertEqual(report["display_panels"], 2)
        self.assertTrue(report["passed"])

    def test_word_boundary_and_override(self):
        self.assertTrue(self.check('<p>one two three</p>', max_words=3)["passed"])
        self.assertFalse(self.check('<p>one two three four</p>', max_words=3)["passed"])
        self.assertTrue(self.check('<p>one two three four</p>', max_words=4)["passed"])

    def test_metadata_without_explicit_head_and_inline_plot_labels(self):
        result = self.check('<title>Metadata words</title><figure data-report-panels="1">'
                            '<svg><text>Plot labels</text></svg><figcaption>Caption</figcaption></figure>')
        self.assertEqual(result["words"], 1)
        self.assertTrue(result["passed"])

    def test_composite_and_table_budget(self):
        html = self.figure("6") + '<table><tr><td>First</td></tr></table><table><tr><td>Second</td></tr></table>'
        self.assertEqual(self.check(html)["display_panels"], 8)
        self.assertTrue(self.check(html)["passed"])
        self.assertFalse(self.check(html + self.figure())["passed"])
        self.assertTrue(self.check(html + self.figure(), max_panels=9)["passed"])

    def test_unannotated_and_invalid_counts_cannot_pass(self):
        for value in ("", "0", "-1", "1.5", "six"):
            with self.subTest(value=value):
                result = self.check(self.figure(value))
                self.assertFalse(result["passed"])
                self.assertIsNone(result["display_panels"])
                self.assertEqual(result["unverified_displays"], 1)

    def test_unwrapped_displays_are_not_silently_omitted(self):
        result = self.check('<img src="plot.jpeg" alt="RNA"><svg></svg><canvas></canvas>')
        self.assertFalse(result["passed"])
        self.assertEqual(result["unverified_displays"], 3)

    def test_caption_and_alt_are_required(self):
        for html in (self.figure(caption=" "), self.figure(alt=""),
                     '<figure data-report-panels="1"><img src="plot.jpeg" alt="RNA"></figure>'):
            with self.subTest(html=html):
                self.assertFalse(self.check(html)["passed"])

    def test_table_in_figure_is_counted_once_and_references_cannot_hide_panels(self):
        html = ('<section data-report-exclude="references"><figure data-report-panels="1">'
                '<table><tr><td>Source</td></tr></table><figcaption>Evidence</figcaption>'
                '</figure></section>')
        result = self.check(html)
        self.assertEqual(result["words"], 0)
        self.assertEqual(result["display_panels"], 1)

    def test_nested_figures_are_flagged(self):
        self.assertFalse(self.check('<figure data-report-panels="1">' + self.figure() +
                                    '<figcaption>Outer</figcaption></figure>')["passed"])

    def test_local_files_and_html_fragments(self):
        (self.root / "other report.html").write_text('<h2 id="result">Result</h2>')
        good = ('<h2 id="local">Here</h2><a href="#local">Here</a>'
                '<a href="other%20report.html?view=all#result">Result</a>' + self.figure())
        self.assertTrue(self.check(good)["passed"])
        for broken in ('missing.jpeg', 'other%20report.html#absent', '#absent'):
            with self.subTest(broken=broken):
                self.assertFalse(self.check(good + f'<a href="{broken}">Broken</a>')["passed"])

    def test_file_urls_self_closing_images_and_duplicate_ids(self):
        url = (self.root / "plot.jpeg").as_uri()
        good = f'<figure data-report-panels="1"><img src="{url}" alt="RNA"/><figcaption>RNA</figcaption></figure>'
        self.assertTrue(self.check(good)["passed"])
        self.assertFalse(self.check(good + '<p id="same">A</p><p id="same">B</p>')["passed"])

    def test_external_and_non_html_fragments_have_explicit_scope(self):
        (self.root / "README.md").write_text('# Methods')
        result = self.check('<a href="https://invalid.example/no-network">Source</a>'
                            '<a href="README.md#methods">Methods</a>')
        self.assertTrue(result["passed"])
        self.assertEqual(result["nonlocal_targets_skipped"], 1)
        self.assertEqual(result["non_html_fragments_skipped"], ['README.md#methods'])

    def test_template_leftovers_and_base_urls(self):
        for html in ('<p>{{ result }}</p>', '<p>{% include figure %}</p>',
                     '<p><%= result %></p>', '<base href="assets/"><p>Text</p>'):
            with self.subTest(html=html):
                self.assertFalse(self.check(html)["passed"])

    def test_cli_json_status_and_read_only_behavior(self):
        script = Path(__file__).with_name('check_report.py')
        for html, expected_status in ((self.figure(), 0), (self.figure("0"), 1)):
            self.path.write_text(html)
            original = self.path.read_bytes()
            result = subprocess.run([sys.executable, str(script), str(self.path), '--json'],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, expected_status, result.stderr)
            self.assertEqual(json.loads(result.stdout)["passed"], expected_status == 0)
            self.assertEqual(original, self.path.read_bytes())


if __name__ == '__main__':
    unittest.main()
