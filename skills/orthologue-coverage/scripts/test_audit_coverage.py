#!/usr/bin/env python3
"""Small synthetic checks; no expression objects or external inputs are loaded."""

import random
import copy
import tempfile
import unittest
from pathlib import Path
from subprocess import run
import sys

from audit_coverage import audit, diagnose, read_tsv, write_tsv


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
            self.assertEqual(run(command + ["--max-component-genes", "1"], capture_output=True).returncode, 0)
            warnings = read_tsv(folder / "results/mapping_warnings.tsv", ["kind"])
            self.assertTrue(any(r["kind"] == "large_candidate_component" for r in warnings))
            self.assertNotEqual(run(command + ["--min-shared-genes", "0"], capture_output=True).returncode, 0)

    def test_global_component_chaining_and_threshold_boundary(self):
        mapping = [dict(source_id=s,target_id=t,score=v) for s,t,v in
                   [("A","X",9),("B","X",8),("B","Y",7),("C","Y",6),("C","Z",5)]]
        signatures = [dict(signature="one_target",input_gene="X",target_id="X")]
        features = [dict(source_id=s,assayed="TRUE",expressed="TRUE") for s in ["A","B","C"]]
        mapped, genes, _ = audit(mapping,signatures,features,3)
        families, _, warnings = diagnose(mapped,genes,max_component_genes=2)
        row = next(r for r in families if r["mapping"]=="broader")
        self.assertEqual((row["expressed_source_genes"],row["candidate_mapping_components"]),(2,1))
        self.assertEqual((row["max_component_source_genes"],row["max_component_target_genes"]),(3,3))
        self.assertEqual(row["component_target_genes_outside_signature"],2)
        self.assertEqual(len(warnings),1)
        self.assertEqual(diagnose(mapped,genes,max_component_genes=3)[2],[])

    def test_overlap_uses_smaller_set_and_minimum_shared_count(self):
        mapping = [dict(source_id=str(i),target_id="T"+str(i),score=9) for i in range(1,6)]
        signatures = [dict(signature=name,input_gene="T"+str(i),target_id="T"+str(i))
                      for name,indices in [("A",[1,2,3,4]),("B",[2,3,4,5]),("C",[4])] for i in indices]
        features = [dict(source_id=str(i),assayed="TRUE",expressed="TRUE") for i in range(1,6)]
        mapped, genes, _ = audit(mapping,signatures,features,3)
        _, overlaps, warnings = diagnose(mapped,genes,overlap_fraction=.75,min_shared_genes=2)
        ab = next(r for r in overlaps if r["mapping"]=="primary" and (r["signature_a"],r["signature_b"])==("A","B"))
        self.assertEqual((ab["shared_source_genes"],ab["smaller_set_fraction_shared"]),(3,.75))
        self.assertAlmostEqual(ab["jaccard"],3/5)
        self.assertEqual(len(warnings),2)  # The same pair under primary and broader policies.
        self.assertTrue(all((r["signature_a"],r["signature_b"])==("A","B") for r in warnings))

    def test_diagnostics_preserve_inputs_and_are_order_invariant(self):
        mapped, genes, _ = audit(self.mapping,self.signatures,self.features,3)
        original = copy.deepcopy((mapped,genes))
        expected = diagnose(mapped,genes,max_component_genes=1)
        self.assertEqual((mapped,genes),original)
        random.Random(4).shuffle(mapped); random.Random(8).shuffle(genes)
        self.assertEqual(diagnose(mapped,genes,max_component_genes=1),expected)

    def test_diagnostics_keep_assays_separate_and_handle_empty_sets(self):
        mapped, genes, _ = audit(self.mapping,self.signatures,self.features,3)
        a = [dict(r,assay="exon",signature="A") for r in genes]
        b = [dict(r,assay="utr",signature="B") for r in genes]
        self.assertEqual(diagnose(mapped,a+b,min_shared_genes=1)[1],[])
        mapped, genes, _ = audit(self.mapping,self.signatures,self.features,100)
        families, overlaps, warnings = diagnose(mapped,genes)
        self.assertTrue(all(r["candidate_mapping_components"]==0 for r in families))
        self.assertEqual((overlaps,warnings),([],[]))


if __name__ == "__main__":
    unittest.main()
