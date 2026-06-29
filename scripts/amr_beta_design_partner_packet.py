#!/usr/bin/env python3
"""Create an AMR beta design-partner packet from benchmark readiness.

This is a packaging helper only. It consumes existing readiness/backlog
artifacts, does not run benchmarks, does not fabricate human input, and keeps
release/public/model readiness blocked.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from amr_beta_readiness_backlog import build_backlog, is_forbidden_env_path, load_readiness, validate_readiness

SCHEMA = "amr_beta_design_partner_packet.v1"
CLAIM_BOUNDARY = "alpha-local-code-doc-audit-only"
BLOCKED_FLAGS = {
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}

OPERATOR_RUNBOOK = [
    "Keep all raw repositories, human decisions, and maintainer feedback local.",
    "Verify repo intake, label intake, feedback countability, benchmark input preparation, benchmark output, and readiness before every partner handoff.",
    "Treat every blocked readiness row as a remediation item before rerunning or expanding beta access.",
    "Do not present release, public-comparison, or model-execution claims from this packet.",
]

ONBOARDING_CHECKLIST = [
    "Provide the local install command and first-report command used in the benchmark.",
    "Share expected scope, known limitations, and source-citation review expectations with the design partner.",
    "Collect new maintainer feedback through the local feedback template and hash raw feedback before export.",
    "Record every rerun, remediation, and new label batch as a new evidence packet.",
]

KNOWN_LIMITATIONS = [
    "The packet is local-code/document/config audit evidence only.",
    "It is not a release-readiness, public benchmark, or real-model execution claim.",
    "Precision and citation validity are bounded by the supplied repositories, labels, maintainers, and benchmark run.",
    "New repositories, dependency changes, dirty worktrees, or changed labels require rerun and re-verification.",
]


def read_json(path: Path, input_name: str) -> dict:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} path")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{input_name} must contain an object")
    return payload


def packet_kind(readiness: dict, backlog_items: int) -> str:
    ready = int(readiness.get("design_partner_beta_candidate_ready", 0)) == 1
    return "design_partner_beta_candidate" if ready and backlog_items == 0 else "blocked_beta_candidate"


def load_backlog(path_text: str, readiness: dict) -> list[dict]:
    if not path_text:
        return build_backlog(readiness)
    path = Path(path_text).expanduser().resolve()
    payload = read_json(path, "backlog")
    backlog = payload.get("backlog", [])
    if not isinstance(backlog, list):
        raise ValueError("backlog JSON must contain a backlog list")
    if payload.get("release_ready", 0) != 0:
        raise ValueError("backlog JSON must keep release_ready=0")
    if payload.get("public_comparison_claim_ready", 0) != 0:
        raise ValueError("backlog JSON must keep public_comparison_claim_ready=0")
    if payload.get("real_model_execution_ready", 0) != 0:
        raise ValueError("backlog JSON must keep real_model_execution_ready=0")
    return [row for row in backlog if isinstance(row, dict)]


def build_packet(readiness: dict, backlog: list[dict], *, readiness_path: Path, backlog_path: str) -> dict:
    ready = int(readiness.get("design_partner_beta_candidate_ready", 0))
    kind = packet_kind(readiness, len(backlog))
    if ready == 1 and backlog:
        raise ValueError("ready beta packet cannot include backlog items")
    return {
        "schema": SCHEMA,
        "claim_boundary": CLAIM_BOUNDARY,
        "packet_kind": kind,
        "input_readiness": str(readiness_path),
        "input_backlog": backlog_path,
        "product_readiness_calculated_from_real_labels": int(
            readiness.get("product_readiness_calculated_from_real_labels", 0)
        ),
        "design_partner_beta_candidate_ready": ready,
        **BLOCKED_FLAGS,
        "gate_rows": int(readiness.get("gate_rows", 0)),
        "passed_gate_rows": int(readiness.get("passed_gate_rows", 0)),
        "blocked_gate_rows": int(readiness.get("blocked_gate_rows", 0)),
        "backlog_items": len(backlog),
        "operator_runbook": OPERATOR_RUNBOOK,
        "onboarding_checklist": ONBOARDING_CHECKLIST,
        "known_limitations": KNOWN_LIMITATIONS,
        "backlog": backlog,
    }


def write_markdown(path: Path, packet: dict) -> None:
    lines = [
        "# AMR Beta Design-Partner Packet",
        "",
        f"- packet_kind: {packet['packet_kind']}",
        f"- design_partner_beta_candidate_ready: {packet['design_partner_beta_candidate_ready']}",
        f"- blocked_gate_rows: {packet['blocked_gate_rows']}",
        f"- release_ready: {packet['release_ready']}",
        f"- public_comparison_claim_ready: {packet['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {packet['real_model_execution_ready']}",
        "",
        "## Operator Runbook",
        "",
    ]
    lines.extend(f"- {item}" for item in packet["operator_runbook"])
    lines.extend(["", "## Onboarding Checklist", ""])
    lines.extend(f"- {item}" for item in packet["onboarding_checklist"])
    lines.extend(["", "## Known Limitations", ""])
    lines.extend(f"- {item}" for item in packet["known_limitations"])
    lines.extend(["", "## Backlog", ""])
    if not packet["backlog"]:
        lines.append("No blocked readiness gates were reported.")
    for item in packet["backlog"]:
        lines.extend(
            [
                f"### {item.get('gate_id', 'unknown_gate')}",
                "",
                f"- area: {item.get('area', '')}",
                f"- owner: {item.get('owner', '')}",
                f"- observed: {item.get('observed', '')}",
                f"- required: {item.get('required', '')}",
                f"- next_action: {item.get('next_action', '')}",
                "",
            ]
        )
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--readiness", required=True, help="Path to benchmark_readiness.json.")
    parser.add_argument("--backlog", default="", help="Optional backlog JSON from amr_beta_readiness_backlog.py.")
    parser.add_argument("--out-json", required=True, help="Output packet JSON path.")
    parser.add_argument("--out-md", default="", help="Optional output packet Markdown path.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        readiness_path = Path(args.readiness).expanduser().resolve()
        readiness = load_readiness(readiness_path)
        errors = validate_readiness(readiness)
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            if args.json:
                print(json.dumps({"schema": SCHEMA, "errors": errors}, indent=2, sort_keys=True))
            return 1
        backlog = load_backlog(args.backlog, readiness)
        packet = build_packet(
            readiness,
            backlog,
            readiness_path=readiness_path,
            backlog_path=str(Path(args.backlog).expanduser().resolve()) if args.backlog else "",
        )
        out_json = Path(args.out_json).expanduser().resolve()
        out_md = Path(args.out_md).expanduser().resolve() if args.out_md else None
        for path in [out_json, *([out_md] if out_md else [])]:
            if is_forbidden_env_path(path):
                raise ValueError("refusing .env-like output path")
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.exists() and not args.overwrite:
                raise ValueError(f"output already exists; use --overwrite: {path}")
        out_json.write_text(json.dumps(packet, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        if out_md:
            write_markdown(out_md, packet)
        if args.json:
            print(json.dumps({**packet, "errors": []}, indent=2, sort_keys=True))
        else:
            print(f"design_partner_packet: ok packet_kind={packet['packet_kind']}")
        return 0
    except Exception as exc:
        print(f"design_partner_packet: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
