"""Smoke tests for scripts/release_review_collection.py.

Run:
    python3 scripts/test_release_review_collection.py
"""
from __future__ import annotations

import csv
import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT = SCRIPTS_DIR.parent
TOOL = SCRIPTS_DIR / "release_review_collection.py"


def sha(value: str) -> str:
    return "sha256:" + hashlib.sha256(value.encode("utf-8")).hexdigest()


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def run_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def build_fixture_input(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    human_cols = [
        "blind_response_id",
        "reviewer_id",
        "reviewer_pool_id",
        "reviewer_independent",
        "reviewer_blinded",
        "conflict_disclosed",
        "review_decision",
        "review_sha256",
        "synthetic",
        "template_only",
        "test_fixture",
    ]
    write_csv(
        path / "human_review_rows.csv",
        human_cols,
        [
            {
                "blind_response_id": "blind-response-001",
                "reviewer_id": "reviewer-alpha",
                "reviewer_pool_id": "pool-alpha",
                "reviewer_independent": "true",
                "reviewer_blinded": "true",
                "conflict_disclosed": "true",
                "review_decision": "accept",
                "review_sha256": sha("review-alpha"),
                "synthetic": "0",
                "template_only": "0",
                "test_fixture": "1",
            },
            {
                "blind_response_id": "blind-response-001",
                "reviewer_id": "reviewer-beta",
                "reviewer_pool_id": "pool-beta",
                "reviewer_independent": "true",
                "reviewer_blinded": "true",
                "conflict_disclosed": "true",
                "review_decision": "reject",
                "review_sha256": sha("review-beta"),
                "synthetic": "0",
                "template_only": "0",
                "test_fixture": "1",
            },
        ],
    )
    adjudication_cols = [
        "blind_response_id",
        "metric",
        "reviewer_a_id",
        "reviewer_b_id",
        "needs_adjudication",
        "adjudicated_value",
        "adjudicator_id",
        "adjudicator_independent",
        "adjudication_sha256",
        "synthetic",
        "template_only",
        "test_fixture",
    ]
    write_csv(
        path / "adjudication_rows.csv",
        adjudication_cols,
        [
            {
                "blind_response_id": "blind-response-001",
                "metric": "review_decision",
                "reviewer_a_id": "reviewer-alpha",
                "reviewer_b_id": "reviewer-beta",
                "needs_adjudication": "1",
                "adjudicated_value": "accept",
                "adjudicator_id": "adjudicator-gamma",
                "adjudicator_independent": "true",
                "adjudication_sha256": sha("adjudication"),
                "synthetic": "0",
                "template_only": "0",
                "test_fixture": "1",
            }
        ],
    )
    repro_cols = [
        "reproduction_id",
        "reproducer_id",
        "reproducer_independent",
        "conflict_disclosed",
        "command",
        "exit_code",
        "output_manifest_sha256",
        "metric_rows_sha256",
        "environment_sha256",
        "started_at_utc",
        "finished_at_utc",
        "synthetic",
        "template_only",
        "test_fixture",
    ]
    write_csv(
        path / "independent_reproduction_rows.csv",
        repro_cols,
        [
            {
                "reproduction_id": "repro-001",
                "reproducer_id": "reproducer-delta",
                "reproducer_independent": "true",
                "conflict_disclosed": "true",
                "command": "./scripts/run_minimal_demo.sh",
                "exit_code": "0",
                "output_manifest_sha256": sha("output-manifest"),
                "metric_rows_sha256": sha("metric-rows"),
                "environment_sha256": sha("environment"),
                "started_at_utc": "2026-06-29T00:00:00Z",
                "finished_at_utc": "2026-06-29T00:01:00Z",
                "synthetic": "0",
                "template_only": "0",
                "test_fixture": "1",
            }
        ],
    )


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        tmpl = tmp / "template"
        proc = run_tool("template", "--out", str(tmpl))
        assert proc.returncode == 0, proc.stderr
        for name in ["human_review_rows.csv", "adjudication_rows.csv", "independent_reproduction_rows.csv"]:
            assert (tmpl / name).is_file()

        out = tmp / "blocked"
        summary = tmp / "blocked_summary.csv"
        decision = tmp / "blocked_decision.csv"
        proc = run_tool("collect", "--out", str(out), "--summary", str(summary), "--decision", str(decision))
        assert proc.returncode == 0, proc.stderr
        row = read_csv(summary)[0]
        assert row["actual_collection_ready"] == "0"
        assert row["human_review_packet_collected"] == "0"
        assert row["independent_reproduction_packet_collected"] == "0"
        assert row["release_ready"] == "0"
        decisions = {r["gate"]: r["status"] for r in read_csv(decision)}
        assert decisions["actual-human-independent-collection"] == "blocked"

        fixture = tmp / "fixture_input"
        build_fixture_input(fixture)
        out = tmp / "fixture_out"
        summary = tmp / "fixture_summary.csv"
        decision = tmp / "fixture_decision.csv"
        proc = run_tool(
            "collect",
            "--input-dir",
            str(fixture),
            "--out",
            str(out),
            "--summary",
            str(summary),
            "--decision",
            str(decision),
            "--allow-test-fixture",
        )
        assert proc.returncode == 0, proc.stderr
        row = read_csv(summary)[0]
        assert row["collection_mode"] == "test-fixture"
        assert row["test_fixture_collection_ready"] == "1"
        assert row["actual_collection_ready"] == "0"
        assert row["human_review_packet_collected"] == "0"
        assert row["independent_reproduction_packet_collected"] == "0"
        assert row["human_review_ready"] == "0"
        assert row["independent_reproduction_ready"] == "0"
        assert row["release_ready"] == "0"
        sha_rows = read_csv(out / "sha256_manifest.csv")
        assert any(r["path"] == "supplied/human_review_rows.csv" for r in sha_rows)

        # The same fixture rows must be blocked in actual mode.
        out = tmp / "actual_blocked"
        summary = tmp / "actual_blocked_summary.csv"
        decision = tmp / "actual_blocked_decision.csv"
        proc = run_tool(
            "collect",
            "--input-dir",
            str(fixture),
            "--out",
            str(out),
            "--summary",
            str(summary),
            "--decision",
            str(decision),
        )
        assert proc.returncode == 0, proc.stderr
        row = read_csv(summary)[0]
        assert row["actual_collection_ready"] == "0"
        assert row["blocking_reason"] == "human row 1: test-fixture-row"

    print("release review collection smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
