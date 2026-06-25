"""Deterministic smoke test for scripts/de_execution_packet.py (preflight v2).

Generates a template, fills it with synthetic schema-test values (allowed only
for schema testing, never as measured evidence), and checks the v2 preflight:
exact header order, explicit external_api, parameter range, system/query
uniqueness, cross-file consistency, v53 frozen-query binding, sha256 manifest.

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
PARAM_BY_SYSTEM = {"D": "30", "E": "70"}
SYSTEMS = ["D", "E"]
ROWS_PER_SYSTEM = 2


def base_value(field: str) -> str:
    if field == "external_api_used":
        return "0"
    if field == "non_fixture_declared":
        return "true"
    if field.endswith("_sha256"):
        return SHA
    if field in NUMERIC:
        return "1"
    return "x"


def read_rows(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def write_rows(path: Path, header: list[str], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def fill_file(path: Path, mutate) -> None:
    header, rows = read_rows(path)
    for index, row in enumerate(rows):
        for field in header:
            if not (row.get(field) or "").strip():
                row[field] = base_value(field)
        mutate(index, row)
    write_rows(path, header, rows)


def fill_packet(packet: Path) -> None:
    def mi(_i, row):
        sid = row["system_id"]
        row["model_id"] = f"model-{sid}"
        row["parameter_count_b"] = PARAM_BY_SYSTEM[sid]

    def ac(_i, row):
        row["model_id"] = f"model-{row['system_id']}"

    def re_(i, row):
        row["model_id"] = f"model-{SYSTEMS[i // ROWS_PER_SYSTEM]}"

    fill_file(packet / "model_identity.csv", mi)
    fill_file(packet / "answer_citation_raw_output.csv", ac)
    fill_file(packet / "resource_evaluator_manifest.csv", re_)


def run_tool(*args: str) -> int:
    return subprocess.run(
        [sys.executable, str(TOOL), "--contract", str(CONTRACT), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    ).returncode


def template(packet: Path) -> None:
    assert run_tool(
        "template", "--out", str(packet), "--systems", ",".join(SYSTEMS),
        "--rows-per-system", str(ROWS_PER_SYSTEM),
    ) == 0


def preflight(packet: Path, *extra: str) -> int:
    return run_tool(
        "preflight", "--packet", str(packet), "--systems", ",".join(SYSTEMS),
        "--rows-per-system", str(ROWS_PER_SYSTEM), *extra,
    )


def fresh(tmp: Path, name: str) -> Path:
    packet = tmp / name
    template(packet)
    fill_packet(packet)
    return packet


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)

        # 1. Valid filled packet passes.
        packet = fresh(tmp, "valid")
        assert preflight(packet) == 0
        print("preflight: valid v2 packet PASS")

        # 2. sha256 manifest: generate, then --require-manifest passes.
        assert run_tool("manifest", "--packet", str(packet)) == 0
        assert (packet / "sha256_manifest.csv").is_file()
        assert preflight(packet, "--require-manifest") == 0
        # Tamper a file -> manifest sha mismatch blocks.
        ans = packet / "answer_citation_raw_output.csv"
        ans.write_text(ans.read_text(encoding="utf-8") + "\n", encoding="utf-8")
        assert preflight(packet, "--require-manifest") == 1
        print("manifest: generate + verify + tamper-detect OK")

        # 3. Empty external_api blocked (v2: must be explicit).
        p = fresh(tmp, "empty_api")
        _set_first(p / "answer_citation_raw_output.csv", "external_api_used", "")
        assert preflight(p) == 1
        print("preflight: empty external_api BLOCKED")

        # 4. external_api=1 blocked.
        p = fresh(tmp, "api_on")
        _set_first(p / "answer_citation_raw_output.csv", "external_api_used", "1")
        assert preflight(p) == 1
        print("preflight: external_api=1 BLOCKED")

        # 5. parameter_count_b out of range blocked (D must be 25-40).
        p = fresh(tmp, "param_oor")
        _set_first(p / "model_identity.csv", "parameter_count_b", "70")
        assert preflight(p) == 1
        print("preflight: parameter range BLOCKED")

        # 6. Header reorder blocked (exact order required).
        p = fresh(tmp, "reorder")
        _swap_header(p / "resource_evaluator_manifest.csv")
        assert preflight(p) == 1
        print("preflight: header reorder BLOCKED")

        # 7. Cross-file query inconsistency blocked.
        p = fresh(tmp, "xfile")
        _set_first(p / "resource_evaluator_manifest.csv", "query_id", "q9999")
        assert preflight(p) == 1
        print("preflight: cross-file query mismatch BLOCKED")

        # 8. v53 frozen-query binding: matching set passes, mismatch blocks.
        p = fresh(tmp, "v53bind")
        good = tmp / "frozen_good.csv"
        write_rows(good, ["query_id"], [{"query_id": "q0001"}, {"query_id": "q0002"}])
        assert preflight(p, "--v53-query-manifest", str(good)) == 0
        bad = tmp / "frozen_bad.csv"
        write_rows(bad, ["query_id"], [{"query_id": "q0001"}, {"query_id": "q9999"}])
        assert preflight(p, "--v53-query-manifest", str(bad)) == 1
        print("preflight: v53 frozen-query binding OK")

    print("de execution packet v2 smoke OK (staging/preflight only; admits no evidence)")
    return 0


def _set_first(path: Path, field: str, value: str) -> None:
    header, rows = read_rows(path)
    if rows:
        rows[0][field] = value
    write_rows(path, header, rows)


def _swap_header(path: Path) -> None:
    header, rows = read_rows(path)
    if len(header) >= 2:
        header[0], header[1] = header[1], header[0]
    write_rows(path, header, rows)


if __name__ == "__main__":
    raise SystemExit(main())
