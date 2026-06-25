"""Deterministic smoke test for scripts/de_execution_packet.py.

Generates a template, fills it with synthetic schema-test values (allowed only
for schema testing, never as measured evidence), and checks that preflight
passes on a valid packet and blocks an unsafe one.

Run:  python3 scripts/test_de_execution_packet.py
"""
from __future__ import annotations

import csv
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT = SCRIPTS_DIR.parent
TOOL = SCRIPTS_DIR / "de_execution_packet.py"
CONTRACT = ROOT / "baselines" / "de_30b70b_real.json"

SHA = "a" * 64
NUMERIC = {
    "parameter_count_b",
    "context_budget",
    "retrieval_budget",
    "seed",
    "raw_prompt_context_bytes",
    "retrieved_span_rows",
    "latency_ns",
    "peak_memory_mb",
}


def fill_value(field: str) -> str:
    if field == "external_api_used":
        return "0"
    if field == "non_fixture_declared":
        return "true"
    if field.endswith("_sha256"):
        return SHA
    if field in NUMERIC:
        return "1"
    return "x"


def fill_csv(path: Path) -> None:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        header = list(reader.fieldnames or [])
        rows = list(reader)
    for row in rows:
        for field in header:
            if not (row.get(field) or "").strip():
                row[field] = fill_value(field)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def run_tool(*args: str) -> int:
    return subprocess.run(
        [sys.executable, str(TOOL), "--contract", str(CONTRACT), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    ).returncode


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        packet = Path(tmp) / "de_canary"
        assert run_tool("template", "--out", str(packet), "--systems", "D,E", "--rows-per-system", "2") == 0
        for name in ("model_identity.csv", "answer_citation_raw_output.csv", "resource_evaluator_manifest.csv"):
            assert (packet / name).is_file(), name
            fill_csv(packet / name)

        # A fully and validly filled packet must pass preflight.
        assert run_tool("preflight", "--packet", str(packet), "--systems", "D,E", "--rows-per-system", "2") == 0
        print("preflight: valid filled packet PASS")

        # An external API call must be blocked.
        ans = packet / "answer_citation_raw_output.csv"
        _flip_field(ans, "external_api_used", "1")
        assert run_tool("preflight", "--packet", str(packet), "--systems", "D,E", "--rows-per-system", "2") == 1
        print("preflight: external_api_used=1 BLOCKED")

        # Restore, then break row count expectation.
        _flip_field(ans, "external_api_used", "0")
        assert run_tool("preflight", "--packet", str(packet), "--systems", "D,E", "--rows-per-system", "99") == 1
        print("preflight: wrong row count BLOCKED")

    print("de execution packet smoke OK (staging/preflight only; admits no evidence)")
    return 0


def _flip_field(path: Path, field: str, value: str) -> None:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        header = list(reader.fieldnames or [])
        rows = list(reader)
    if rows:
        rows[0][field] = value
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    raise SystemExit(main())
