#!/usr/bin/env python3
"""Build a human repo-intake request packet from discovery candidates.

This is a read-only blocker 9.1 helper. It consumes the output of
amr_beta_repo_intake_discover.py and writes a human-review packet listing
candidate repos that still need owner/maintainer contact and explicit
real_benchmark namespace confirmation.

It does not write a filled repo-intake sheet, does not count any repo for beta,
does not run audits, and does not create benchmark evidence.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

import amr_beta_repo_intake_validate as repo_intake

SCHEMA = "amr_beta_repo_discovery_request.v1"
DISCOVERY_SCHEMA = "amr_beta_repo_intake_discover.v1"
BLOCKED_FLAGS = {
    "design_partner_beta_candidate_ready": 0,
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}
READ_ONLY_FLAGS = [
    "runs_audit",
    "runs_label_template_generation",
    "writes_reviewer_packets",
    "creates_benchmark_evidence",
    "repo_intake_rows_counted",
    "ready_for_repo_intake",
]
RESPONSE_TEMPLATE_COLUMNS = [
    "suggested_case_id",
    "include_for_real_benchmark_intake",
    "owner_or_maintainer_contact",
    "real_benchmark_namespace_confirmed",
    "human_real_repo_source_confirmed",
    "path_risk_flags",
    "repo_path",
    "audit_mode",
    "notes",
]


def is_forbidden_env_path(path: Path) -> bool:
    for part in path.parts:
        if part == ".env" or part.startswith(".env.") or part.endswith(".env") or ".env." in part:
            return True
    return False


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path) -> dict:
    raw_path = path.expanduser()
    resolved_path = raw_path.resolve()
    if is_forbidden_env_path(raw_path) or is_forbidden_env_path(resolved_path):
        raise ValueError("refusing .env-like discovery path")
    payload = json.loads(resolved_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("repo discovery must contain an object")
    return payload


def int_flag(payload: dict, key: str, default: int = 0) -> int:
    raw = payload.get(key, default)
    if isinstance(raw, bool):
        return int(raw)
    if isinstance(raw, int):
        return raw
    return default


def output_exists_errors(
    raw_paths: dict[str, Path],
    resolved_paths: dict[str, Path],
    overwrite: bool,
) -> list[str]:
    errors: list[str] = []
    for name, raw_path in raw_paths.items():
        if is_forbidden_env_path(raw_path):
            errors.append(f"{name} must not be .env-like")
        resolved = resolved_paths[name]
        if is_forbidden_env_path(resolved):
            errors.append(f"{name} must not be .env-like")
        if resolved.exists() and not overwrite:
            errors.append(f"{name} already exists; use --overwrite: {resolved}")
        tmp_path = resolved.with_name(resolved.name + ".tmp")
        if tmp_path.exists():
            errors.append(f"{name} temporary output already exists: {tmp_path}")
    return errors


def validate_discovery(payload: dict) -> list[str]:
    errors: list[str] = []
    if str(payload.get("schema") or "") != DISCOVERY_SCHEMA:
        errors.append("repo_discovery: unexpected schema")
    if payload.get("errors"):
        errors.append("repo_discovery: artifact contains errors")
    for key in READ_ONLY_FLAGS:
        if int_flag(payload, key) != 0:
            errors.append(f"repo_discovery: must keep {key}=0")
    for key, expected in BLOCKED_FLAGS.items():
        if int_flag(payload, key) != expected:
            errors.append(f"repo_discovery: must keep {key}=0")
    if int_flag(payload, "candidate_rows_cannot_count_without_human_contact") != 1:
        errors.append("repo_discovery: candidate_rows_cannot_count_without_human_contact must be 1")

    candidates = payload.get("candidates")
    if not isinstance(candidates, list):
        errors.append("repo_discovery: candidates must be a list")
        return errors
    if int_flag(payload, "candidate_repo_count", len(candidates)) != len(candidates):
        errors.append("repo_discovery: candidate_repo_count must match candidates length")
    for key in [
        "candidate_repos_with_path_risk",
        "candidate_repos_with_clean_head_and_path_risk",
        "candidate_repos_with_clean_head_and_no_path_risk",
        "clean_risk_free_candidate_shortfall_to_minimum",
    ]:
        if key not in payload:
            errors.append(f"repo_discovery: {key} is required")
    ready_count = 0
    path_risk_count = 0
    ready_with_path_risk = 0
    ready_without_path_risk = 0
    for index, row in enumerate(candidates, start=1):
        prefix = f"repo_discovery: candidates row {index}"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if not str(row.get("repo_path") or "").strip():
            errors.append(f"{prefix}: repo_path must be present")
        if not str(row.get("suggested_case_id") or "").strip():
            errors.append(f"{prefix}: suggested_case_id must be present")
        if int_flag(row, "owner_or_maintainer_contact_present") != 0:
            errors.append(f"{prefix}: owner_or_maintainer_contact_present must be 0")
        if int_flag(row, "owner_or_maintainer_contact_required") != 1:
            errors.append(f"{prefix}: owner_or_maintainer_contact_required must be 1")
        if int_flag(row, "real_benchmark_namespace_confirmation_required") != 1:
            errors.append(f"{prefix}: real_benchmark_namespace_confirmation_required must be 1")
        if "path_risk_flags" not in row:
            errors.append(f"{prefix}: path_risk_flags is required")
        if "path_risk_flag_count" not in row:
            errors.append(f"{prefix}: path_risk_flag_count is required")
        if "human_real_repo_source_confirmation_required" not in row:
            errors.append(f"{prefix}: human_real_repo_source_confirmation_required is required")
        risk_flags = row.get("path_risk_flags", [])
        if not isinstance(risk_flags, list) or not all(isinstance(flag, str) for flag in risk_flags):
            errors.append(f"{prefix}: path_risk_flags must be a string list")
            risk_flags = []
        elif int_flag(row, "path_risk_flag_count") != len(risk_flags):
            errors.append(f"{prefix}: path_risk_flag_count must match path_risk_flags length")
        has_path_risk = bool(risk_flags)
        path_risk_count += int(has_path_risk)
        if int_flag(row, "human_real_repo_source_confirmation_required") != int(has_path_risk):
            errors.append(
                f"{prefix}: human_real_repo_source_confirmation_required must match path_risk_flags"
            )
        if int_flag(row, "counts_for_repo_intake") != 0:
            errors.append(f"{prefix}: counts_for_repo_intake must be 0")
        if str(row.get("suggested_namespace") or "") != "real_benchmark":
            errors.append(f"{prefix}: suggested_namespace must be real_benchmark")
        if int_flag(row, "ready_for_intake_after_human_contact") == 1:
            ready_count += 1
            if has_path_risk:
                ready_with_path_risk += 1
            else:
                ready_without_path_risk += 1
    if int_flag(payload, "candidate_repos_with_clean_head", ready_count) != ready_count:
        errors.append("repo_discovery: candidate_repos_with_clean_head must match ready candidates")
    if int_flag(payload, "candidate_repos_with_path_risk", path_risk_count) != path_risk_count:
        errors.append("repo_discovery: candidate_repos_with_path_risk must match candidates")
    if (
        int_flag(payload, "candidate_repos_with_clean_head_and_path_risk", ready_with_path_risk)
        != ready_with_path_risk
    ):
        errors.append("repo_discovery: candidate_repos_with_clean_head_and_path_risk must match ready candidates")
    if (
        int_flag(payload, "candidate_repos_with_clean_head_and_no_path_risk", ready_without_path_risk)
        != ready_without_path_risk
    ):
        errors.append("repo_discovery: candidate_repos_with_clean_head_and_no_path_risk must match ready candidates")
    expected_shortfall = max(
        0,
        int_flag(payload, "min_real_repos_required", repo_intake.MIN_REAL_REPOS_FOR_BETA)
        - ready_without_path_risk,
    )
    if int_flag(payload, "clean_risk_free_candidate_shortfall_to_minimum", expected_shortfall) != expected_shortfall:
        errors.append("repo_discovery: clean_risk_free_candidate_shortfall_to_minimum must match ready risk-free candidates")
    return errors


def candidate_repo_paths(payload: dict) -> list[str]:
    rows = payload.get("candidates", [])
    if not isinstance(rows, list):
        return []
    return [str(row.get("repo_path") or "") for row in rows if isinstance(row, dict)]


def build_request_rows(candidates: list[dict]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for row in candidates:
        ready = int_flag(row, "ready_for_intake_after_human_contact")
        request = {
            "schema": SCHEMA,
            "candidate_index": row.get("candidate_index", 0),
            "suggested_case_id": row.get("suggested_case_id", ""),
            "repo_path": row.get("repo_path", ""),
            "actual_repo_git_head": row.get("actual_repo_git_head", ""),
            "clean_worktree_actual": row.get("clean_worktree_actual"),
            "repo_git_worktree_confirmed": int_flag(row, "repo_git_worktree_confirmed"),
            "repo_head_readable": int_flag(row, "repo_head_readable"),
            "repo_status_readable": int_flag(row, "repo_status_readable"),
            "suggested_audit_mode": row.get("suggested_audit_mode", "quick"),
            "suggested_namespace": "real_benchmark",
            "path_risk_flags": row.get("path_risk_flags", []),
            "path_risk_flag_count": int_flag(row, "path_risk_flag_count"),
            "human_real_repo_source_confirmation_required": int_flag(
                row, "human_real_repo_source_confirmation_required"
            ),
            "include_for_real_benchmark_intake_required": 1,
            "owner_or_maintainer_contact_required": 1,
            "real_benchmark_namespace_confirmation_required": 1,
            "recommended_for_contact_request": ready,
            "counts_for_repo_intake": 0,
            "next_action": (
                "human_confirm_contact_and_namespace"
                if ready
                else "clean_or_fix_repo_before_intake"
            ),
            "blockers_before_counting": row.get("blockers_before_counting", []),
            **BLOCKED_FLAGS,
        }
        rows.append(request)
    return rows


def build_payload(
    discovery_path: Path,
    discovery: dict,
    errors: list[str],
    *,
    include_discovery_hash: bool = True,
    response_template_csv: Path | None = None,
    response_template_recommended_only: bool = False,
) -> dict[str, object]:
    candidates = discovery.get("candidates", [])
    if not isinstance(candidates, list):
        candidates = []
    request_rows = build_request_rows([row for row in candidates if isinstance(row, dict)])
    min_repos = int_flag(discovery, "min_real_repos_required", repo_intake.MIN_REAL_REPOS_FOR_BETA)
    clean_count = int_flag(discovery, "candidate_repos_with_clean_head")
    path_risk_count = sum(int(bool(row.get("path_risk_flags"))) for row in request_rows)
    response_template_rows = [
        row
        for row in request_rows
        if not response_template_recommended_only or int(row["recommended_for_contact_request"]) == 1
    ]
    recommended_rows_with_path_risk = sum(
        int(row["recommended_for_contact_request"] and bool(row.get("path_risk_flags")))
        for row in request_rows
    )
    recommended_rows_without_path_risk = sum(
        int(row["recommended_for_contact_request"] and not bool(row.get("path_risk_flags")))
        for row in request_rows
    )
    clean_risk_free_count = recommended_rows_without_path_risk
    clean_path_risk_count = recommended_rows_with_path_risk
    return {
        "schema": SCHEMA,
        "repo_discovery": str(discovery_path),
        "repo_discovery_sha256": (
            sha256_file(discovery_path) if include_discovery_hash and discovery_path.exists() else ""
        ),
        "candidate_repo_count": int_flag(discovery, "candidate_repo_count", len(request_rows)),
        "candidate_repos_with_clean_head": clean_count,
        "candidate_repos_with_path_risk": path_risk_count,
        "candidate_repos_with_clean_head_and_path_risk": clean_path_risk_count,
        "candidate_repos_with_clean_head_and_no_path_risk": clean_risk_free_count,
        "request_row_count": len(request_rows),
        "response_template_csv": str(response_template_csv) if response_template_csv else "",
        "response_template_recommended_only": int(response_template_recommended_only),
        "response_template_row_count": len(response_template_rows) if response_template_csv else 0,
        "writes_response_template_csv": int(bool(response_template_csv) and not errors),
        "recommended_contact_request_rows": sum(
            int(row["recommended_for_contact_request"]) for row in request_rows
        ),
        "recommended_contact_request_rows_with_path_risk": recommended_rows_with_path_risk,
        "recommended_contact_request_rows_without_path_risk": recommended_rows_without_path_risk,
        "min_real_repos_required": min_repos,
        "clean_candidate_shortfall_to_minimum": max(0, min_repos - clean_count),
        "clean_risk_free_candidate_shortfall_to_minimum": max(0, min_repos - clean_risk_free_count),
        "human_fields_required": [
            "include_for_real_benchmark_intake",
            "owner_or_maintainer_contact",
            "real_benchmark_namespace_confirmed",
            "human_real_repo_source_confirmed",
        ],
        "repo_intake_rows_counted": 0,
        "ready_for_repo_intake": 0,
        "writes_repo_intake_sheet": 0,
        "runs_audit": 0,
        "runs_label_template_generation": 0,
        "writes_reviewer_packets": 0,
        "creates_benchmark_evidence": 0,
        "request_rows": request_rows,
        **BLOCKED_FLAGS,
        "errors": errors,
    }


def markdown_cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def write_json(path: Path, payload: dict[str, object], overwrite: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    tmp_path = path.with_name(path.name + ".tmp")
    tmp_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp_path.replace(path)


def write_markdown(path: Path, payload: dict[str, object], overwrite: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    lines = [
        "# AMR Beta Repo Discovery Request",
        "",
        f"- repo_intake_rows_counted: {payload['repo_intake_rows_counted']}",
        f"- ready_for_repo_intake: {payload['ready_for_repo_intake']}",
        f"- candidate_repo_count: {payload['candidate_repo_count']}",
        f"- candidate_repos_with_clean_head: {payload['candidate_repos_with_clean_head']}",
        f"- candidate_repos_with_clean_head_and_no_path_risk: {payload['candidate_repos_with_clean_head_and_no_path_risk']}",
        f"- candidate_repos_with_clean_head_and_path_risk: {payload['candidate_repos_with_clean_head_and_path_risk']}",
        f"- candidate_repos_with_path_risk: {payload['candidate_repos_with_path_risk']}",
        f"- clean_candidate_shortfall_to_minimum: {payload['clean_candidate_shortfall_to_minimum']}",
        f"- clean_risk_free_candidate_shortfall_to_minimum: {payload['clean_risk_free_candidate_shortfall_to_minimum']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        "",
        "## Human Review Fields",
        "",
        "- include_for_real_benchmark_intake",
        "- owner_or_maintainer_contact",
        "- real_benchmark_namespace_confirmed",
        "- human_real_repo_source_confirmed",
        "",
        "## Candidate Rows",
        "",
        "| suggested_case_id | recommended | include_for_real_benchmark_intake | contact | namespace_confirmed | source_confirmed | clean | head | status | risk_flags | repo_path | blockers |",
        "|---|---:|---|---|---|---|---:|---:|---:|---|---|---|",
    ]
    for row in payload["request_rows"]:
        blockers = ",".join(str(item) for item in row.get("blockers_before_counting", []))
        lines.append(
            "| {case_id} | {recommended} |  |  |  |  | {clean} | {head} | {status} | {risk_flags} | {repo} | {blockers} |".format(
                case_id=markdown_cell(row.get("suggested_case_id", "")),
                recommended=row.get("recommended_for_contact_request", 0),
                clean=markdown_cell(row.get("clean_worktree_actual")),
                head=row.get("repo_head_readable", 0),
                status=row.get("repo_status_readable", 0),
                risk_flags=markdown_cell(",".join(str(flag) for flag in row.get("path_risk_flags", []))),
                repo=markdown_cell(row.get("repo_path", "")),
                blockers=markdown_cell(blockers),
            )
        )
    lines.extend(
        [
            "",
            "## Collector Template",
            "",
            "```bash",
            "python3 scripts/amr_beta_repo_intake_collect.py \\",
            "  --repo <selected-repo-path> --contact <human-contact> --case-id <case-id> \\",
            "  --confirm-real-benchmark-namespace \\",
            "  --out results/amr_beta_repo_intake.md",
            "```",
        ]
    )
    tmp_path = path.with_name(path.name + ".tmp")
    tmp_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    tmp_path.replace(path)


def write_response_csv(
    path: Path,
    payload: dict[str, object],
    overwrite: bool,
    *,
    recommended_only: bool = False,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    tmp_path = path.with_name(path.name + ".tmp")
    with tmp_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=RESPONSE_TEMPLATE_COLUMNS)
        writer.writeheader()
        for row in payload["request_rows"]:
            if recommended_only and int(row.get("recommended_for_contact_request", 0)) != 1:
                continue
            writer.writerow(
                {
                    "suggested_case_id": str(row.get("suggested_case_id", "")),
                    "include_for_real_benchmark_intake": "",
                    "owner_or_maintainer_contact": "",
                    "real_benchmark_namespace_confirmed": "",
                    "human_real_repo_source_confirmed": "",
                    "path_risk_flags": ",".join(str(flag) for flag in row.get("path_risk_flags", [])),
                    "repo_path": str(row.get("repo_path", "")),
                    "audit_mode": str(row.get("suggested_audit_mode", "quick")),
                    "notes": (
                        "recommended_for_contact_request=1"
                        if int(row.get("recommended_for_contact_request", 0)) == 1
                        else "clean_or_fix_repo_before_intake"
                    ),
                }
            )
    tmp_path.replace(path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-discovery", required=True, help="JSON from amr_beta_repo_intake_discover.py.")
    parser.add_argument("--out-json", required=True)
    parser.add_argument("--out-md", default="")
    parser.add_argument("--out-response-csv", default="", help="Optional human-fillable response CSV template.")
    parser.add_argument(
        "--response-template-recommended-only",
        action="store_true",
        help="Write only clean/head recommended candidates to the optional response CSV template.",
    )
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    raw_discovery_path = Path(args.repo_discovery).expanduser()
    discovery_path = raw_discovery_path.resolve()
    discovery_path_allowed = not is_forbidden_env_path(raw_discovery_path) and not is_forbidden_env_path(
        discovery_path
    )
    raw_out_paths = {"out_json": Path(args.out_json).expanduser()}
    errors: list[str] = []
    if args.out_md:
        raw_out_paths["out_md"] = Path(args.out_md).expanduser()
    raw_response_template_path = Path(args.out_response_csv).expanduser() if args.out_response_csv else None
    response_template_path = raw_response_template_path.resolve() if raw_response_template_path else None
    if raw_response_template_path:
        raw_out_paths["out_response_csv"] = raw_response_template_path
    if args.response_template_recommended_only and not response_template_path:
        errors.append("--response-template-recommended-only requires --out-response-csv")

    discovery: dict[str, object] = {}
    try:
        discovery = read_json(raw_discovery_path)
    except Exception as exc:
        errors.append(str(exc))
    if discovery:
        errors.extend(validate_discovery(discovery))
    out_paths = {name: path.resolve() for name, path in raw_out_paths.items()}
    if discovery:
        errors.extend(repo_intake.validate_output_paths(out_paths, candidate_repo_paths(discovery)))
    errors.extend(output_exists_errors(raw_out_paths, out_paths, args.overwrite))

    payload = build_payload(
        discovery_path,
        discovery,
        errors,
        include_discovery_hash=discovery_path_allowed,
        response_template_csv=response_template_path,
        response_template_recommended_only=args.response_template_recommended_only,
    )
    if not errors:
        try:
            if response_template_path:
                write_response_csv(
                    response_template_path,
                    payload,
                    args.overwrite,
                    recommended_only=args.response_template_recommended_only,
                )
            write_json(out_paths["out_json"], payload, args.overwrite)
            if args.out_md:
                write_markdown(out_paths["out_md"], payload, args.overwrite)
        except Exception as exc:
            errors.append(str(exc))
            payload["errors"] = errors
            payload["writes_response_template_csv"] = 0
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    if not args.json:
        print(
            "repo_discovery_request: ok "
            f"request_row_count={payload['request_row_count']} "
            f"repo_intake_rows_counted={payload['repo_intake_rows_counted']} "
            f"out_json={out_paths['out_json']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
