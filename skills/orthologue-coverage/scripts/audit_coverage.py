#!/usr/bin/env python3
"""Audit numeric orthology support and signature coverage from normalized TSVs."""

import argparse
import csv
import hashlib
import json
import math
import os
import platform
import subprocess
import sys
from collections import defaultdict
from pathlib import Path


def read_tsv(path, required):
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if not set(required).issubset(reader.fieldnames or []):
            raise ValueError(f"{path}: required columns {required}")
        return list(reader)


def write_tsv(path, rows, columns):
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)


def boolean(value):
    if value.upper() not in {"TRUE", "FALSE"}:
        raise ValueError(f"Expected TRUE/FALSE, received {value!r}")
    return value.upper() == "TRUE"


def audit(mapping, signatures, features, min_score, min_genes=None, min_fraction=None):
    pairs = {}
    for row in mapping:
        key = row["source_id"], row["target_id"]
        score = float(row["score"])
        if not all(key) or not math.isfinite(score):
            raise ValueError("Mapping requires nonempty stable IDs and finite scores")
        if key in pairs and pairs[key] != score:
            raise ValueError(f"Conflicting scores for {key}")
        pairs[key] = score
    pairs = {key: score for key, score in pairs.items() if score >= min_score}
    by_source, by_target = defaultdict(list), defaultdict(list)
    for (source, target), score in pairs.items():
        by_source[source].append(score)
        by_target[target].append(score)
    best_source = {key: max(values) for key, values in by_source.items()}
    best_target = {key: max(values) for key, values in by_target.items()}
    primary = {(s, t) for (s, t), score in pairs.items()
               if score == best_source[s] == best_target[t]
               and by_source[s].count(score) == by_target[t].count(score) == 1}
    feature_flags = {}
    for row in features:
        gene = row["source_id"]
        flags = boolean(row["assayed"]), boolean(row["expressed"])
        if not gene or gene in feature_flags or (flags[1] and not flags[0]):
            raise ValueError("Features require unique nonempty IDs and expressed implies assayed")
        feature_flags[gene] = flags
    groups = defaultdict(dict)
    for row in signatures:
        name, original, target = row["signature"], row["input_gene"], row["target_id"]
        if not name or not original:
            raise ValueError("Signature and input_gene must be nonempty")
        if original in groups[name] and groups[name][original] != target:
            raise ValueError(f"Ambiguous normalized signature entry: {name}/{original}")
        groups[name][original] = target
    mapping_rows = [dict(source_id=s, target_id=t, score=pairs[s, t], primary_pair=(s, t) in primary)
                    for s, t in sorted(pairs)]
    coverage, gene_audit = [], []
    for policy in ["primary", "broader"]:
        partners = defaultdict(list)
        for (s, t), score in sorted(pairs.items()):
            if policy == "broader" or (s, t) in primary:
                partners[t].append((s, score))
        for name, entries in sorted(groups.items()):
            mapped, assayed, expressed, source_genes, retained = set(), set(), set(), set(), set()
            for original, target in sorted(entries.items()):
                candidates = partners.get(target, [])
                for source, score in candidates or [("", "")]:
                    measured, active = feature_flags.get(source, (False, False))
                    status = ("unresolved_target" if not target else "no_selected_orthologue" if not source
                              else "unassayed" if not measured else "below_expression_rule" if not active
                              else "expressed")
                    gene_audit.append(dict(signature=name, input_gene=original, target_id=target,
                                           mapping=policy, source_id=source, score=score,
                                           assayed=measured, expressed=active, status=status))
                    if source:
                        mapped.add(target)
                    if measured:
                        assayed.add(target)
                    if active:
                        expressed.add(target)
                        source_genes.add(source)
                        retained.add(original)
            resolved = {t for t in entries.values() if t}
            fraction = len(retained) / len(entries)
            eligible = (len(source_genes) >= min_genes and fraction >= min_fraction
                        if min_genes is not None else "")
            coverage.append(dict(signature=name, mapping=policy, original_input_genes=len(entries),
                                 resolved_target_genes=len(resolved),
                                 resolved_entries_sharing_target=sum(bool(t) for t in entries.values())-len(resolved),
                                 target_genes_mapped=len(mapped), target_genes_assayed=len(assayed),
                                 target_genes_expressed=len(expressed), input_genes_retained=len(retained),
                                 distinct_source_genes_expressed=len(source_genes),
                                 retained_input_fraction=fraction, score_eligible=eligible))
    return mapping_rows, gene_audit, coverage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["mapping", "signatures", "features", "out-dir"]:
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--min-score", type=float, required=True)
    parser.add_argument("--min-genes", type=int)
    parser.add_argument("--min-fraction", type=float)
    args = parser.parse_args()
    if (args.min_genes is None) != (args.min_fraction is None):
        parser.error("Specify both --min-genes and --min-fraction, or neither")
    if not math.isfinite(args.min_score) or (args.min_genes is not None and
            (args.min_genes < 1 or not 0 <= args.min_fraction <= 1)):
        parser.error("Use a finite support threshold, positive gene minimum and fraction in [0,1]")
    mapping = read_tsv(args.mapping, ["source_id", "target_id", "score"])
    signatures = read_tsv(args.signatures, ["signature", "input_gene", "target_id"])
    features = read_tsv(args.features, ["source_id", "assayed", "expressed"])
    if not mapping or not signatures or not features:
        parser.error("Input tables must contain data rows")
    outputs = audit(mapping, signatures, features, args.min_score, args.min_genes, args.min_fraction)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    for name, rows in zip(["orthologue_mapping", "signature_gene_audit", "signature_coverage"], outputs):
        columns = list(rows[0]) if rows else ["source_id", "target_id", "score", "primary_pair"]
        write_tsv(args.out_dir / (name + ".tsv"), rows, columns)
    inputs = {name: {"path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
              for name, path in [("mapping", args.mapping), ("signatures", args.signatures),
                                 ("features", args.features)]}
    skill_root = Path(__file__).resolve().parent.parent
    git_info = {}
    for key, command in [("commit", ["rev-parse", "HEAD"]), ("source_changes", ["status", "--short", "--", "."])]:
        result = subprocess.run(["git", *command], cwd=skill_root, text=True, capture_output=True)
        git_info[key] = result.stdout.strip() if result.returncode == 0 else None
    record = dict(command=[sys.executable, *sys.argv], inputs=inputs,
                  parameters={"min_score": args.min_score, "min_genes": args.min_genes,
                              "min_fraction": args.min_fraction},
                  python=platform.python_version(), slurm_job_id=os.getenv("SLURM_JOB_ID"), git=git_info,
                  script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  policy="Unique reciprocal score-best pairs versus all supplied pairs at/above min_score")
    (args.out_dir / "coverage_run.json").write_text(json.dumps(record, indent=2) + "\n")
    print(f"Audited {len(signatures)} input rows across {len(outputs[2])} signature/policy combinations.")


if __name__ == "__main__":
    main()
