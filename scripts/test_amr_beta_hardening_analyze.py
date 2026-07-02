#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_hardening_analyze.py."""
from __future__ import annotations

import csv
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import amr_beta_hardening_analyze as hardening_analyze

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_hardening_analyze.py"


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def make_benchmark_out(path: Path) -> None:
    path.mkdir()
    confusion_fields = [
        "case_id", "row_type", "label_id", "plugin_id", "rule_id", "file_path",
        "expected_line_start", "expected_line_end", "expected_span_sha256", "expected",
        "priority", "matched_finding_id", "citation_expectation_supplied",
        "matched_citation_id", "citation_expectation_met", "outcome", "tp", "fp", "fn", "tn",
    ]
    write_csv(
        path / "benchmark_confusion_rows.csv",
        confusion_fields,
        [
            {
                "case_id": "case-a", "row_type": "label", "label_id": "l1", "plugin_id": "static",
                "rule_id": "danger", "file_path": "src/a.py", "expected_line_start": "1",
                "expected_line_end": "1", "expected_span_sha256": "sha256:" + ("a" * 64),
                "expected": "present", "priority": "P1", "matched_finding_id": "f1",
                "citation_expectation_supplied": "1", "matched_citation_id": "c1",
                "citation_expectation_met": "0", "outcome": "FP", "tp": "0", "fp": "1",
                "fn": "0", "tn": "0",
            },
            {
                "case_id": "case-b", "row_type": "label", "label_id": "l2", "plugin_id": "static",
                "rule_id": "missing", "file_path": "src/b.py", "expected_line_start": "2",
                "expected_line_end": "2", "expected_span_sha256": "sha256:" + ("b" * 64),
                "expected": "present", "priority": "P0", "matched_finding_id": "",
                "citation_expectation_supplied": "1", "matched_citation_id": "",
                "citation_expectation_met": "0", "outcome": "FN", "tp": "0", "fp": "0",
                "fn": "1", "tn": "0",
            },
        ],
    )
    citation_fields = [
        "case_id", "finding_id", "citation_id", "file_path", "line_start", "line_end",
        "file_exists", "file_sha256_valid", "source_manifest_sha256_valid",
        "line_bounds_valid", "span_sha256_valid", "span_preview_valid",
        "citation_valid", "invalid_reasons",
    ]
    write_csv(
        path / "benchmark_citation_validity.csv",
        citation_fields,
        [
            {
                "case_id": "case-a", "finding_id": "f1", "citation_id": "c1",
                "file_path": "src/a.py", "line_start": "1", "line_end": "1",
                "file_exists": "1", "file_sha256_valid": "0",
                "source_manifest_sha256_valid": "1", "line_bounds_valid": "1",
                "span_sha256_valid": "0", "span_preview_valid": "1",
                "citation_valid": "0", "invalid_reasons": "file_sha256_valid|span_sha256_valid",
            }
        ],
    )
    quality_fields = [
        "case_id", "label_id", "plugin_id", "rule_id", "file_path",
        "expected_line_start", "expected_line_end", "expected_span_sha256", "expected",
        "priority", "is_broad", "is_citation_unbound", "citation_expectation_supplied",
        "is_duplicate", "is_contradictory", "is_specific",
    ]
    write_csv(
        path / "benchmark_label_quality.csv",
        quality_fields,
        [
            {
                "case_id": "case-a", "label_id": "l1", "plugin_id": "static",
                "rule_id": "danger", "file_path": "src/a.py", "expected_line_start": "1",
                "expected_line_end": "1", "expected_span_sha256": "sha256:" + ("a" * 64),
                "expected": "present", "priority": "P1", "is_broad": "0",
                "is_citation_unbound": "1", "citation_expectation_supplied": "0",
                "is_duplicate": "0", "is_contradictory": "0", "is_specific": "0",
            }
        ],
    )
    write_json(
        path / "benchmark_readiness.json",
        {
            "design_partner_beta_candidate_ready": 0,
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
        },
    )


def run_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        assert hardening_analyze.is_forbidden_env_path(Path(".env.secrets") / "hardening.json")
        assert hardening_analyze.is_forbidden_env_path(tmp / ".env.secrets" / "hardening.json")
        assert not hardening_analyze.is_forbidden_env_path(tmp / "hardening.json")
        benchmark = tmp / "benchmark"
        make_benchmark_out(benchmark)
        out_json = tmp / "hardening.json"
        out_md = tmp / "hardening.md"
        proc = run_tool(
            "--benchmark-out",
            str(benchmark),
            "--out-json",
            str(out_json),
            "--out-md",
            str(out_md),
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(out_json.read_text(encoding="utf-8"))
        assert payload["fp_rows"] == 1
        assert payload["fn_rows"] == 1
        assert payload["citation_failed_rows"] == 1
        assert payload["is_citation_unbound_rows"] == 1
        assert payload["backlog_items"] >= 4
        assert payload["release_ready"] == 0
        assert "precision_hardening" in out_md.read_text(encoding="utf-8")

        bad = tmp / "bad"
        make_benchmark_out(bad)
        readiness = json.loads((bad / "benchmark_readiness.json").read_text(encoding="utf-8"))
        readiness["release_ready"] = 1
        write_json(bad / "benchmark_readiness.json", readiness)
        proc = run_tool("--benchmark-out", str(bad), "--out-json", str(tmp / "bad.json"))
        assert proc.returncode == 1
        assert "must keep release_ready=0" in proc.stderr

    print("AMR beta hardening analyze smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
