#!/usr/bin/env python3
"""Collect and validate v1.0 human review + independent reproduction returns.

This is an intake surface, not a readiness promotion tool. It accepts a local
operator-supplied directory with:

  human_review_rows.csv
  adjudication_rows.csv
  independent_reproduction_rows.csv

It copies the supplied rows into a hash-bound run directory, validates that the
rows are not templates/placeholders, and records whether the actual collection
packet is complete. `human_review_ready`, `independent_reproduction_ready`, and
`release_ready` intentionally remain 0; final promotion still belongs to the
canonical v58/operator/v60 release gates.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "results" / "release_review_collection" / "collection_001"
DEFAULT_SUMMARY = ROOT / "results" / "release_review_collection_summary.csv"
DEFAULT_DECISION = ROOT / "results" / "release_review_collection_decision.csv"

TRUE = {"1", "true", "yes"}
FALSE = {"0", "false", "no", ""}
ALLOWED_DECISIONS = {"accept", "reject", "revise"}
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
PLACEHOLDERS = {"", "placeholder", "todo", "replace-me", "replace-with-value", "example", "template"}

HUMAN_REVIEW_COLUMNS = [
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
ADJUDICATION_COLUMNS = [
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
INDEPENDENT_REPRODUCTION_COLUMNS = [
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


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def is_true(value: str) -> bool:
    return str(value).strip().lower() in TRUE


def is_false(value: str) -> bool:
    return str(value).strip().lower() in FALSE


def good_text(value: str) -> bool:
    text = str(value).strip()
    return text.lower() not in PLACEHOLDERS and not text.lower().startswith("replace-with")


def valid_sha(value: str) -> bool:
    return bool(SHA_RE.fullmatch(str(value).strip()))


def row_mode_ok(row: dict[str, str], *, allow_test_fixture: bool) -> tuple[bool, str]:
    if is_true(row.get("synthetic", "")):
        return False, "synthetic-row"
    if is_true(row.get("template_only", "")):
        return False, "template-row"
    if is_true(row.get("test_fixture", "")):
        if allow_test_fixture:
            return True, "test-fixture"
        return False, "test-fixture-row"
    return True, "actual"


def validate_human_reviews(rows: list[dict[str, str]], *, allow_test_fixture: bool) -> tuple[bool, int, int, list[str], str]:
    errors: list[str] = []
    modes: set[str] = set()
    by_response: dict[str, list[dict[str, str]]] = {}
    for index, row in enumerate(rows, start=1):
        ok, mode = row_mode_ok(row, allow_test_fixture=allow_test_fixture)
        modes.add(mode)
        if not ok:
            errors.append(f"human row {index}: {mode}")
        if not good_text(row.get("blind_response_id", "")):
            errors.append(f"human row {index}: missing blind_response_id")
        if not good_text(row.get("reviewer_id", "")):
            errors.append(f"human row {index}: missing reviewer_id")
        if not good_text(row.get("reviewer_pool_id", "")):
            errors.append(f"human row {index}: missing reviewer_pool_id")
        if not is_true(row.get("reviewer_independent", "")):
            errors.append(f"human row {index}: reviewer_independent must be true")
        if not is_true(row.get("reviewer_blinded", "")):
            errors.append(f"human row {index}: reviewer_blinded must be true")
        if not is_true(row.get("conflict_disclosed", "")):
            errors.append(f"human row {index}: conflict_disclosed must be true")
        if row.get("review_decision", "") not in ALLOWED_DECISIONS:
            errors.append(f"human row {index}: invalid review_decision")
        if not valid_sha(row.get("review_sha256", "")):
            errors.append(f"human row {index}: invalid review_sha256")
        by_response.setdefault(row.get("blind_response_id", ""), []).append(row)

    disagreements = 0
    for response_id, response_rows in by_response.items():
        reviewers = {row["reviewer_id"] for row in response_rows}
        pools = {row["reviewer_pool_id"] for row in response_rows}
        if len(response_rows) != 2:
            errors.append(f"response {response_id}: expected exactly 2 human reviews, got {len(response_rows)}")
        if len(reviewers) != len(response_rows):
            errors.append(f"response {response_id}: duplicate reviewer")
        if len(pools) < min(2, len(response_rows)):
            errors.append(f"response {response_id}: reviewers must come from distinct pools")
        if len({row["review_decision"] for row in response_rows}) > 1:
            disagreements += 1
    mode = "test-fixture" if modes == {"test-fixture"} else "actual"
    return not errors and bool(rows), len(by_response), disagreements, errors, mode


def validate_adjudications(
    rows: list[dict[str, str]],
    human_rows: list[dict[str, str]],
    disagreements: int,
    *,
    allow_test_fixture: bool,
) -> tuple[bool, list[str]]:
    errors: list[str] = []
    by_response: dict[str, list[dict[str, str]]] = {}
    for row in human_rows:
        by_response.setdefault(row.get("blind_response_id", ""), []).append(row)
    disagreement_ids = {
        response_id
        for response_id, response_rows in by_response.items()
        if len(response_rows) == 2 and len({row.get("review_decision", "") for row in response_rows}) > 1
    }
    adjudicated_ids = {row.get("blind_response_id", "") for row in rows if is_true(row.get("needs_adjudication", ""))}
    if disagreement_ids - adjudicated_ids:
        errors.append(f"missing adjudication for responses: {', '.join(sorted(disagreement_ids - adjudicated_ids))}")
    for index, row in enumerate(rows, start=1):
        ok, mode = row_mode_ok(row, allow_test_fixture=allow_test_fixture)
        if not ok:
            errors.append(f"adjudication row {index}: {mode}")
        if row.get("blind_response_id", "") not in by_response:
            errors.append(f"adjudication row {index}: unknown blind_response_id")
        if row.get("adjudicated_value", "") not in ALLOWED_DECISIONS:
            errors.append(f"adjudication row {index}: invalid adjudicated_value")
        if not is_true(row.get("adjudicator_independent", "")):
            errors.append(f"adjudication row {index}: adjudicator_independent must be true")
        if not good_text(row.get("adjudicator_id", "")):
            errors.append(f"adjudication row {index}: missing adjudicator_id")
        reviewers = by_response.get(row.get("blind_response_id", ""), [])
        reviewer_ids = {r.get("reviewer_id", "") for r in reviewers}
        if row.get("adjudicator_id", "") in reviewer_ids:
            errors.append(f"adjudication row {index}: adjudicator must differ from reviewers")
        if not valid_sha(row.get("adjudication_sha256", "")):
            errors.append(f"adjudication row {index}: invalid adjudication_sha256")
    # If there were no disagreements, zero adjudication rows is complete.
    return not errors and (disagreements == 0 or bool(rows)), errors


def validate_reproductions(rows: list[dict[str, str]], *, allow_test_fixture: bool) -> tuple[bool, list[str], str]:
    errors: list[str] = []
    modes: set[str] = set()
    for index, row in enumerate(rows, start=1):
        ok, mode = row_mode_ok(row, allow_test_fixture=allow_test_fixture)
        modes.add(mode)
        if not ok:
            errors.append(f"reproduction row {index}: {mode}")
        for field in ["reproduction_id", "reproducer_id", "command", "started_at_utc", "finished_at_utc"]:
            if not good_text(row.get(field, "")):
                errors.append(f"reproduction row {index}: missing {field}")
        if not is_true(row.get("reproducer_independent", "")):
            errors.append(f"reproduction row {index}: reproducer_independent must be true")
        if not is_true(row.get("conflict_disclosed", "")):
            errors.append(f"reproduction row {index}: conflict_disclosed must be true")
        if str(row.get("exit_code", "")).strip() != "0":
            errors.append(f"reproduction row {index}: exit_code must be 0")
        for field in ["output_manifest_sha256", "metric_rows_sha256", "environment_sha256"]:
            if not valid_sha(row.get(field, "")):
                errors.append(f"reproduction row {index}: invalid {field}")
    mode = "test-fixture" if modes == {"test-fixture"} else "actual"
    return not errors and bool(rows), errors, mode


def cmd_template(args: argparse.Namespace) -> int:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    write_csv(out / "human_review_rows.csv", HUMAN_REVIEW_COLUMNS, [])
    write_csv(out / "adjudication_rows.csv", ADJUDICATION_COLUMNS, [])
    write_csv(out / "independent_reproduction_rows.csv", INDEPENDENT_REPRODUCTION_COLUMNS, [])
    (out / "README.md").write_text(
        "# v1.0 Human/Independent Return Inbox\n\n"
        "Fill these CSVs with actual human review, adjudication, and independent reproduction rows.\n"
        "Do not use examples, templates, synthetic rows, or test fixtures for release evidence.\n",
        encoding="utf-8",
    )
    print(f"wrote release review collection template to {out}")
    return 0


def cmd_collect(args: argparse.Namespace) -> int:
    input_dir = Path(args.input_dir) if args.input_dir else None
    out = Path(args.out)
    summary_csv = Path(args.summary)
    decision_csv = Path(args.decision)
    out.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    validation_errors: list[str] = []
    human_rows: list[dict[str, str]] = []
    adjudication_rows: list[dict[str, str]] = []
    reproduction_rows: list[dict[str, str]] = []

    def load_required(name: str, columns: list[str]) -> list[dict[str, str]]:
        if input_dir is None or not input_dir.is_dir():
            validation_errors.append("input-dir-missing")
            return []
        path = input_dir / name
        if not path.is_file() or path.stat().st_size == 0:
            validation_errors.append(f"{name}-missing")
            return []
        header, rows = read_csv(path)
        if header != columns:
            validation_errors.append(f"{name}-bad-header")
            return rows
        dst = out / "supplied" / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dst)
        copied.append(f"supplied/{name}")
        return rows

    if input_dir and "examples" in input_dir.parts and not args.allow_test_fixture:
        validation_errors.append("examples-dir-not-actual-evidence")

    human_rows = load_required("human_review_rows.csv", HUMAN_REVIEW_COLUMNS)
    adjudication_rows = load_required("adjudication_rows.csv", ADJUDICATION_COLUMNS)
    reproduction_rows = load_required("independent_reproduction_rows.csv", INDEPENDENT_REPRODUCTION_COLUMNS)

    human_ok, reviewed_responses, disagreements, human_errors, human_mode = validate_human_reviews(
        human_rows, allow_test_fixture=args.allow_test_fixture
    )
    adjudication_ok, adjudication_errors = validate_adjudications(
        adjudication_rows, human_rows, disagreements, allow_test_fixture=args.allow_test_fixture
    )
    reproduction_ok, reproduction_errors, reproduction_mode = validate_reproductions(
        reproduction_rows, allow_test_fixture=args.allow_test_fixture
    )
    validation_errors.extend(human_errors)
    validation_errors.extend(adjudication_errors)
    validation_errors.extend(reproduction_errors)

    collection_mode = "none"
    if args.allow_test_fixture and (human_mode == "test-fixture" or reproduction_mode == "test-fixture"):
        collection_mode = "test-fixture"
    elif input_dir and input_dir.is_dir():
        collection_mode = "actual"

    actual_collection_ready = int(
        collection_mode == "actual" and human_ok and adjudication_ok and reproduction_ok and not validation_errors
    )
    test_fixture_collection_ready = int(
        collection_mode == "test-fixture" and human_ok and adjudication_ok and reproduction_ok and not validation_errors
    )
    blocking_reason = ""
    if not actual_collection_ready:
        if validation_errors:
            blocking_reason = validation_errors[0]
        elif collection_mode == "test-fixture":
            blocking_reason = "test-fixture-not-actual-collection"
        else:
            blocking_reason = "actual-collection-incomplete"

    validation_rows = [
        {"check": "human-review-packet", "status": "pass" if human_ok else "blocked", "reason": ";".join(human_errors[:3])},
        {"check": "adjudication-packet", "status": "pass" if adjudication_ok else "blocked", "reason": ";".join(adjudication_errors[:3])},
        {"check": "independent-reproduction-packet", "status": "pass" if reproduction_ok else "blocked", "reason": ";".join(reproduction_errors[:3])},
        {"check": "actual-collection", "status": "pass" if actual_collection_ready else "blocked", "reason": blocking_reason},
    ]
    write_csv(out / "collection_validation_rows.csv", ["check", "status", "reason"], validation_rows)
    copied.append("collection_validation_rows.csv")

    manifest = {
        "manifest_scope": "release-review-collection",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "input_dir": str(input_dir) if input_dir else "",
        "collection_mode": collection_mode,
        "actual_collection_ready": actual_collection_ready,
        "test_fixture_collection_ready": test_fixture_collection_ready,
        "human_review_ready": 0,
        "independent_reproduction_ready": 0,
        "release_ready": 0,
        "real_release_package_ready": 0,
    }
    (out / "release_review_collection_manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    copied.append("release_review_collection_manifest.json")

    summary = {
        "release_review_collection_intake_ready": "1",
        "input_dir_supplied": "1" if input_dir else "0",
        "input_dir_accepted": "1" if input_dir and input_dir.is_dir() and not validation_errors else "0",
        "collection_mode": collection_mode,
        "human_review_rows": str(len(human_rows)),
        "reviewed_response_rows": str(reviewed_responses),
        "review_disagreement_rows": str(disagreements),
        "adjudication_rows": str(len(adjudication_rows)),
        "adjudication_required_rows": str(disagreements),
        "independent_reproduction_rows": str(len(reproduction_rows)),
        "human_review_packet_collected": "1" if actual_collection_ready and human_ok else "0",
        "adjudication_packet_collected": "1" if actual_collection_ready and adjudication_ok else "0",
        "independent_reproduction_packet_collected": "1" if actual_collection_ready and reproduction_ok else "0",
        "actual_collection_ready": str(actual_collection_ready),
        "test_fixture_collection_ready": str(test_fixture_collection_ready),
        "human_review_ready": "0",
        "independent_reproduction_ready": "0",
        "release_ready": "0",
        "real_release_package_ready": "0",
        "blocking_reason": blocking_reason,
        "evidence_dir": str(out),
    }
    write_csv(summary_csv, list(summary), [summary])
    decision_rows = [
        ("human-review-packet", "pass" if human_ok else "blocked", f"rows={len(human_rows)}"),
        ("adjudication-packet", "pass" if adjudication_ok else "blocked", f"rows={len(adjudication_rows)} required={disagreements}"),
        ("independent-reproduction-packet", "pass" if reproduction_ok else "blocked", f"rows={len(reproduction_rows)}"),
        ("actual-human-independent-collection", "pass" if actual_collection_ready else "blocked", blocking_reason),
        ("release-ready", "blocked", "collection intake never promotes release readiness"),
    ]
    write_csv(
        decision_csv,
        ["gate", "status", "reason"],
        [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows],
    )

    sha_rows = []
    for rel in copied:
        path = out / rel
        sha_rows.append({"path": rel, "sha256": sha256_file(path), "bytes": str(path.stat().st_size)})
    write_csv(out / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

    print(f"release_review_collection_dir: {out}")
    print(f"summary: {summary_csv}")
    print(f"decision: {decision_csv}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_template = sub.add_parser("template", help="write blank return CSV templates")
    p_template.add_argument("--out", required=True)
    p_template.set_defaults(func=cmd_template)

    p_collect = sub.add_parser("collect", help="validate and hash-bind supplied return rows")
    p_collect.add_argument("--input-dir", default="")
    p_collect.add_argument("--out", default=str(DEFAULT_OUT))
    p_collect.add_argument("--summary", default=str(DEFAULT_SUMMARY))
    p_collect.add_argument("--decision", default=str(DEFAULT_DECISION))
    p_collect.add_argument("--allow-test-fixture", action="store_true")
    p_collect.set_defaults(func=cmd_collect)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
