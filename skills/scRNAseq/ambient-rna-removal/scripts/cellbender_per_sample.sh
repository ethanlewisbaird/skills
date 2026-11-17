#!/bin/bash
# CellBender remove-background for one capture.
#
# CellBender models the background jointly with cells on the RAW (unfiltered)
# matrix, so its output carries its own cell calls. Adopting those calls changes
# every downstream rate; keep Cell Ranger's calls unless that is decided.
#
# Usage: sbatch cellbender_per_sample.sh <raw_h5> <sample_name> <out_dir> [fpr] [epochs]
#SBATCH --job-name=cellbender
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00

set -euo pipefail

RAW_H5=$1
SAMPLE=$2
OUT_DIR=$3
FPR=${4:-0.01}          # target false-positive rate; a methodological setting
EPOCHS=${5:-150}        # training length; a methodological setting

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

cellbender remove-background \
  --input "$RAW_H5" \
  --output "${SAMPLE}_CB_output.h5" \
  --fpr "$FPR" \
  --epochs "$EPOCHS"

# Retain the metrics table: it holds the estimated background fraction and the
# cell count CellBender proposes, both of which the provenance record needs.
ls -1 "${SAMPLE}_CB_output"*
