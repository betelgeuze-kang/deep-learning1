#!/usr/bin/env python3
"""v54 training + heldout generation packet: template + preflight.

Return-side staging for a real v54 training/heldout run. It fixes the schema and
safety rules of the packet an executor returns, without running training or
admitting evidence.

    template   emit a blank packet (split rows, config, checkpoint manifest,
               free-running generation rows, heldout metric rows).
    preflight  validate a filled packet against the schema and the v54 rules.
    manifest   write sha256_manifest.csv over the packet files.

Rules enforced (matching the v54 contracts):
- training may use teacher forcing; evaluation must be free-running only
  (free_running_in_eval=true; every generation row free_running_decode=1,
  teacher_forcing_used=0),
- no raw source span in the prompt (raw_prompt_context_bytes=0,
  raw_source_span_in_prompt=false),
- no source locator leakage (source_locator_leakage=0/false),
- every generation row carries an output sha256,
- heldout repos are disjoint from train/calibration (unseen split), and metrics
  are reported on the heldout split only.

BOUNDARY: staging only. This admits no evidence, runs no training, and flips no
readiness flag. real_model_generation_ready / heldout_metric_ready stay decided
by the canonical experiments/test_v54f_*.sh intake after a real run.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

V54F_CONTRACT = "v54/free_running_generation_evidence_intake_contract.json"
SHA256_RE = re.compile(r"^(sha256:)?[0-9a-f]{64}$")
TRUE_TOKENS = {"1", "true", "yes"}
FALSE_TOKENS = {"0", "false", "no"}

SPLIT_COLUMNS = ["query_id", "repo_id", "split", "source_query_hash"]
HELDOUT_METRIC_COLUMNS = ["split", "metric", "value", "n"]
GEN_FIELDS = {
    "free_running_decode": "1",
    "teacher_forcing_used": "0",
    "raw_prompt_context_bytes": "0",
    "source_locator_leakage": "0",
    "external_api_used": "0",
}
PACKET_FILES = [
    "train_split_rows.csv",
    "calibration_split_rows.csv",
    "heldout_split_rows.csv",
    "generation_config.json",
    "checkpoint_manifest.json",
    "free_running_generation_rows.csv",
    "heldout_metric_rows.csv",
]


def read_rows(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def write_csv(path: Path, header: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def generation_columns(contract_path: Path) -> list[str]:
    data = json.loads(contract_path.read_text(encoding="utf-8"))
    for artifact in data.get("required_artifacts", []):
        if artifact["artifact_id"] == "free-running-generation-template-rows":
            return list(artifact["required_columns"])
    raise SystemExit(f"{contract_path}: free-running-generation-template-rows not found")


# --------------------------------------------------------------------------- #
# template
# --------------------------------------------------------------------------- #
def cmd_template(args: argparse.Namespace) -> int:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    gen_columns = generation_columns(Path(args.contract))

    def split_rows(split: str, repos: list[str]) -> list[dict]:
        rows = []
        for repo in repos:
            for index in (1, 2):
                rows.append(
                    {
                        "query_id": f"q{index:06d}",
                        "repo_id": repo,
                        "split": split,
                        "source_query_hash": "<sha256-of-frozen-v53-query-set>",
                    }
                )
        return rows

    write_csv(out / "train_split_rows.csv", SPLIT_COLUMNS, split_rows("train", ["<train-repo-1>", "<train-repo-2>"]))
    write_csv(out / "calibration_split_rows.csv", SPLIT_COLUMNS, split_rows("calibration", ["<calibration-repo-1>"]))
    write_csv(out / "heldout_split_rows.csv", SPLIT_COLUMNS, split_rows("heldout", ["<unseen-repo-1>", "<unseen-repo-2>"]))

    (out / "generation_config.json").write_text(
        json.dumps(
            {
                "generator_id": "<generator-id>",
                "vocab_size": "<int>",
                "embed_dim": "<int>",
                "hidden_dim": "<int>",
                "context_dim": "<int>",
                "seed": "<int>",
                "query_source": args.query_source,
                "teacher_forcing_in_training": True,
                "free_running_in_eval": True,
                "raw_source_span_in_prompt": False,
                "source_locator_leakage": False,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    (out / "checkpoint_manifest.json").write_text(
        json.dumps(
            {
                "checkpoint_sha256": "sha256:<64-hex-of-checkpoint>",
                "config_sha256": "sha256:<64-hex-of-generation_config.json>",
                "trained_on_split": "train",
                "calibrated_on_split": "calibration",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    blank_gen = {column: "" for column in gen_columns}
    for field, value in GEN_FIELDS.items():
        if field in blank_gen:
            blank_gen[field] = value
    blank_gen_row = dict(blank_gen)
    if "query_id" in blank_gen_row:
        blank_gen_row["query_id"] = "q000001"
    write_csv(out / "free_running_generation_rows.csv", gen_columns, [blank_gen_row])

    write_csv(
        out / "heldout_metric_rows.csv",
        HELDOUT_METRIC_COLUMNS,
        [{"split": "heldout", "metric": "<answer_exact_match>", "value": "<float>", "n": "<int>"}],
    )

    print(f"wrote v54 training/heldout packet template to {out} (query_source={args.query_source})")
    return 0


# --------------------------------------------------------------------------- #
# preflight
# --------------------------------------------------------------------------- #
def _repos_for_split(path: Path) -> set[str]:
    _, rows = read_rows(path)
    return {(r.get("repo_id") or "").strip() for r in rows if (r.get("repo_id") or "").strip()}


def _heldout_query_ids(path: Path) -> set[str]:
    _, rows = read_rows(path)
    return {(r.get("query_id") or "").strip() for r in rows if (r.get("query_id") or "").strip()}


def cmd_preflight(args: argparse.Namespace) -> int:
    packet = Path(args.packet)
    gen_columns = generation_columns(Path(args.contract))
    errors: list[str] = []

    for name in PACKET_FILES:
        if not (packet / name).is_file():
            errors.append(f"{packet}: missing required packet file {name}")
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f"v54 training packet preflight BLOCKED: {len(errors)} issue(s)", file=sys.stderr)
        return 1

    # split column shape
    for split_file in ("train_split_rows.csv", "calibration_split_rows.csv", "heldout_split_rows.csv"):
        header, _ = read_rows(packet / split_file)
        if header != SPLIT_COLUMNS:
            errors.append(f"{packet / split_file}: header must be exactly {SPLIT_COLUMNS}; got {header}")

    # heldout must be unseen: disjoint repos from train and calibration
    train_repos = _repos_for_split(packet / "train_split_rows.csv")
    calib_repos = _repos_for_split(packet / "calibration_split_rows.csv")
    heldout_repos = _repos_for_split(packet / "heldout_split_rows.csv")
    if heldout_repos & train_repos:
        errors.append(f"{packet}: heldout repos overlap train repos {sorted(heldout_repos & train_repos)}")
    if heldout_repos & calib_repos:
        errors.append(f"{packet}: heldout repos overlap calibration repos {sorted(heldout_repos & calib_repos)}")
    if train_repos & calib_repos:
        errors.append(f"{packet}: train repos overlap calibration repos {sorted(train_repos & calib_repos)}")

    # generation_config rules
    try:
        config = json.loads((packet / "generation_config.json").read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        config = {}
        errors.append(f"{packet}/generation_config.json: invalid JSON ({exc})")
    if config.get("free_running_in_eval") is not True:
        errors.append(f"{packet}/generation_config.json: free_running_in_eval must be true")
    if config.get("raw_source_span_in_prompt") is not False:
        errors.append(f"{packet}/generation_config.json: raw_source_span_in_prompt must be false")
    if config.get("source_locator_leakage") is not False:
        errors.append(f"{packet}/generation_config.json: source_locator_leakage must be false")
    # teacher_forcing_in_training is allowed either way (training may teacher-force).

    # checkpoint manifest
    try:
        checkpoint = json.loads((packet / "checkpoint_manifest.json").read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        checkpoint = {}
        errors.append(f"{packet}/checkpoint_manifest.json: invalid JSON ({exc})")
    if not SHA256_RE.match(str(checkpoint.get("checkpoint_sha256", "")).lower()):
        errors.append(f"{packet}/checkpoint_manifest.json: checkpoint_sha256 must be a sha256 hash")

    # free-running generation rows: schema + eval rules + output hash + heldout-only
    gen_header, gen_rows = read_rows(packet / "free_running_generation_rows.csv")
    if gen_header != gen_columns:
        errors.append(f"{packet}/free_running_generation_rows.csv: header must match the v54f contract columns")
    else:
        heldout_qids = _heldout_query_ids(packet / "heldout_split_rows.csv")
        for index, row in enumerate(gen_rows, start=1):
            prefix = f"{packet}/free_running_generation_rows.csv:row{index}"
            if (row.get("free_running_decode") or "").strip() not in TRUE_TOKENS:
                errors.append(f"{prefix}: free_running_decode must be 1 (eval is free-running only)")
            if (row.get("teacher_forcing_used") or "").strip() not in FALSE_TOKENS:
                errors.append(f"{prefix}: teacher_forcing_used must be 0 at evaluation")
            if (row.get("raw_prompt_context_bytes") or "").strip() != "0":
                errors.append(f"{prefix}: raw_prompt_context_bytes must be 0 (no raw source span in prompt)")
            if (row.get("source_locator_leakage") or "").strip() not in FALSE_TOKENS:
                errors.append(f"{prefix}: source_locator_leakage must be 0")
            if (row.get("external_api_used") or "").strip() not in FALSE_TOKENS:
                errors.append(f"{prefix}: external_api_used must be 0")
            if not SHA256_RE.match((row.get("raw_output_sha256") or "").strip().lower()):
                errors.append(f"{prefix}: raw_output_sha256 must be a sha256 hash (output hash required)")
            qid = (row.get("query_id") or "").strip()
            if heldout_qids and qid and qid not in heldout_qids:
                errors.append(f"{prefix}: query_id {qid} is not in the heldout split (eval must be heldout)")

    # heldout metric rows on heldout split only
    metric_header, metric_rows = read_rows(packet / "heldout_metric_rows.csv")
    if metric_header != HELDOUT_METRIC_COLUMNS:
        errors.append(f"{packet}/heldout_metric_rows.csv: header must be exactly {HELDOUT_METRIC_COLUMNS}")
    else:
        for index, row in enumerate(metric_rows, start=1):
            if (row.get("split") or "").strip() != "heldout":
                errors.append(f"{packet}/heldout_metric_rows.csv:row{index}: split must be heldout")

    # sha256 manifest (verify if present or required)
    manifest_path = packet / "sha256_manifest.csv"
    if args.require_manifest and not manifest_path.is_file():
        errors.append(f"{manifest_path}: sha256 manifest required (--require-manifest) but missing")
    elif manifest_path.is_file():
        _verify_manifest(packet, manifest_path, errors)

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f"v54 training packet preflight BLOCKED: {len(errors)} issue(s)", file=sys.stderr)
        return 1
    print(
        "v54 training/heldout packet preflight ok (splits disjoint, free-running eval, "
        "no raw span / locator leakage, output hashes present, heldout-only metrics). "
        "This admits no evidence; run the canonical v54f intake next."
    )
    return 0


def _verify_manifest(packet: Path, manifest_path: Path, errors: list[str]) -> None:
    header, rows = read_rows(manifest_path)
    if header != ["path", "sha256", "bytes"]:
        errors.append(f"{manifest_path}: header must be exactly path,sha256,bytes; got {header}")
        return
    listed = set()
    for row in rows:
        rel = (row.get("path") or "").strip()
        listed.add(rel)
        target = packet / rel
        if not target.is_file():
            errors.append(f"{manifest_path}: listed file missing: {rel}")
            continue
        if (row.get("sha256") or "").strip().lower() != sha256_file(target):
            errors.append(f"{manifest_path}: sha256 mismatch for {rel}")
    for name in PACKET_FILES:
        if name not in listed:
            errors.append(f"{manifest_path}: missing manifest entry for {name}")


def cmd_manifest(args: argparse.Namespace) -> int:
    packet = Path(args.packet)
    rows = []
    for name in PACKET_FILES:
        target = packet / name
        if not target.is_file():
            raise SystemExit(f"{target}: packet file missing; cannot build manifest")
        rows.append({"path": name, "sha256": sha256_file(target), "bytes": str(target.stat().st_size)})
    write_csv(packet / "sha256_manifest.csv", ["path", "sha256", "bytes"], rows)
    print(f"wrote {packet / 'sha256_manifest.csv'} ({len(rows)} entries)")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", default=V54F_CONTRACT, help="v54f contract (generation row columns)")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_template = sub.add_parser("template", help="emit a blank training/heldout packet")
    p_template.add_argument("--out", required=True)
    p_template.add_argument("--query-source", dest="query_source", default="v53")
    p_template.set_defaults(func=cmd_template)

    p_preflight = sub.add_parser("preflight", help="validate a filled packet")
    p_preflight.add_argument("--packet", required=True)
    p_preflight.add_argument("--require-manifest", dest="require_manifest", action="store_true")
    p_preflight.set_defaults(func=cmd_preflight)

    p_manifest = sub.add_parser("manifest", help="write sha256_manifest.csv for a packet")
    p_manifest.add_argument("--packet", required=True)
    p_manifest.set_defaults(func=cmd_manifest)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
