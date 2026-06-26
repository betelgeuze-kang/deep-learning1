#!/usr/bin/env python3
"""Convert design-partner finding-review issues into normalized JSONL decisions.

Turns "Design Partner Finding Review" GitHub issue-form responses into one
JSONL decision row per finding, validates them, and summarizes the collected
human labels against the audit-my-repo beta targets.

    convert    parse issue bodies -> decisions.jsonl (one row per issue)
    validate   re-validate a decisions.jsonl (schema + allowed values)
    summarize  aggregate collected labels (distinct repos/reviewers, validity
               precision, P0/P1 precision, citation validity) vs beta targets

Input for `convert` (--issues):
- a JSON file: a list of issue objects, each with `body` and optionally
  `number`, `user`/`author`, `created_at` (the shape of the GitHub issues API), or
- a directory of `*.md` files, each containing one issue body (the filename
  stem becomes issue_ref).

BOUNDARY: this normalizes/aggregates collected human labels only. It admits no
evidence, writes nothing to results/ or contracts, and flips no readiness flag.
`design_partner_beta_candidate_ready` stays decided by the project verifier
after real labels are supplied; the `summarize` numbers are candidate aggregates,
not a readiness claim.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

LABEL_MAP = {
    "Repository commit SHA": "repo_head_sha",
    "Finding ID": "finding_id",
    "Finding validity": "finding_validity",
    "Priority": "priority",
    "Citation correctness": "citation_correct",
    "Expected source span": "expected_source_span",
    "Reviewer independence": "reviewer_independence",
    "Reviewer notes / rationale": "notes",
}
ALLOWED = {
    "finding_validity": {"present", "absent", "ambiguous"},
    "priority": {"P0", "P1", "P2", "informational"},
    "citation_correct": {"correct", "incorrect", "partial", "not-applicable"},
    "reviewer_independence": {
        "external-maintainer",
        "external-contributor",
        "independent-third-party",
        "project-internal",
    },
}
REQUIRED = ["repo_head_sha", "finding_id", "finding_validity", "priority", "citation_correct", "reviewer_independence"]
SHA_RE = re.compile(r"^[0-9a-f]{7,64}$")
HEADING_RE = re.compile(r"^###\s+(.*\S)\s*$")

BETA_TARGETS = {
    "min_labels": 300,
    "min_repos": 10,
    "min_reviewers": 3,
    "min_precision": 0.80,
    "min_p0_p1_precision": 0.90,
    "min_citation_validity": 1.00,
}


def parse_issue_form(body: str) -> dict:
    fields: dict[str, str] = {}
    current = None
    buf: list[str] = []
    for line in body.splitlines():
        match = HEADING_RE.match(line)
        if match:
            if current is not None:
                fields[current] = "\n".join(buf).strip()
            current = match.group(1).strip()
            buf = []
        else:
            buf.append(line)
    if current is not None:
        fields[current] = "\n".join(buf).strip()
    decision: dict[str, str] = {}
    for label, key in LABEL_MAP.items():
        value = fields.get(label, "").strip()
        if value == "_No response_":
            value = ""
        decision[key] = value
    return decision


def validate_decision(decision: dict) -> list[str]:
    errors: list[str] = []
    for key in REQUIRED:
        if not (decision.get(key) or "").strip():
            errors.append(f"missing required field {key}")
    sha = (decision.get("repo_head_sha") or "").strip().lower()
    if sha and not SHA_RE.match(sha):
        errors.append(f"repo_head_sha not a commit sha: {sha!r}")
    for key, allowed in ALLOWED.items():
        value = (decision.get(key) or "").strip()
        if value and value not in allowed:
            errors.append(f"{key}={value!r} not in {sorted(allowed)}")
    return errors


def _load_issues(path: Path) -> list[dict]:
    if path.is_dir():
        issues = []
        for md in sorted(path.glob("*.md")):
            issues.append({"issue_ref": md.stem, "body": md.read_text(encoding="utf-8")})
        return issues
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        data = data.get("issues", [])
    issues = []
    for item in data:
        user = item.get("user") or item.get("author") or {}
        reviewer = user.get("login") if isinstance(user, dict) else (user or "")
        issues.append(
            {
                "issue_ref": str(item.get("number", item.get("issue_ref", ""))),
                "reviewer": reviewer or "",
                "created_at": item.get("created_at", ""),
                "body": item.get("body", "") or "",
            }
        )
    return issues


def cmd_convert(args: argparse.Namespace) -> int:
    issues = _load_issues(Path(args.issues))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for issue in issues:
        decision = parse_issue_form(issue["body"])
        decision["issue_ref"] = issue.get("issue_ref", "")
        decision["reviewer"] = issue.get("reviewer", "")
        decision["created_at"] = issue.get("created_at", "")
        errors = validate_decision(decision)
        decision["valid"] = not errors
        decision["validation_errors"] = errors
        rows.append(decision)
    with out.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, sort_keys=True) + "\n")
    valid = sum(1 for r in rows if r["valid"])
    print(f"wrote {len(rows)} decision row(s) to {out} ({valid} valid, {len(rows) - valid} invalid)")
    return 0


def _read_jsonl(path: Path) -> list[dict]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            rows.append(json.loads(line))
    return rows


def cmd_validate(args: argparse.Namespace) -> int:
    rows = _read_jsonl(Path(args.decisions))
    bad = 0
    for index, row in enumerate(rows, start=1):
        errors = validate_decision(row)
        if errors:
            bad += 1
            print(f"row {index} ({row.get('issue_ref','?')}): {errors}", file=sys.stderr)
    if bad:
        print(f"audit review decisions BLOCKED: {bad}/{len(rows)} invalid", file=sys.stderr)
        return 1
    print(f"audit review decisions ok: {len(rows)} valid")
    return 0


def cmd_summarize(args: argparse.Namespace) -> int:
    rows = [r for r in _read_jsonl(Path(args.decisions)) if r.get("valid", True) and not validate_decision(r)]
    total = len(rows)
    repos = {(r.get("repo_head_sha") or "").strip().lower() for r in rows if r.get("repo_head_sha")}
    reviewers = {(r.get("reviewer") or "").strip() for r in rows if (r.get("reviewer") or "").strip()}
    present = sum(1 for r in rows if r.get("finding_validity") == "present")
    absent = sum(1 for r in rows if r.get("finding_validity") == "absent")
    decided = present + absent
    p0p1 = [r for r in rows if r.get("priority") in {"P0", "P1"}]
    p0p1_present = sum(1 for r in p0p1 if r.get("finding_validity") == "present")
    p0p1_absent = sum(1 for r in p0p1 if r.get("finding_validity") == "absent")
    p0p1_decided = p0p1_present + p0p1_absent
    citation_correct = sum(1 for r in rows if r.get("citation_correct") == "correct")

    def ratio(num: int, den: int) -> float:
        return (num / den) if den else 0.0

    summary = {
        "boundary": "candidate-aggregate-of-collected-human-labels; not a readiness claim",
        "total_labels": total,
        "distinct_repos": len(repos),
        "distinct_reviewers": len(reviewers),
        "validity_counts": {"present": present, "absent": absent, "ambiguous": total - decided},
        "precision": round(ratio(present, decided), 6),
        "p0_p1_precision": round(ratio(p0p1_present, p0p1_decided), 6),
        "citation_validity": round(ratio(citation_correct, total), 6),
        "beta_targets": BETA_TARGETS,
        "targets_met": {
            "labels": total >= BETA_TARGETS["min_labels"],
            "repos": len(repos) >= BETA_TARGETS["min_repos"],
            "reviewers": len(reviewers) >= BETA_TARGETS["min_reviewers"],
            "precision": ratio(present, decided) >= BETA_TARGETS["min_precision"],
            "p0_p1_precision": ratio(p0p1_present, p0p1_decided) >= BETA_TARGETS["min_p0_p1_precision"],
            "citation_validity": ratio(citation_correct, total) >= BETA_TARGETS["min_citation_validity"],
        },
    }
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_convert = sub.add_parser("convert", help="issue bodies -> decisions.jsonl")
    p_convert.add_argument("--issues", required=True, help="JSON list of issues, or a dir of *.md bodies")
    p_convert.add_argument("--out", required=True, help="output decisions.jsonl")
    p_convert.set_defaults(func=cmd_convert)

    p_validate = sub.add_parser("validate", help="validate a decisions.jsonl")
    p_validate.add_argument("--decisions", required=True)
    p_validate.set_defaults(func=cmd_validate)

    p_summarize = sub.add_parser("summarize", help="aggregate decisions vs beta targets")
    p_summarize.add_argument("--decisions", required=True)
    p_summarize.set_defaults(func=cmd_summarize)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
