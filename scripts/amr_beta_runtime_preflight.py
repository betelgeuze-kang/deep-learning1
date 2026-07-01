#!/usr/bin/env python3
"""Preflight AMR beta inputs before requesting a real_benchmark runtime.

This is a read-only operator gate for blocker 9.4. It checks repository intake,
label templates, human decisions, maintainer feedback, and verified label-intake
directories before the long runtime-approved benchmark step.

It does not run audits, does not compile labels, does not run real_benchmark,
does not create benchmark evidence, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shlex
import sys
from pathlib import Path

import amr_beta_benchmark_input_prepare as benchmark_inputs
import amr_beta_human_input_status as human_status
import amr_beta_label_packet as label_packet
import amr_beta_repo_intake_validate as repo_intake

SCHEMA = "amr_beta_runtime_preflight.v1"
BLOCKED_FLAGS = {
    "design_partner_beta_candidate_ready": 0,
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def read_json_or_jsonl(path: Path, input_name: str) -> list[dict]:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} file")
    return human_status.read_json_or_jsonl(path, input_name)


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def repo_context(rows: list[dict[str, str]]) -> tuple[dict[str, dict[str, str]], dict[str, str]]:
    by_case: dict[str, dict[str, str]] = {}
    by_repo: dict[str, str] = {}
    for row in rows:
        case_id = str(row.get("case_id") or "").strip()
        raw_repo = str(row.get("repo_path") or "").strip()
        expected_head = str(row.get("expected_repo_git_head") or "").strip().lower()
        if not case_id or not raw_repo:
            continue
        repo_path = str(Path(raw_repo).expanduser().resolve())
        by_case[case_id] = {
            "repo_path": repo_path,
            "expected_repo_git_head": expected_head,
        }
        by_repo[repo_path] = case_id
    return by_case, by_repo


def load_label_intakes(
    raw_dirs: list[str],
    *,
    verify_existing: bool,
) -> tuple[list[dict], list[str], list[str], list[dict[str, str]], dict[str, int]]:
    rows: list[dict] = []
    errors: list[str] = []
    manifest_sha256s: list[str] = []
    manifest_fingerprints: list[dict[str, str]] = []
    verify_passed_dirs = 0
    verify_failed_dirs = 0
    for raw_dir in raw_dirs:
        path = Path(raw_dir).expanduser().resolve()
        if verify_existing:
            verify_errors = human_status.verify_label_intake_existing(path)
            if verify_errors:
                verify_failed_dirs += 1
                errors.extend(verify_errors)
            else:
                verify_passed_dirs += 1
        loaded_rows, intake_errors, _manifest = benchmark_inputs.load_label_intake_dir(
            path,
            allow_synthetic=False,
        )
        rows.extend(loaded_rows)
        errors.extend(intake_errors)
        manifest_sha256 = benchmark_inputs.sha256_file(path / "label_intake_manifest.json")
        manifest_sha256s.append(manifest_sha256)
        manifest_fingerprints.append(
            {
                "label_intake_dir": str(path),
                "label_intake_manifest_sha256": manifest_sha256,
            }
        )
    return rows, errors, manifest_sha256s, manifest_fingerprints, {
        "label_intake_verify_existing_required": int(verify_existing and bool(raw_dirs)),
        "label_intake_verify_existing_passed_dirs": verify_passed_dirs,
        "label_intake_verify_existing_failed_dirs": verify_failed_dirs,
    }


def load_templates(
    raw_dirs: list[str],
    *,
    verify_existing: bool,
) -> tuple[list[dict], list[str], int, dict[str, int], list[dict[str, str]]]:
    rows: list[dict] = []
    errors: list[str] = []
    fingerprints: list[dict[str, str]] = []
    synthetic_rows = 0
    verify_passed_dirs = 0
    verify_failed_dirs = 0
    for raw_dir in raw_dirs:
        path = Path(raw_dir).expanduser().resolve()
        if verify_existing:
            verify_errors = label_packet.verify_label_template_existing(path)
            if verify_errors:
                verify_failed_dirs += 1
                errors.extend(verify_errors)
            else:
                verify_passed_dirs += 1
        loaded_rows, template_errors, counts = label_packet.load_template_dir(path)
        template_json = path / "label_template.json"
        template_manifest = path / "label_template_manifest.json"
        fingerprints.append(
            {
                "template_dir": str(path),
                "label_template_json_sha256": sha256_file(template_json),
                "label_template_manifest_sha256": sha256_file(template_manifest)
                if template_manifest.is_file()
                else "",
            }
        )
        rows.extend(loaded_rows)
        errors.extend(template_errors)
        synthetic_rows += counts["synthetic_candidate_rows"]
    candidate_ids = [row["candidate_label_id"] for row in rows]
    duplicate_ids = sorted({value for value in candidate_ids if candidate_ids.count(value) > 1})
    if duplicate_ids:
        errors.append(f"duplicate template candidate_label_id values: {', '.join(duplicate_ids[:10])}")
    return rows, errors, synthetic_rows, {
        "label_template_verify_existing_required": int(verify_existing and bool(raw_dirs)),
        "label_template_verify_existing_passed_dirs": verify_passed_dirs,
        "label_template_verify_existing_failed_dirs": verify_failed_dirs,
    }, fingerprints


def validate_label_binding(rows: list[dict], repo_by_case: dict[str, dict[str, str]]) -> list[str]:
    errors: list[str] = []
    for index, row in enumerate(rows, start=1):
        case_id = str(row.get("case_id") or "").strip()
        repo_path = str(Path(str(row.get("repo_path") or "")).expanduser().resolve())
        expected_head = str(row.get("expected_repo_git_head") or "").strip().lower()
        context = repo_by_case.get(case_id)
        if not context:
            errors.append(f"label intake row {index}: case_id not present in repo intake: {case_id}")
            continue
        if repo_path != context["repo_path"]:
            errors.append(f"label intake row {index}: repo_path does not match repo intake for {case_id}")
        if expected_head != context["expected_repo_git_head"]:
            errors.append(f"label intake row {index}: expected_repo_git_head does not match repo intake for {case_id}")
    return errors


def duplicate_label_errors(rows: list[dict]) -> list[str]:
    errors: list[str] = []
    seen: set[tuple[str, str]] = set()
    for row in rows:
        key = (str(row.get("case_id") or ""), str(row.get("label_id") or ""))
        if key in seen:
            errors.append(f"duplicate label intake row: {key[0]}:{key[1]}")
        seen.add(key)
    return errors


def empty_label_intake_summary(raw_dirs: list[str], *, verify_existing: bool) -> dict[str, int]:
    return {
        "label_intake_dir_count": len(raw_dirs),
        "label_intake_verify_existing_required": int(verify_existing and bool(raw_dirs)),
        "label_intake_verify_existing_passed_dirs": 0,
        "label_intake_verify_existing_failed_dirs": 0,
        "label_intake_label_rows": 0,
        "label_intake_case_count": 0,
        "label_intake_countable_case_count": 0,
        "label_intake_synthetic_case_count": 0,
    }


def empty_decision_summary() -> dict[str, int]:
    return {
        "total_decision_rows": 0,
        "valid_human_label_rows": 0,
        "non_synthetic_valid_human_label_rows": 0,
        "synthetic_or_unverified_human_label_rows": 0,
    }


def empty_feedback_summary() -> dict[str, object]:
    return {
        "feedback_sha256": "",
        "feedback_bundle_sha256": "",
        "feedback_rows": 0,
        "feedback_digest_fingerprint_rows": 0,
        "total_feedback_rows": 0,
        "valid_feedback_rows": 0,
        "valid_feedback_text_input_rows": 0,
        "valid_feedback_hash_only_rows": 0,
        "valid_feedback_digest_rows": 0,
        "distinct_maintainer_id_count": 0,
        "feedback_countable_case_rows": 0,
        "distinct_countable_maintainer_id_count": 0,
        "feedback_counts_for_beta_precheck": 0,
        "raw_feedback_text_emitted": 0,
    }


def write_json(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like JSON output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_markdown(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like Markdown output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    lines = [
        "# AMR Beta Runtime Preflight",
        "",
        f"- ready_to_request_runtime_approval: {payload['ready_to_request_runtime_approval']}",
        f"- repo_intake_preflight_passed: {payload['repo_intake_preflight_passed']}",
        f"- template_preflight_passed: {payload['template_preflight_passed']}",
        f"- label_template_verify_existing_required: {payload['label_template_verify_existing_required']}",
        f"- label_template_verify_existing_passed_dirs: {payload['label_template_verify_existing_passed_dirs']}",
        f"- label_template_verify_existing_failed_dirs: {payload['label_template_verify_existing_failed_dirs']}",
        f"- label_intake_preflight_passed: {payload['label_intake_preflight_passed']}",
        f"- label_intake_verify_existing_required: {payload['label_intake_verify_existing_required']}",
        f"- label_intake_verify_existing_passed_dirs: {payload['label_intake_verify_existing_passed_dirs']}",
        f"- label_intake_verify_existing_failed_dirs: {payload['label_intake_verify_existing_failed_dirs']}",
        f"- human_input_preflight_passed: {payload['human_input_preflight_passed']}",
        f"- case_binding_preflight_passed: {payload['case_binding_preflight_passed']}",
        f"- input_path_preflight_passed: {payload['input_path_preflight_passed']}",
        f"- output_path_preflight_passed: {payload['output_path_preflight_passed']}",
        f"- valid_repo_rows: {payload['valid_repo_rows']}",
        f"- repo_snapshot_lock_sha256: {payload['repo_snapshot_lock_sha256']}",
        f"- preflight_input_bundle_sha256: {payload['preflight_input_bundle_sha256']}",
        f"- label_intake_case_count: {payload['label_intake_case_count']}",
        f"- label_template_bundle_sha256: {payload['label_template_bundle_sha256']}",
        f"- label_intake_bundle_sha256: {payload['label_intake_bundle_sha256']}",
        f"- human_label_rows: {payload['human_label_rows']}",
        f"- distinct_countable_maintainer_id_count: {payload['distinct_countable_maintainer_id_count']}",
        f"- feedback_bundle_sha256: {payload['feedback_bundle_sha256']}",
        f"- valid_feedback_text_input_rows: {payload['valid_feedback_text_input_rows']}",
        f"- valid_feedback_hash_only_rows: {payload['valid_feedback_hash_only_rows']}",
        f"- valid_feedback_digest_rows: {payload['valid_feedback_digest_rows']}",
        f"- feedback_counts_for_beta_precheck: {payload['feedback_counts_for_beta_precheck']}",
        f"- raw_feedback_text_emitted: {payload['raw_feedback_text_emitted']}",
        "- release/public/model readiness: 0",
        "- benchmark_runtime_approval_required: 1",
        "",
        "## Next Commands",
        "",
    ]
    for command in payload["next_commands"]:
        lines.append(f"- `{command}`")
    if payload["errors"]:
        lines.extend(["", "## Blockers", ""])
        lines.extend(f"- {error}" for error in payload["errors"])
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def command_line(parts: list[str]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-intake", required=True, help="Filled repo-intake Markdown or CSV.")
    parser.add_argument("--template-dir", action="append", required=True, help="Label template dir; repeatable.")
    parser.add_argument("--decisions", required=True, help="Human decision JSON/JSONL file.")
    parser.add_argument("--feedback", required=True, help="Maintainer feedback JSON/JSONL file.")
    parser.add_argument("--label-intake-dir", action="append", required=True, help="Verified label-intake dir; repeatable.")
    parser.add_argument("--combined-labels", default="results/combined_benchmark_labels.jsonl")
    parser.add_argument("--combined-summary", default="results/combined_benchmark_input_summary.json")
    parser.add_argument("--benchmark-out", default="results/audit_benchmark")
    parser.add_argument("--min-repos", type=int, default=repo_intake.MIN_REAL_REPOS_FOR_BETA)
    parser.add_argument("--min-labels", type=int, default=human_status.MIN_HUMAN_LABELS_FOR_BETA)
    parser.add_argument("--min-maintainers", type=int, default=human_status.MIN_MAINTAINER_FEEDBACK_FOR_BETA)
    parser.add_argument("--out-json", default="")
    parser.add_argument("--out-md", default="")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument(
        "--skip-verify-existing",
        action="store_true",
        help=(
            "Testing only: skip audit_my_repo_label_template.py and "
            "audit_my_repo_label_intake.py --verify-existing checks."
        ),
    )
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        repo_path = Path(args.repo_intake).expanduser().resolve()
        if is_forbidden_env_path(repo_path):
            raise ValueError("refusing .env-like repo intake path")
        decisions_path = Path(args.decisions).expanduser().resolve()
        feedback_path = Path(args.feedback).expanduser().resolve()
        repo_rows = repo_intake.read_rows(repo_path)
        repo_errors, repo_summary = repo_intake.validate_rows(repo_rows, min_repos=args.min_repos)
        repo_by_case, _repo_by_path = repo_context(repo_rows)
        target_repo_paths = repo_intake.target_repo_paths_from_statuses(repo_summary.get("row_statuses", []))
        input_paths = {
            "repo_intake": repo_path,
            "decisions": decisions_path,
            "feedback": feedback_path,
        }
        for index, raw_dir in enumerate(args.template_dir, start=1):
            input_paths[f"template_dir[{index}]"] = Path(raw_dir).expanduser().resolve()
        for index, raw_dir in enumerate(args.label_intake_dir, start=1):
            input_paths[f"label_intake_dir[{index}]"] = Path(raw_dir).expanduser().resolve()
        input_path_errors = benchmark_inputs.validate_input_paths(input_paths, target_repo_paths)

        if input_path_errors:
            template_rows = []
            template_errors = []
            synthetic_template_rows = 0
            template_verify_counts = {
                "label_template_verify_existing_required": int(
                    not args.skip_verify_existing and bool(args.template_dir)
                ),
                "label_template_verify_existing_passed_dirs": 0,
                "label_template_verify_existing_failed_dirs": 0,
            }
            template_fingerprints = []
            template_candidate_ids: set[str] = set()
            template_non_synthetic_candidate_ids: set[str] = set()
            template_case_ids: set[str] = set()
            label_rows = []
            label_errors = []
            manifest_sha256s = []
            label_intake_fingerprints = []
            label_case_ids = []
            label_repo_paths = []
            label_intake_case_ids: set[str] = set()
            countable_case_ids: set[str] = set()
            label_intake_summary = empty_label_intake_summary(
                args.label_intake_dir,
                verify_existing=not args.skip_verify_existing,
            )
            decision_errors = []
            decision_summary = empty_decision_summary()
            feedback_errors = []
            feedback_summary = empty_feedback_summary()
            known_case_ids = set(repo_by_case)
        else:
            template_rows, template_errors, synthetic_template_rows, template_verify_counts, template_fingerprints = load_templates(
                args.template_dir,
                verify_existing=not args.skip_verify_existing,
            )
            template_candidate_ids = {row["candidate_label_id"] for row in template_rows}
            template_non_synthetic_candidate_ids = {
                row["candidate_label_id"]
                for row in template_rows
                if not benchmark_inputs.truthy(row.get("synthetic", True))
            }
            template_case_ids = {row["case_id"] for row in template_rows}
            label_rows, label_errors, manifest_sha256s, label_intake_fingerprints, verify_counts = load_label_intakes(
                args.label_intake_dir,
                verify_existing=not args.skip_verify_existing,
            )
            label_errors.extend(duplicate_label_errors(label_rows))
            label_errors.extend(validate_label_binding(label_rows, repo_by_case))
            label_case_ids = sorted({str(row.get("case_id") or "") for row in label_rows})
            label_repo_paths = sorted({str(Path(str(row.get("repo_path") or "")).expanduser().resolve()) for row in label_rows})
            if len(label_case_ids) < args.min_repos:
                label_errors.append(f"label_intake_case_count {len(label_case_ids)} below required minimum {args.min_repos}")
            if len(label_rows) < args.min_labels:
                label_errors.append(f"human_label_rows {len(label_rows)} below required minimum {args.min_labels}")

            label_intake_case_ids, countable_case_ids, label_intake_summary = human_status.load_label_intake_context(
                args.label_intake_dir,
                verify_existing=False,
            )
            label_intake_summary.update(verify_counts)
            decisions = read_json_or_jsonl(decisions_path, "decisions")
            feedback = read_json_or_jsonl(feedback_path, "feedback")
            known_case_ids = set(repo_by_case) | template_case_ids | label_intake_case_ids
            decision_errors, decision_summary = human_status.validate_decisions(
                decisions,
                known_candidate_ids=template_candidate_ids,
                non_synthetic_candidate_ids=template_non_synthetic_candidate_ids,
                template_context_supplied=bool(args.template_dir),
                min_labels=args.min_labels,
            )
            feedback_errors, feedback_summary = benchmark_inputs.summarize_feedback_bundle(
                feedback_path,
                feedback,
                known_case_ids=known_case_ids,
                countable_case_ids=countable_case_ids,
                min_maintainers=args.min_maintainers,
            )
        human_errors = [*decision_errors, *feedback_errors]

        binding_errors: list[str] = []
        unknown_template_cases = sorted(template_case_ids - set(repo_by_case))
        if unknown_template_cases:
            binding_errors.append(
                "template case_id values missing from repo intake: " + ", ".join(unknown_template_cases[:20])
            )
        unknown_label_cases = sorted(set(label_case_ids) - set(repo_by_case))
        if unknown_label_cases:
            binding_errors.append(
                "label-intake case_id values missing from repo intake: " + ", ".join(unknown_label_cases[:20])
            )

        combined_labels = str(Path(args.combined_labels).expanduser().resolve())
        combined_summary = str(Path(args.combined_summary).expanduser().resolve())
        benchmark_out = str(Path(args.benchmark_out).expanduser().resolve())
        output_paths = {
            "combined_labels": Path(combined_labels),
            "combined_summary": Path(combined_summary),
            "benchmark_out": Path(benchmark_out),
        }
        if args.out_json:
            output_paths["out_json"] = Path(args.out_json).expanduser().resolve()
        if args.out_md:
            output_paths["out_md"] = Path(args.out_md).expanduser().resolve()
        output_errors = benchmark_inputs.validate_output_paths(output_paths, target_repo_paths)
        feedback_path_text = str(feedback_path)
        prepare_parts = ["python3", "scripts/amr_beta_benchmark_input_prepare.py"]
        for raw in args.label_intake_dir:
            prepare_parts.extend(["--label-intake-dir", str(Path(raw).expanduser().resolve())])
        prepare_parts.extend(
            [
                "--out-labels",
                combined_labels,
                "--summary",
                combined_summary,
                "--feedback",
                feedback_path_text,
                "--benchmark-out",
                benchmark_out,
            ]
        )
        benchmark_parts = [
            "python3",
            "scripts/audit_my_repo_benchmark.py",
            "--labels",
            combined_labels,
            "--feedback",
            feedback_path_text,
            "--namespace",
            "real_benchmark",
            "--confirm-real-benchmark-namespace",
            "--mode",
            "full",
            "--out",
            benchmark_out,
        ]
        next_commands = [] if input_path_errors or output_errors else [command_line(prepare_parts), command_line(benchmark_parts)]

        errors = [*repo_errors, *input_path_errors, *template_errors, *label_errors, *human_errors, *binding_errors, *output_errors]
        repo_pass = int(not repo_errors)
        template_pass = int(not template_errors)
        label_pass = int(not label_errors)
        human_pass = int(not human_errors)
        binding_pass = int(not binding_errors)
        input_path_pass = int(not input_path_errors)
        output_pass = int(not output_errors)
        ready = int(not errors)
        label_template_bundle_sha256 = sha256_json(template_fingerprints)
        label_intake_bundle_sha256 = sha256_json(label_intake_fingerprints)
        preflight_inputs = {
            "repo_intake_sha256": sha256_file(repo_path),
            "repo_snapshot_lock_sha256": repo_summary.get("repo_snapshot_lock_sha256", ""),
            "decisions_sha256": "" if input_path_errors else sha256_file(decisions_path),
            "feedback_sha256": "" if input_path_errors else sha256_file(feedback_path),
            "feedback_bundle_sha256": str(feedback_summary.get("feedback_bundle_sha256", "")),
            "label_template_bundle_sha256": label_template_bundle_sha256,
            "label_intake_bundle_sha256": label_intake_bundle_sha256,
        }
        payload = {
            "schema": SCHEMA,
            "repo_intake": str(repo_path),
            "repo_intake_sha256": preflight_inputs["repo_intake_sha256"],
            "repo_snapshot_lock_sha256": preflight_inputs["repo_snapshot_lock_sha256"],
            "decisions": str(decisions_path),
            "decisions_sha256": preflight_inputs["decisions_sha256"],
            "feedback": feedback_path_text,
            "feedback_sha256": preflight_inputs["feedback_sha256"],
            "preflight_input_bundle_sha256": sha256_json(preflight_inputs),
            "template_dir_count": len(args.template_dir),
            "label_template_fingerprints": template_fingerprints,
            "label_template_json_sha256s": [
                row["label_template_json_sha256"] for row in template_fingerprints
            ],
            "label_template_manifest_sha256s": [
                row["label_template_manifest_sha256"]
                for row in template_fingerprints
                if row["label_template_manifest_sha256"]
            ],
            "label_template_bundle_sha256": label_template_bundle_sha256,
            "label_intake_dir_count": len(args.label_intake_dir),
            "valid_repo_rows": int(repo_summary.get("valid_repo_rows", 0)),
            "min_real_repos_required": args.min_repos,
            "repo_intake_preflight_passed": repo_pass,
            "template_case_count": len(template_case_ids),
            "template_candidate_rows": len(template_rows),
            "template_candidate_id_count": len(template_candidate_ids),
            "synthetic_template_candidate_rows": synthetic_template_rows,
            **template_verify_counts,
            "template_preflight_passed": template_pass,
            "label_intake_case_count": len(label_case_ids),
            "label_intake_repo_count": len(label_repo_paths),
            "human_label_rows": len(label_rows),
            "synthetic_label_rows": sum(1 for row in label_rows if benchmark_inputs.truthy(row.get("synthetic", False))),
            "label_intake_fingerprints": label_intake_fingerprints,
            "label_intake_manifest_sha256s": manifest_sha256s,
            "label_intake_bundle_sha256": label_intake_bundle_sha256,
            "label_intake_preflight_passed": label_pass,
            **decision_summary,
            "min_human_label_rows_required": args.min_labels,
            **feedback_summary,
            **label_intake_summary,
            "min_maintainer_feedback_required": args.min_maintainers,
            "human_input_preflight_passed": human_pass,
            "case_binding_preflight_passed": binding_pass,
            "input_path_preflight_passed": input_path_pass,
            "output_path_preflight_passed": output_pass,
            "ready_to_request_runtime_approval": ready,
            "benchmark_runtime_approval_required": 1,
            "creates_benchmark_evidence": 0,
            "combined_labels": combined_labels,
            "combined_summary": combined_summary,
            "benchmark_out": benchmark_out,
            "next_commands": next_commands,
            **BLOCKED_FLAGS,
            "errors": errors,
        }
        if args.out_json and not output_errors:
            write_json(Path(args.out_json).expanduser().resolve(), payload, args.overwrite)
        if args.out_md and not output_errors:
            write_markdown(Path(args.out_md).expanduser().resolve(), payload, args.overwrite)
        if args.json:
            print(json.dumps(payload, indent=2, sort_keys=True))
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        if not args.json:
            print(
                "runtime_preflight: ok "
                f"valid_repo_rows={payload['valid_repo_rows']} "
                f"human_label_rows={payload['human_label_rows']} "
                f"distinct_countable_maintainer_id_count={payload['distinct_countable_maintainer_id_count']}"
            )
        return 0
    except Exception as exc:
        print(f"runtime_preflight: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
