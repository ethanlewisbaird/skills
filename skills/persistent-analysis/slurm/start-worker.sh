#!/usr/bin/env bash
# Resources are supplied explicitly by `persistent-analysis start` or srun flags.
set -euo pipefail
umask 077
: "${SLURM_JOB_ID:?Start this script through Slurm, never on the login node}"
session=$1
env_script=${2:-}
if [[ -n "$env_script" ]]; then
    source "$env_script"
fi
skill_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
exec python "$skill_dir/scripts/persistent_analysis.py" _worker "$session"
