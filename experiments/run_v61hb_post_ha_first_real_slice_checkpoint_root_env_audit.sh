#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61hb_post_ha_first_real_slice_checkpoint_root_env_audit"
RUN_ID="${V61HB_RUN_ID:-checkpoint_env_audit_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKAGE_DIR="$RUN_DIR/first_real_slice_checkpoint_root_env_audit"
WORK_ROOT="${V61HB_WORK_ROOT:-${V61GU_WORK_ROOT:-}}"
CHECKPOINT_ROOT="${V61HB_CHECKPOINT_ROOT:-}"
APPLY_CHECKPOINT_ROOT="${V61HB_APPLY_CHECKPOINT_ROOT:-0}"
HASH_CHECKPOINT_SHARDS="${V61HB_HASH_CHECKPOINT_SHARDS:-0}"

if [[ "${V61HB_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61HA_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ha_post_gz_first_real_slice_source_witness_promotion_audit.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$PACKAGE_DIR" "$RUN_ID" "$WORK_ROOT" "$CHECKPOINT_ROOT" "$APPLY_CHECKPOINT_ROOT" "$HASH_CHECKPOINT_SHARDS" <<'PY'
import csv
import hashlib
import json
import re
import shlex
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
package_dir = Path(sys.argv[5])
run_id = sys.argv[6]
work_root_raw = sys.argv[7].strip()
checkpoint_root_raw = sys.argv[8].strip()
apply_requested = int(sys.argv[9] == "1")
hash_checkpoint_shards = int(sys.argv[10] == "1")
results = root / "results"
prefix = "v61hb_post_ha_first_real_slice_checkpoint_root_env_audit"
package_dir.mkdir(parents=True, exist_ok=True)

EXPECTED_SHARDS = 59
PLACEHOLDER = "REPLACE_WITH_FINAL_CHECKPOINT_ROOT"
VALUE_ENV = [
    "V61GI_REVIEWER_ID",
    "V61GI_ADJUDICATOR_ID",
    "V61GI_GENERATION_ID",
    "V61GI_CITATION_ID",
    "V61GI_CHECKPOINT_ROOT",
    "V61GI_LATENCY_ROW_ID",
    "V61GI_PROMPT_TOKENS",
    "V61GI_OUTPUT_TOKENS",
    "V61GI_PREFILL_MS",
    "V61GI_DECODE_MS",
    "V61GI_TOTAL_MS",
    "V61GI_TOKENS_PER_SECOND",
    "V61GI_V53_AUTHORITY_STATEMENT",
    "V61GI_V61_AUTHORITY_STATEMENT",
    "V61GI_EXTERNAL_RETURN_ATTESTATION",
    "V61GI_OPERATOR_INPUT_ASSEMBLY_AUTHORITY_STATEMENT",
]
NONFINAL_TOKENS = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy_source(source_id, src, folder):
    dst = run_dir / folder / src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return {
        "source_id": source_id,
        "path": dst.relative_to(run_dir).as_posix(),
        "bytes": str(dst.stat().st_size),
        "sha256": sha256(dst),
        "metadata_only": "1",
    }


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def unquote_env(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def has_nonfinal_text(value):
    lowered = value.lower()
    return any(token in lowered for token in NONFINAL_TOKENS)


def parse_env_template(path):
    env = {}
    export_re = re.compile(r"^export\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
    if not path.is_file():
        return env
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = export_re.match(line.strip())
        if match:
            env[match.group(1)] = unquote_env(match.group(2))
    return env


def checkpoint_inventory(checkpoint_root):
    rows = []
    valid_names = set()
    total_bytes = 0
    if checkpoint_root is not None and checkpoint_root.is_dir():
        for path in sorted(checkpoint_root.glob("*.safetensors")):
            match = re.fullmatch(r"model-(\d{5})-of-00059\.safetensors", path.name)
            size = path.stat().st_size
            shard_index = int(match.group(1)) if match else 0
            if match:
                valid_names.add(shard_index)
            total_bytes += size
            sampled_hash = hash_checkpoint_shards and (len(rows) < 2 or path.name.endswith("00059.safetensors"))
            rows.append({
                "shard_file": path.name,
                "shard_index": str(shard_index),
                "bytes": str(size),
                "nonempty": str(int(size > 0)),
                "name_matches_expected_pattern": str(int(match is not None)),
                "sha256": sha256(path) if sampled_hash else "",
                "sha256_scope": "sampled-first2-and-last" if sampled_hash else "omitted-fast-mode",
            })
    expected_indexes = set(range(1, EXPECTED_SHARDS + 1))
    valid = int(
        len(rows) == EXPECTED_SHARDS
        and valid_names == expected_indexes
        and all(row["nonempty"] == "1" and row["name_matches_expected_pattern"] == "1" for row in rows)
    )
    return rows, total_bytes, valid


source_paths = {
    "v61ha_summary": results / "v61ha_post_gz_first_real_slice_source_witness_promotion_audit_summary.csv",
    "v61ha_decision": results / "v61ha_post_gz_first_real_slice_source_witness_promotion_audit_decision.csv",
}
for source_id, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61hb source {source_id}: {path}")
source_rows = [copy_source(source_id, path, "source_v61ha") for source_id, path in source_paths.items()]
write_csv(run_dir / "first_real_slice_checkpoint_root_env_audit_source_rows.csv", list(source_rows[0].keys()), source_rows)

v61ha = read_csv(source_paths["v61ha_summary"])[0]
if v61ha.get("v61ha_post_gz_first_real_slice_source_witness_promotion_audit_ready") != "1":
    raise SystemExit("v61hb requires v61ha ready")

work_root = Path(work_root_raw).expanduser().resolve() if work_root_raw else None
checkpoint_root = Path(checkpoint_root_raw).expanduser().resolve() if checkpoint_root_raw else None
work_root_supplied = int(work_root is not None)
work_root_exists = int(work_root is not None and work_root.is_dir())
work_root_outside_repo = int(work_root is not None and not is_inside(work_root, root))
checkpoint_root_supplied = int(checkpoint_root is not None)
checkpoint_root_exists = int(checkpoint_root is not None and checkpoint_root.is_dir())
checkpoint_root_outside_repo = int(checkpoint_root is not None and not is_inside(checkpoint_root, root))

shard_rows, total_checkpoint_bytes, checkpoint_root_valid = checkpoint_inventory(checkpoint_root)
if not shard_rows:
    shard_rows = [{
        "shard_file": "none",
        "shard_index": "0",
        "bytes": "0",
        "nonempty": "0",
        "name_matches_expected_pattern": "0",
        "sha256": "",
        "sha256_scope": "not-supplied",
    }]
write_csv(run_dir / "first_real_slice_checkpoint_root_env_shard_rows.csv", list(shard_rows[0].keys()), shard_rows)

env_template = work_root / "FIRST_REAL_SLICE_ENV_TEMPLATE.sh" if work_root else None
env_template_exists = int(env_template is not None and env_template.is_file())
env_before = parse_env_template(env_template) if env_template else {}
checkpoint_env_before = env_before.get("V61GI_CHECKPOINT_ROOT", "")
checkpoint_env_present_before = int("V61GI_CHECKPOINT_ROOT" in env_before)
checkpoint_env_was_placeholder = int(checkpoint_env_before == PLACEHOLDER or "REPLACE_WITH" in checkpoint_env_before)
checkpoint_env_already_set_before = int(checkpoint_env_present_before and not checkpoint_env_was_placeholder and not has_nonfinal_text(checkpoint_env_before))

apply_admitted = int(
    apply_requested
    and work_root_exists
    and work_root_outside_repo
    and env_template_exists
    and checkpoint_root_exists
    and checkpoint_root_outside_repo
    and checkpoint_root_valid
)
applied = 0
apply_message = "not-requested"
if apply_requested and not apply_admitted:
    apply_message = "blocked-by-preflight"
elif apply_admitted:
    lines = env_template.read_text(encoding="utf-8", errors="replace").splitlines()
    new_line = f"export V61GI_CHECKPOINT_ROOT={shlex.quote(str(checkpoint_root))}"
    replaced = False
    for index, line in enumerate(lines):
        if line == f"export V61GI_CHECKPOINT_ROOT={PLACEHOLDER}":
            lines[index] = new_line
            replaced = True
            break
        if line.startswith("export V61GI_CHECKPOINT_ROOT="):
            current = unquote_env(line.split("=", 1)[1])
            if current == str(checkpoint_root):
                replaced = True
                break
    if replaced:
        env_template.write_text("\n".join(lines) + "\n", encoding="utf-8")
        applied = int(checkpoint_env_before != str(checkpoint_root))
        apply_message = "applied" if applied else "already-set"
    else:
        apply_message = "missing-exact-placeholder"

env_after = parse_env_template(env_template) if env_template else {}
checkpoint_env_after = env_after.get("V61GI_CHECKPOINT_ROOT", "")
checkpoint_env_ready_after = int(
    "V61GI_CHECKPOINT_ROOT" in env_after
    and checkpoint_env_after == str(checkpoint_root)
    and checkpoint_root_valid
    and not has_nonfinal_text(checkpoint_env_after)
)
ready_value_env_rows_after = 0
for key in VALUE_ENV:
    value = env_after.get(key, "")
    placeholder = int((not value) or "REPLACE_WITH" in value or has_nonfinal_text(value))
    ready_value_env_rows_after += int(not placeholder)
env_value_gap_rows_after = len(VALUE_ENV) - ready_value_env_rows_after

apply_rows = [{
    "run_id": run_id,
    "work_root": str(work_root) if work_root else "",
    "checkpoint_root": str(checkpoint_root) if checkpoint_root else "",
    "apply_requested": str(apply_requested),
    "apply_admitted": str(apply_admitted),
    "applied": str(applied),
    "apply_message": apply_message,
    "checkpoint_env_before": checkpoint_env_before,
    "checkpoint_env_after": checkpoint_env_after,
    "accepted_as_real_review_evidence": "0",
    "accepted_as_real_generation_result": "0",
}]
write_csv(run_dir / "first_real_slice_checkpoint_root_env_apply_rows.csv", list(apply_rows[0].keys()), apply_rows)

candidate_rows = [{
    "candidate_id": "v61hb-checkpoint-root",
    "checkpoint_root": str(checkpoint_root) if checkpoint_root else "",
    "checkpoint_root_supplied": str(checkpoint_root_supplied),
    "checkpoint_root_exists": str(checkpoint_root_exists),
    "checkpoint_root_outside_repo": str(checkpoint_root_outside_repo),
    "expected_shard_rows": str(EXPECTED_SHARDS),
    "observed_safetensor_rows": str(0 if shard_rows[0]["shard_file"] == "none" else len(shard_rows)),
    "checkpoint_root_valid": str(checkpoint_root_valid),
    "total_checkpoint_bytes": str(total_checkpoint_bytes),
    "checkpoint_shard_hash_mode": str(hash_checkpoint_shards),
    "copied_checkpoint_payload_bytes_to_repo": "0",
}]
write_csv(run_dir / "first_real_slice_checkpoint_root_env_candidate_rows.csv", list(candidate_rows[0].keys()), candidate_rows)

stage_rows = [
    {"stage_id": "01-v61ha-source", "status": "ready", "evidence": "v61ha ready"},
    {"stage_id": "02-work-root", "status": "ready" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"stage_id": "03-env-template", "status": "ready" if env_template_exists else "blocked", "evidence": f"env_template_exists={env_template_exists}"},
    {"stage_id": "04-checkpoint-root", "status": "ready" if checkpoint_root_valid and checkpoint_root_outside_repo else "blocked", "evidence": f"checkpoint_root_valid={checkpoint_root_valid}; observed_safetensor_rows={candidate_rows[0]['observed_safetensor_rows']}"},
    {"stage_id": "05-apply-request", "status": "ready" if apply_requested else "blocked", "evidence": f"apply_requested={apply_requested}"},
    {"stage_id": "06-apply-admission", "status": "ready" if apply_admitted else "blocked", "evidence": f"apply_admitted={apply_admitted}; message={apply_message}"},
    {"stage_id": "07-checkpoint-env-ready", "status": "ready" if checkpoint_env_ready_after else "blocked", "evidence": f"checkpoint_env_ready_after={checkpoint_env_ready_after}"},
    {"stage_id": "08-real-review-return", "status": "blocked", "evidence": "checkpoint root is not human review evidence"},
    {"stage_id": "09-actual-generation", "status": "blocked", "evidence": "checkpoint root env alone is not generation execution or result acceptance"},
]
write_csv(run_dir / "first_real_slice_checkpoint_root_env_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {"command_id": "01-verify-audit", "ready_to_run_now": "1", "command": "results/v61hb_post_ha_first_real_slice_checkpoint_root_env_audit/checkpoint_env_audit_001/first_real_slice_checkpoint_root_env_audit/VERIFY_FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_AUDIT.sh", "purpose": "verify metadata-only checkpoint root env audit package"},
    {"command_id": "02-apply-checkpoint-root-env", "ready_to_run_now": str(int(checkpoint_root_valid and work_root_exists and work_root_outside_repo)), "command": "V61HB_APPLY_CHECKPOINT_ROOT=1 V61HB_WORK_ROOT=<work-root> V61HB_CHECKPOINT_ROOT=<checkpoint-root> experiments/run_v61hb_post_ha_first_real_slice_checkpoint_root_env_audit.sh", "purpose": "replace only V61GI_CHECKPOINT_ROOT placeholder after 59-shard validation"},
    {"command_id": "03-rerun-workspace-gap-audit", "ready_to_run_now": str(int(work_root_exists)), "command": "V61GV_WORK_ROOT=<work-root> experiments/run_v61gv_post_gu_first_real_slice_workspace_gap_audit.sh", "purpose": "confirm env gap delta without executing replay"},
]
write_csv(run_dir / "first_real_slice_checkpoint_root_env_command_rows.csv", list(command_rows[0].keys()), command_rows)

for rel, src in [
    ("FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_CANDIDATE_ROWS.csv", run_dir / "first_real_slice_checkpoint_root_env_candidate_rows.csv"),
    ("FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_APPLY_ROWS.csv", run_dir / "first_real_slice_checkpoint_root_env_apply_rows.csv"),
    ("FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_STAGE_ROWS.csv", run_dir / "first_real_slice_checkpoint_root_env_stage_rows.csv"),
    ("FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_COMMAND_ROWS.csv", run_dir / "first_real_slice_checkpoint_root_env_command_rows.csv"),
]:
    shutil.copy2(src, package_dir / rel)

(package_dir / "VERIFY_FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_AUDIT.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_MANIFEST.json\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_CANDIDATE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_APPLY_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_STAGE_ROWS.csv\"",
        "test -s \"$DIR/FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_COMMAND_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61hb package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_AUDIT.sh").chmod(0o755)

summary = {
    "v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_ready": 1,
    "v61ha_post_gz_first_real_slice_source_witness_promotion_audit_ready": 1,
    "work_root_supplied": work_root_supplied,
    "work_root_exists": work_root_exists,
    "work_root_outside_repo": work_root_outside_repo,
    "env_template_exists": env_template_exists,
    "checkpoint_root_supplied": checkpoint_root_supplied,
    "checkpoint_root_exists": checkpoint_root_exists,
    "checkpoint_root_outside_repo": checkpoint_root_outside_repo,
    "expected_checkpoint_shard_rows": EXPECTED_SHARDS,
    "observed_checkpoint_safetensor_rows": 0 if shard_rows[0]["shard_file"] == "none" else len(shard_rows),
    "checkpoint_root_valid": checkpoint_root_valid,
    "checkpoint_total_bytes_observed": total_checkpoint_bytes,
    "checkpoint_shard_hash_mode": hash_checkpoint_shards,
    "checkpoint_env_present_before": checkpoint_env_present_before,
    "checkpoint_env_was_placeholder": checkpoint_env_was_placeholder,
    "checkpoint_env_already_set_before": checkpoint_env_already_set_before,
    "checkpoint_env_apply_requested": apply_requested,
    "checkpoint_env_apply_admitted": apply_admitted,
    "checkpoint_env_applied": applied,
    "checkpoint_env_ready_after_audit": checkpoint_env_ready_after,
    "ready_value_env_rows_after_audit": ready_value_env_rows_after,
    "env_value_gap_rows_after_audit": env_value_gap_rows_after,
    "real_external_review_return_rows": 0,
    "real_adjudication_rows": 0,
    "slice_answer_review_accepted_rows": 0,
    "real_generation_result_artifacts": 0,
    "accepted_generation_result_artifacts": 0,
    "generation_result_accepted_rows": 0,
    "row_acceptance_ready": 0,
    "dual_external_return_real_ready": 0,
    "real_return_replay_admission_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "authority_bound_replay_admission_ready": 0,
    "actual_model_generation_ready": 0,
    "production_latency_claim_ready": 0,
    "near_frontier_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61hb": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "source_file_rows": len(source_rows),
    "payload_like_package_file_rows": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61ha-ready", "status": "pass", "evidence": "v61ha ready"},
    {"gate": "work-root", "status": "pass" if work_root_exists and work_root_outside_repo else "blocked", "evidence": f"exists={work_root_exists}; outside_repo={work_root_outside_repo}"},
    {"gate": "env-template", "status": "pass" if env_template_exists else "blocked", "evidence": f"env_template_exists={env_template_exists}"},
    {"gate": "checkpoint-root", "status": "pass" if checkpoint_root_valid and checkpoint_root_outside_repo else "blocked", "evidence": f"checkpoint_root_valid={checkpoint_root_valid}; observed_safetensor_rows={summary['observed_checkpoint_safetensor_rows']}"},
    {"gate": "checkpoint-env-apply", "status": "pass" if apply_admitted else "blocked", "evidence": f"apply_requested={apply_requested}; apply_admitted={apply_admitted}; message={apply_message}"},
    {"gate": "checkpoint-env-ready", "status": "pass" if checkpoint_env_ready_after else "blocked", "evidence": f"checkpoint_env_ready_after={checkpoint_env_ready_after}"},
    {"gate": "real-review-return", "status": "blocked", "evidence": "checkpoint root is not human review evidence"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_root": str(checkpoint_root) if checkpoint_root else "",
    "work_root": str(work_root) if work_root else "",
    "checkpoint_payload_bytes_downloaded_by_v61hb": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(run_dir / "V61HB_POST_HA_FIRST_REAL_SLICE_CHECKPOINT_ROOT_ENV_AUDIT_BOUNDARY.md").write_text(
    "\n".join([
        "# V61HB Post-HA First Real Slice Checkpoint Root Env Audit",
        "",
        "- v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_ready=1",
        f"- checkpoint_root_valid={checkpoint_root_valid}",
        f"- checkpoint_env_ready_after_audit={checkpoint_env_ready_after}",
        f"- ready_value_env_rows_after_audit={ready_value_env_rows_after}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- row_acceptance_ready=0",
        "- dual_external_return_real_ready=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
        "Blocked wording: this validates and optionally sets the checkpoint root env value only. It does not accept review rows, generation result artifacts, or latency claims.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": "1",
        "payload_like": "0",
    })
write_csv(run_dir / "first_real_slice_checkpoint_root_env_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61hb_post_ha_first_real_slice_checkpoint_root_env_audit_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
