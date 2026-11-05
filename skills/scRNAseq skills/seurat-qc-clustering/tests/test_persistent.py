"""Two real queue tasks in one isolated synthetic R worker under Slurm."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
skill = Path(__file__).resolve().parents[1]
bridge = Path(os.environ.get("PERSISTENT_ANALYSIS_SKILL", str(Path.home() / ".codex/skills/persistent-analysis")))
core = bridge / "scripts/persistent_analysis.py"
spec = importlib.util.spec_from_file_location("persistent_analysis", core)
pa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pa)


def main():
    if not os.environ.get("SLURM_JOB_ID"):
        raise RuntimeError("Run this synthetic test inside a short Slurm allocation")
    logs = skill / "logs"
    logs.mkdir(exist_ok=True)
    # The /data mount does not preserve POSIX ownership/mode 700; use private home state.
    state = Path.home() / ".local/state"
    state.mkdir(exist_ok=True, parents=True)
    with tempfile.TemporaryDirectory(prefix="persistent-qc-test-", dir=state) as tmp:
        project = Path(tmp)
        root = project / "registry"
        session = pa.prepare(root, "synthetic-qc-r", "r", project)
        with (project / "worker.log").open("w") as log:
            worker = subprocess.Popen([sys.executable, str(core), "_worker", str(session)], stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 50
                while pa.status(session)["state"] != "ready":
                    if worker.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError((project / "worker.log").read_text())
                    time.sleep(0.2)
                pid = pa.status(session)["pid"]
                first = f'''
source({json.dumps(str(skill / "scripts/qc_clustering.R"))})
qc_resources()
set.seed(9)
x <- matrix(rpois(80 * 40, 2), nrow=80,
  dimnames=list(paste0("G",1:80),paste0("BC",1:40)))
seu <- qc_import(list(synthetic=list(type="matrix",matrix=x,
  expression_type="counts",sample_id="S1")), data.frame(sample_id="S1",capture_id="capture1"))
seu <- qc_metrics(seu)
original_cells <- colnames(seu)
initial_pid <- Sys.getpid()
initial_history <- length(qc_info(seu)$history)
rm(x)
'''
                task1 = pa.submit(session, first)
                result1 = pa.wait(session, task1, 60)
                if result1["state"] != "successful":
                    raise RuntimeError(json.dumps(result1))
                second = f'''
stopifnot(exists("seu"), !exists("x"), identical(initial_pid, Sys.getpid()),
  identical(original_cells, colnames(seu)), length(qc_info(seu)$history) == initial_history)
preview <- qc_preview(seu, {json.dumps(str(project / "outputs"))})
stopifnot(length(preview$files) >= 1L)
many <- do.call(rbind, lapply(1:7, function(i) {{
  d <- qc_metadata(seu); d$sample_id <- paste0("sample",i)
  rownames(d) <- paste0("input",i,"::",rownames(d)); d
}}))
without_last <- many[many$sample_id != "sample7",,drop=FALSE]
pages <- qc_plot_qc(without_last, {json.dumps(str(project / "outputs"))}, reference=many,
  prefix="paginated", plots="scatter")
stopifnot(length(pages)==2L,all(file.exists(pages)))
print(initial_pid)
'''
                task2 = pa.submit(session, second)
                result2 = pa.wait(session, task2, 60)
                if result2["state"] != "successful":
                    raise RuntimeError(json.dumps(result2))
                if pa.status(session)["pid"] != pid:
                    raise AssertionError("Persistent interpreter changed")
                if not list((project / "outputs/figs").glob("*.jpeg")):
                    raise AssertionError("Follow-up plot was not saved")
                print(json.dumps({"result": "PASS", "check": "same R PID and object across two queue tasks; follow-up JPEG without reload",
                                  "pid": pid, "job_id": os.environ["SLURM_JOB_ID"], "task_ids": [task1, task2]}))
            finally:
                # This test owns the temporary worker and its lifecycle, not user sessions.
                (session / "stop-requested").touch()
                try:
                    worker.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    worker.kill()
                    worker.wait(timeout=5)
                time.sleep(2.2)


if __name__ == "__main__":
    main()
