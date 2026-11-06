#!/usr/bin/env python3
"""Small synthetic checks; no expression objects or external inputs are loaded."""

import random
import tempfile
import unittest
from pathlib import Path
from subprocess import run
import sys

from audit_coverage import audit, read_tsv, write_tsv


class CoverageTests(unittest.TestCase):
    def setUp(self):
        # A/X is blocked globally by A/Z, although Z is outside the signature.
        # B and C tie for Y; D/V and E/W remain primary but differ in measurement.
        self.mapping = [dict(source_id=s, target_id=t, score=v) for s, t, v in
                        [("A", "X", 8), ("A", "Z", 9), ("B", "Y", 7), ("C", "Y", 7),
                         ("D", "V", 8), ("E", "W", 8), ("F", "Q", 1)]]
        self.signatures = [dict(signature="program", input_gene=t, target_id=t)
                           for t in ["X", "Y", "V", "W", "Q"]]
        self.signatures += [dict(signature="program", input_gene="unknown", target_id="")]
        self.features = [dict(source_id=s, assayed=a, expressed=e) for s, a, e in
                         [("A", "TRUE", "TRUE"), ("B", "TRUE", "TRUE"),
                          ("C", "TRUE", "TRUE"), ("D", "TRUE", "FALSE"),
                          ("E", "FALSE", "FALSE"), ("F", "TRUE", "TRUE")]]

    def test_global_best_ties_and_measurement_stages(self):
        mapping, genes, coverage = audit(self.mapping, self.signatures, self.features, 3, 2, .3)
        primary = {(r["source_id"], r["target_id"]) for r in mapping if r["primary_pair"]}
        self.assertEqual(primary, {("A", "Z"), ("D", "V"), ("E", "W")})
        p, b = coverage
        self.assertEqual((p["target_genes_mapped"], p["target_genes_assayed"], p["target_genes_expressed"]), (2, 1, 0))
        self.assertEqual((b["target_genes_mapped"], b["target_genes_assayed"], b["target_genes_expressed"]), (4, 3, 2))
        self.assertEqual(b["distinct_source_genes_expressed"], 3)
        self.assertAlmostEqual(b["retained_input_fraction"], 2 / 6)
        self.assertFalse(p["score_eligible"])
        self.assertTrue(b["score_eligible"])
        self.assertIn("unresolved_target", {r["status"] for r in genes})

    def test_row_order_invariance_and_duplicate_pairs(self):
        expected = audit(self.mapping, self.signatures, self.features, 3)
        rng = random.Random(7)
        self.mapping += [self.mapping[0].copy()]
        rng.shuffle(self.mapping); rng.shuffle(self.signatures); rng.shuffle(self.features)
        self.assertEqual(audit(self.mapping, self.signatures, self.features, 3), expected)

    def test_alias_denominator_and_source_gene_deduplication(self):
        self.signatures += [dict(signature="program", input_gene="X_old", target_id="X")]
        b = audit(self.mapping, self.signatures, self.features, 3)[2][1]
        self.assertEqual(b["resolved_entries_sharing_target"], 1)
        self.assertEqual((b["original_input_genes"], b["input_genes_retained"], b["distinct_source_genes_expressed"]), (7, 3, 3))

    def test_inconsistent_scores_rejected(self):
        self.mapping += [dict(source_id="A", target_id="X", score=9)]
        with self.assertRaises(ValueError): audit(self.mapping, self.signatures, self.features, 3)

    def test_expression_without_measurement_rejected(self):
        self.features[0]["assayed"] = "FALSE"
        with self.assertRaises(ValueError): audit(self.mapping, self.signatures, self.features, 3)

    def test_ambiguous_resolution_rejected(self):
        self.signatures += [dict(signature="program", input_gene="X", target_id="Y")]
        with self.assertRaises(ValueError): audit(self.mapping, self.signatures, self.features, 3)

    def test_empty_supported_mapping(self):
        mapping, _, coverage = audit(self.mapping, self.signatures, self.features, 100)
        self.assertEqual(mapping, [])
        self.assertTrue(all(r["retained_input_fraction"] == 0 and r["score_eligible"] == "" for r in coverage))

    def test_cli_roundtrip_and_gate_argument_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for name, rows in [("mapping", self.mapping), ("signatures", self.signatures), ("features", self.features)]:
                write_tsv(folder / (name + ".tsv"), rows, list(rows[0]))
            command = [sys.executable, str(Path(__file__).with_name("audit_coverage.py"))]
            for name in ["mapping", "signatures", "features"]:
                command += ["--" + name, str(folder / (name + ".tsv"))]
            command += ["--min-score", "3", "--out-dir", str(folder / "results")]
            self.assertEqual(run(command, capture_output=True).returncode, 0)
            output = read_tsv(folder / "results/signature_coverage.tsv", ["score_eligible"])
            self.assertTrue(all(r["score_eligible"] == "" for r in output))
            self.assertNotEqual(run(command + ["--min-genes", "2"], capture_output=True).returncode, 0)


if __name__ == "__main__":
    unittest.main()
