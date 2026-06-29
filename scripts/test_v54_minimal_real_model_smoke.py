"""Smoke test for scripts/v54_minimal_real_model_smoke.py.

Run:
    python3 scripts/test_v54_minimal_real_model_smoke.py
"""
from __future__ import annotations

import csv
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT = SCRIPTS_DIR.parent
TOOL = SCRIPTS_DIR / "v54_minimal_real_model_smoke.py"


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        out = tmp / "smoke"
        summary = tmp / "summary.csv"
        decision = tmp / "decision.csv"
        proc = subprocess.run(
            [
                sys.executable,
                str(TOOL),
                "--out",
                str(out),
                "--summary",
                str(summary),
                "--decision",
                str(decision),
            ],
            cwd=str(ROOT),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        assert proc.returncode == 0, proc.stderr

        summary_row = read_csv(summary)[0]
        expected = {
            "v54_minimal_real_model_smoke_ready": "1",
            "contract_ready": "1",
            "fixture_execution_ready": "1",
            "real_model_execution_ready": "1",
            "heldout_metric_ready": "1",
            "human_review_ready": "0",
            "independent_reproduction_ready": "0",
            "release_ready": "0",
            "train_rows": "4",
            "heldout_rows": "4",
            "train_heldout_repo_overlap_rows": "0",
            "heldout_exact_match": "1.000000",
            "free_running_decode_rows": "4",
            "teacher_forcing_used_rows": "0",
            "raw_prompt_context_bytes": "0",
            "source_locator_leakage_rows": "0",
            "raw_output_hash_bound_rate": "1.000000",
            "external_label_source_ready": "0",
            "synthetic_dataset": "1",
            "network_or_download_used": "0",
            "gpu_execution_used": "0",
            "checkpoint_downloaded": "0",
            "external_api_used": "0",
            "v54_full_generation_intake_ready": "0",
            "public_comparison_claim_ready": "0",
            "real_release_package_ready": "0",
        }
        for field, value in expected.items():
            assert summary_row.get(field) == value, f"{field}: expected {value}, got {summary_row.get(field)}"

        train_repos = {row["repo_id"] for row in read_csv(out / "train_split_rows.csv")}
        heldout_repos = {row["repo_id"] for row in read_csv(out / "heldout_split_rows.csv")}
        assert train_repos.isdisjoint(heldout_repos)

        generation_rows = read_csv(out / "free_running_generation_rows.csv")
        assert len(generation_rows) == 4
        for row in generation_rows:
            assert row["free_running_decode"] == "1"
            assert row["teacher_forcing_used"] == "0"
            assert row["raw_prompt_context_bytes"] == "0"
            assert row["source_locator_leakage"] == "0"
            assert row["external_api_used"] == "0"
            assert row["raw_output_sha256"] == sha256_text(row["generated_text"])

        metric = read_csv(out / "heldout_metric_rows.csv")[0]
        assert metric == {
            "split": "heldout",
            "metric": "exact_match",
            "value": "1.000000",
            "n": "4",
            "heldout_metric_ready": "1",
        }

        manifest = json.loads((out / "v54_minimal_real_model_smoke_manifest.json").read_text(encoding="utf-8"))
        assert manifest["real_model_execution_ready"] == 1
        assert manifest["heldout_metric_ready"] == 1
        assert manifest["human_review_ready"] == 0
        assert manifest["independent_reproduction_ready"] == 0
        assert manifest["release_ready"] == 0

        sha_rows = {row["path"]: row["sha256"] for row in read_csv(out / "sha256_manifest.csv")}
        for rel, digest in sha_rows.items():
            assert digest == sha256_file(out / rel), rel

        decisions = {row["gate"]: row["status"] for row in read_csv(decision)}
        for gate in ["local-model-training", "free-running-heldout-execution", "heldout-metric"]:
            assert decisions[gate] == "pass"
        for gate in ["external-label-source", "human-review", "independent-reproduction", "release-package"]:
            assert decisions[gate] == "blocked"

    print("v54 minimal real-model smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
