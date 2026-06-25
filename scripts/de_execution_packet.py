#!/usr/bin/env python3
"""D/E open-weight baseline execution packet: template generator + return preflight.

This is a return-side staging helper for the 30B (D) and 70B (E) open-weight
LLM+RAG baselines. It does two things:

    template   emit blank executor CSVs whose columns exactly match the
               admission contract, so an executor knows precisely what to fill.
    preflight  validate a filled packet directory against those columns plus
               safety rules, as a convenience BEFORE the data is fed into the
               canonical intake.

Single source of truth: the required artifact columns are read at runtime from
``baselines/de_30b70b_real.json`` (the same columns the project verifier
enforces), so this tool cannot drift from the contract.

Boundary: this tool admits NOTHING. It does not write to the measured registry,
does not flip any readiness flag, and is not the canonical intake. Real D/E
admission still runs through ``experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh``
and the project's baseline-admission / v53u intake verifiers. Fixture/synthetic
rows are allowed only for schema testing and must never be returned as real
measured evidence.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

SHA256_RE = re.compile(r"^(sha256:)?[0-9a-f]{64}$")
TRUE_TOKENS = {"1", "true", "yes"}
FALSE_TOKENS = {"0", "false", "no", ""}

ARTIFACT_FILENAMES = {
    "model-identity": "model_identity.csv",
    "answer-citation-raw-output": "answer_citation_raw_output.csv",
    "resource-evaluator-manifest": "resource_evaluator_manifest.csv",
}
PER_QUERY_ARTIFACTS = {"answer-citation-raw-output", "resource-evaluator-manifest"}
SHA_SUFFIX = "_sha256"
NUMERIC_FIELDS = {
    "parameter_count_b",
    "context_budget",
    "retrieval_budget",
    "seed",
    "raw_prompt_context_bytes",
    "retrieved_span_rows",
    "latency_ns",
    "peak_memory_mb",
}
EXTERNAL_API_FIELD = "external_api_used"
NON_FIXTURE_FIELD = "non_fixture_declared"


def load_contract(contract_path: Path) -> dict:
    data = json.loads(contract_path.read_text(encoding="utf-8"))
    if data.get("schema_version") != "baseline_admission.v1":
        raise SystemExit(f"{contract_path}: unexpected schema_version")
    return data


def artifact_columns(contract: dict) -> dict[str, list[str]]:
    columns: dict[str, list[str]] = {}
    for artifact in contract.get("required_artifacts", []):
        columns[artifact["artifact_id"]] = list(artifact["required_columns"])
    for artifact_id in ARTIFACT_FILENAMES:
        if artifact_id not in columns:
            raise SystemExit(f"contract missing required artifact {artifact_id}")
    return columns


def system_ids(contract: dict) -> list[str]:
    return [system["system_id"] for system in contract.get("systems", [])]


def write_csv(path: Path, header: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def cmd_template(args: argparse.Namespace) -> int:
    contract = load_contract(Path(args.contract))
    columns = artifact_columns(contract)
    systems = args.systems.split(",") if args.systems else system_ids(contract)
    rows_per_system = args.rows_per_system
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    for artifact_id, filename in ARTIFACT_FILENAMES.items():
        header = columns[artifact_id]
        rows: list[dict] = []
        if artifact_id == "model-identity":
            for system_id in systems:
                row = {col: "" for col in header}
                row["system_id"] = system_id
                rows.append(row)
        else:
            for system_id in systems:
                for index in range(1, rows_per_system + 1):
                    row = {col: "" for col in header}
                    if "system_id" in row:
                        row["system_id"] = system_id
                    if "query_id" in row:
                        row["query_id"] = f"q{index:04d}"
                    rows.append(row)
        write_csv(out / filename, header, rows)

    # Field dictionary: one row per (system, artifact, field).
    dict_rows: list[dict] = []
    for system_id in systems:
        for artifact_id, header in columns.items():
            for field in header:
                dict_rows.append(
                    {
                        "system_id": system_id,
                        "artifact": artifact_id,
                        "field": field,
                        "required": "1",
                        "rule": field_rule(field),
                    }
                )
    write_csv(
        out / "de_required_field_rows.csv",
        ["system_id", "artifact", "field", "required", "rule"],
        dict_rows,
    )

    (out / "EXECUTION_PACKET_README.md").write_text(readme_text(systems, rows_per_system), encoding="utf-8")
    print(
        f"wrote D/E execution packet template to {out} "
        f"(systems={','.join(systems)}, rows_per_system={rows_per_system})"
    )
    return 0


def field_rule(field: str) -> str:
    if field.endswith(SHA_SUFFIX):
        return "sha256 hex (optionally sha256: prefixed); not empty, not placeholder"
    if field == EXTERNAL_API_FIELD:
        return "must be 0/false; no external API calls"
    if field == NON_FIXTURE_FIELD:
        return "must be true; real measured run, not a fixture"
    if field in NUMERIC_FIELDS:
        return "non-negative number from the real run"
    return "non-empty value from the real measured run"


def readme_text(systems: list[str], rows_per_system: int) -> str:
    return (
        "# D/E open-weight baseline execution packet\n\n"
        "Fill every column in every CSV from a REAL local run of the 30B (D) and "
        "70B (E) open-weight LLM+RAG baselines. No external API. No fixtures.\n\n"
        "## Recommended run order (canary first)\n\n"
        "1. D 30B 100-query canary\n"
        "2. D 30B 1000-query full\n"
        "3. E 70B 100-query canary\n"
        "4. E 70B 1000-query full\n"
        "5. Re-evaluate A/B/C/D/E/G/H with the same evaluator on the same query set\n\n"
        f"This template was generated for systems={','.join(systems)} with "
        f"rows_per_system={rows_per_system} (use 100 for canary, 1000 for full).\n\n"
        "## Files\n\n"
        "- `model_identity.csv` - one row per system (model repo/revision/quant/hash/runtime/hardware).\n"
        "- `answer_citation_raw_output.csv` - one row per (system, query) raw answer/citation + hashes.\n"
        "- `resource_evaluator_manifest.csv` - one row per (system, query) latency/memory/evaluator.\n"
        "- `de_required_field_rows.csv` - field dictionary (rule per field).\n\n"
        "## Validate before returning\n\n"
        "```bash\n"
        "python3 scripts/de_execution_packet.py preflight --packet <DIR> "
        "--rows-per-system <100|1000>\n"
        "```\n\n"
        "## Boundary\n\n"
        "Preflight is a return-side schema/safety check only. It admits nothing.\n"
        "Real admission runs through the project's v52d/v53u intake and the\n"
        "baseline-admission verifier. Fixture/synthetic rows are for schema tests\n"
        "only and must never be returned as measured evidence.\n"
    )


def read_rows(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        header = list(reader.fieldnames or [])
        return header, list(reader)


def check_artifact(
    artifact_id: str,
    path: Path,
    expected_columns: list[str],
    expected_rows: int,
    errors: list[str],
) -> None:
    if not path.is_file():
        errors.append(f"{path}: missing required packet file for {artifact_id}")
        return
    header, rows = read_rows(path)
    if set(header) != set(expected_columns):
        missing = set(expected_columns) - set(header)
        extra = set(header) - set(expected_columns)
        errors.append(f"{path}: column mismatch (missing={sorted(missing)}, extra={sorted(extra)})")
        return
    if len(rows) != expected_rows:
        errors.append(f"{path}: expected {expected_rows} rows, got {len(rows)}")
    for index, row in enumerate(rows, start=1):
        prefix = f"{path}:row{index}"
        for field in expected_columns:
            value = (row.get(field) or "").strip()
            if field == EXTERNAL_API_FIELD:
                if value.lower() not in FALSE_TOKENS:
                    errors.append(f"{prefix}: {field} must be 0/false, got {value!r}")
                continue
            if value == "":
                errors.append(f"{prefix}: required field {field} is empty")
                continue
            if field == NON_FIXTURE_FIELD and value.lower() not in TRUE_TOKENS:
                errors.append(f"{prefix}: {field} must be true (real measured run), got {value!r}")
            if field.endswith(SHA_SUFFIX) and not SHA256_RE.match(value.lower()):
                errors.append(f"{prefix}: {field} is not a sha256 hash: {value!r}")
            if field in NUMERIC_FIELDS:
                try:
                    if float(value) < 0:
                        errors.append(f"{prefix}: {field} must be non-negative, got {value!r}")
                except ValueError:
                    errors.append(f"{prefix}: {field} must be numeric, got {value!r}")


def cmd_preflight(args: argparse.Namespace) -> int:
    contract = load_contract(Path(args.contract))
    columns = artifact_columns(contract)
    systems = args.systems.split(",") if args.systems else system_ids(contract)
    packet = Path(args.packet)
    rows_per_system = args.rows_per_system
    errors: list[str] = []

    check_artifact(
        "model-identity",
        packet / ARTIFACT_FILENAMES["model-identity"],
        columns["model-identity"],
        len(systems),
        errors,
    )
    for artifact_id in PER_QUERY_ARTIFACTS:
        check_artifact(
            artifact_id,
            packet / ARTIFACT_FILENAMES[artifact_id],
            columns[artifact_id],
            len(systems) * rows_per_system,
            errors,
        )

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(
            f"D/E execution packet preflight BLOCKED: {len(errors)} issue(s). "
            "Packet is not return-ready.",
            file=sys.stderr,
        )
        return 1
    print(
        "D/E execution packet preflight ok (schema + safety checks passed). "
        "This does not admit evidence; run the canonical intake next."
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--contract",
        default="baselines/de_30b70b_real.json",
        help="path to the baseline admission contract (column source of truth)",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_template = sub.add_parser("template", help="emit blank executor CSV templates")
    p_template.add_argument("--out", required=True, help="output directory")
    p_template.add_argument("--systems", default="", help="comma-separated system ids (default: contract)")
    p_template.add_argument("--rows-per-system", type=int, default=100, help="100 canary / 1000 full")
    p_template.set_defaults(func=cmd_template)

    p_preflight = sub.add_parser("preflight", help="validate a filled packet directory")
    p_preflight.add_argument("--packet", required=True, help="filled packet directory")
    p_preflight.add_argument("--systems", default="", help="comma-separated system ids (default: contract)")
    p_preflight.add_argument("--rows-per-system", type=int, default=100, help="expected rows per system")
    p_preflight.set_defaults(func=cmd_preflight)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
