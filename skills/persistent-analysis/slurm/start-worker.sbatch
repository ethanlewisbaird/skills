#!/usr/bin/env bash
# Resources are supplied explicitly by `persistent-analysis start` or sbatch/srun flags.
set -euo pipefail
umask 077
: "${SLURM_JOB_ID:?Start this script through Slurm, never on the login node}"
session=$1
env_script=${2:-}
if [[ -n "$env_script" ]]; then
    source "$env_script"
fi
# sbatch copies this file into a spool directory, so BASH_SOURCE is not the install path.
skill_dir=${3:?Supply the original skill directory as the third argument}
exec python "$skill_dir/scripts/persistent_analysis.py" _worker "$session"
