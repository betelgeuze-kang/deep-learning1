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
import hashlib
import json
import re
import sys
from pathlib import Path

SHA256_RE = re.compile(r"^(sha256:)?[0-9a-f]{64}$")
TRUE_TOKENS = {"1", "true", "yes"}
FALSE_TOKENS = {"0", "false", "no", ""}
FALSE_EXTERNAL_TOKENS = {"0", "false", "no"}

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


def system_specs(contract: dict) -> dict[str, dict]:
    specs: dict[str, dict] = {}
    for system in contract.get("systems", []):
        specs[system["system_id"]] = {
            "min": float(system.get("parameter_count_b_min", 0)),
            "max": float(system.get("parameter_count_b_max", float("inf"))),
        }
    return specs


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def _query_sets_by_model(rows: list[dict]) -> dict[str, set[str]]:
    result: dict[str, set[str]] = {}
    for row in rows:
        model_id = (row.get("model_id") or "").strip()
        result.setdefault(model_id, set()).add((row.get("query_id") or "").strip())
    return result


def _read_query_ids(path: Path) -> set[str]:
    _, rows = read_rows(path)
    return {(row.get("query_id") or "").strip() for row in rows if (row.get("query_id") or "").strip()}


def _query_set_hash(query_ids: set[str]) -> str:
    joined = "\n".join(sorted(query_ids)).encode("utf-8")
    return "sha256:" + hashlib.sha256(joined).hexdigest()


def _verify_manifest(packet: Path, manifest_path: Path, errors: list[str]) -> None:
    header, rows = read_rows(manifest_path)
    if header != ["path", "sha256", "bytes"]:
        errors.append(f"{manifest_path}: header must be exactly path,sha256,bytes; got {header}")
        return
    listed: set[str] = set()
    for row in rows:
        rel = (row.get("path") or "").strip()
        listed.add(rel)
        target = packet / rel
        if not target.is_file():
            errors.append(f"{manifest_path}: listed file missing: {rel}")
            continue
        if (row.get("sha256") or "").strip().lower() != sha256_file(target):
            errors.append(f"{manifest_path}: sha256 mismatch for {rel}")
    for artifact_file in ARTIFACT_FILENAMES.values():
        if artifact_file not in listed:
            errors.append(f"{manifest_path}: missing manifest entry for {artifact_file}")


def check_artifact(
    artifact_id: str,
    path: Path,
    expected_columns: list[str],
    expected_rows: int,
    errors: list[str],
    specs: dict | None = None,
) -> list[dict]:
    if not path.is_file():
        errors.append(f"{path}: missing required packet file for {artifact_id}")
        return []
    header, rows = read_rows(path)
    if header != list(expected_columns):
        errors.append(f"{path}: header must be exactly (in order) {expected_columns}; got {header}")
        return rows
    if len(rows) != expected_rows:
        errors.append(f"{path}: expected {expected_rows} rows, got {len(rows)}")
    for index, row in enumerate(rows, start=1):
        prefix = f"{path}:row{index}"
        for field in expected_columns:
            value = (row.get(field) or "").strip()
            if field == EXTERNAL_API_FIELD:
                if value == "":
                    errors.append(f"{prefix}: {field} must be explicitly 0/false, not empty")
                elif value.lower() not in FALSE_EXTERNAL_TOKENS:
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
                    number = float(value)
                except ValueError:
                    errors.append(f"{prefix}: {field} must be numeric, got {value!r}")
                else:
                    if number < 0:
                        errors.append(f"{prefix}: {field} must be non-negative, got {value!r}")
                    if field == "parameter_count_b" and specs is not None:
                        sid = (row.get("system_id") or "").strip()
                        spec = specs.get(sid)
                        if spec and not (spec["min"] <= number <= spec["max"]):
                            errors.append(
                                f"{prefix}: parameter_count_b {number} outside "
                                f"[{spec['min']},{spec['max']}] for system {sid}"
                            )
    return rows


def cmd_preflight(args: argparse.Namespace) -> int:
    contract = load_contract(Path(args.contract))
    columns = artifact_columns(contract)
    systems = args.systems.split(",") if args.systems else system_ids(contract)
    specs = system_specs(contract)
    packet = Path(args.packet)
    rows_per_system = args.rows_per_system
    errors: list[str] = []

    mi_rows = check_artifact(
        "model-identity",
        packet / ARTIFACT_FILENAMES["model-identity"],
        columns["model-identity"],
        len(systems),
        errors,
        specs=specs,
    )
    seen_systems: set[str] = set()
    system_to_model: dict[str, str] = {}
    for row in mi_rows:
        sid = (row.get("system_id") or "").strip()
        if sid in seen_systems:
            errors.append(f"{packet}: duplicate system_id {sid!r} in model_identity")
        seen_systems.add(sid)
        system_to_model[sid] = (row.get("model_id") or "").strip()

    ac_rows = check_artifact(
        "answer-citation-raw-output",
        packet / ARTIFACT_FILENAMES["answer-citation-raw-output"],
        columns["answer-citation-raw-output"],
        len(systems) * rows_per_system,
        errors,
    )
    re_rows = check_artifact(
        "resource-evaluator-manifest",
        packet / ARTIFACT_FILENAMES["resource-evaluator-manifest"],
        columns["resource-evaluator-manifest"],
        len(systems) * rows_per_system,
        errors,
    )

    # answer uniqueness on (system_id, query_id) + model_id consistency.
    seen_ac: set[tuple[str, str]] = set()
    for row in ac_rows:
        sid = (row.get("system_id") or "").strip()
        qid = (row.get("query_id") or "").strip()
        key = (sid, qid)
        if key in seen_ac:
            errors.append(f"{packet}: duplicate (system_id, query_id)={key} in answer_citation")
        seen_ac.add(key)
        expected_model = system_to_model.get(sid)
        if expected_model and (row.get("model_id") or "").strip() != expected_model:
            errors.append(
                f"{packet}: answer_citation model_id for system {sid!r} does not match model_identity"
            )

    # resource uniqueness on (model_id, query_id).
    seen_re: set[tuple[str, str]] = set()
    for row in re_rows:
        key = ((row.get("model_id") or "").strip(), (row.get("query_id") or "").strip())
        if key in seen_re:
            errors.append(f"{packet}: duplicate (model_id, query_id)={key} in resource_evaluator")
        seen_re.add(key)

    # cross-file query consistency + same-query-set across systems.
    ac_qsets = _query_sets_by_model(ac_rows)
    re_qsets = _query_sets_by_model(re_rows)
    if set(ac_qsets) != set(re_qsets):
        errors.append(f"{packet}: model_id set differs between answer_citation and resource_evaluator")
    for model_id in ac_qsets:
        if model_id in re_qsets and ac_qsets[model_id] != re_qsets[model_id]:
            errors.append(f"{packet}: query_id set differs across files for model {model_id!r}")
    shared_sets = list(ac_qsets.values())
    shared_query_ids: set[str] | None = None
    if shared_sets:
        first = shared_sets[0]
        if any(qset != first for qset in shared_sets):
            errors.append(f"{packet}: systems do not share the same query set (same-query-set required)")
        else:
            shared_query_ids = first

    # v53 frozen query hash binding (optional).
    if args.v53_query_manifest:
        frozen = _read_query_ids(Path(args.v53_query_manifest))
        query_hash = _query_set_hash(frozen)
        if shared_query_ids is None:
            errors.append(f"{packet}: cannot bind to v53 frozen queries (packet query set is inconsistent)")
        elif shared_query_ids != frozen:
            errors.append(
                f"{packet}: packet query set does not match the v53 frozen query manifest "
                f"({Path(args.v53_query_manifest)})"
            )
        else:
            print(f"v53 frozen query binding ok: {len(frozen)} queries, query_set_hash={query_hash}")

    # packet sha256 manifest (verify if present or required).
    manifest_path = packet / "sha256_manifest.csv"
    if args.require_manifest and not manifest_path.is_file():
        errors.append(f"{manifest_path}: sha256 manifest required (--require-manifest) but missing")
    elif manifest_path.is_file():
        _verify_manifest(packet, manifest_path, errors)

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
        "D/E execution packet preflight v2 ok (exact header order, explicit external-API, "
        "parameter range, system/query uniqueness, cross-file consistency"
        + (", v53 binding" if args.v53_query_manifest else "")
        + (", sha256 manifest" if manifest_path.is_file() else "")
        + " checked). This does not admit evidence; run the canonical intake next."
    )
    return 0


def cmd_manifest(args: argparse.Namespace) -> int:
    packet = Path(args.packet)
    rows: list[dict] = []
    for artifact_file in ARTIFACT_FILENAMES.values():
        target = packet / artifact_file
        if not target.is_file():
            raise SystemExit(f"{target}: packet file missing; cannot build manifest")
        rows.append(
            {
                "path": artifact_file,
                "sha256": sha256_file(target),
                "bytes": str(target.stat().st_size),
            }
        )
    write_csv(packet / "sha256_manifest.csv", ["path", "sha256", "bytes"], rows)
    print(f"wrote {packet / 'sha256_manifest.csv'} ({len(rows)} entries)")
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
    p_preflight.add_argument(
        "--v53-query-manifest",
        dest="v53_query_manifest",
        default="",
        help="optional CSV of frozen v53 query_id rows to bind the packet query set to",
    )
    p_preflight.add_argument(
        "--require-manifest",
        dest="require_manifest",
        action="store_true",
        help="fail if sha256_manifest.csv is absent",
    )
    p_preflight.set_defaults(func=cmd_preflight)

    p_manifest = sub.add_parser("manifest", help="write sha256_manifest.csv for a filled packet")
    p_manifest.add_argument("--packet", required=True, help="filled packet directory")
    p_manifest.set_defaults(func=cmd_manifest)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
