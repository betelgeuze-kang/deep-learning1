#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53y_complete_source_review_return_refresh_gate"
RUN_ID="${V53Y_RUN_ID:-refresh_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_DIR="${V53Y_REVIEW_RETURN_DIR:-}"

if [[ "${V53Y_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53y_complete_source_review_return_refresh_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ -n "$RETURN_DIR" ]]; then
  V53S_REVIEW_RETURN_DIR="$RETURN_DIR" V53S_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null
else
  V53S_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null
fi
V53T_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null
V53U_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53u_complete_source_review_return_operator_bundle.sh" >/dev/null
V53V_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53v_complete_source_review_return_acceptance_bridge.sh" >/dev/null
V53W_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53w_complete_source_review_return_chunk_execution_queue.sh" >/dev/null
if [[ -n "$RETURN_DIR" ]]; then
  V53X_REVIEW_CHUNK_RETURN_DIR="$RETURN_DIR" V53X_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53x_complete_source_review_chunk_return_intake.sh" >/dev/null
else
  V53X_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53x_complete_source_review_chunk_return_intake.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
return_dir_arg = sys.argv[5]
return_dir = Path(return_dir_arg).expanduser().resolve() if return_dir_arg else None
results = root / "results"
operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def status(flag):
    return "pass" if flag else "blocked"


summary_paths = {
    "v53s": results / "v53s_complete_source_review_return_intake_summary.csv",
    "v53t": results / "v53t_complete_source_audit_readiness_gate_summary.csv",
    "v53u": results / "v53u_complete_source_review_return_operator_bundle_summary.csv",
    "v53v": results / "v53v_complete_source_review_return_acceptance_bridge_summary.csv",
    "v53w": results / "v53w_complete_source_review_return_chunk_execution_queue_summary.csv",
    "v53x": results / "v53x_complete_source_review_chunk_return_intake_summary.csv",
}
decision_paths = {
    "v53s": results / "v53s_complete_source_review_return_intake_decision.csv",
    "v53t": results / "v53t_complete_source_audit_readiness_gate_decision.csv",
    "v53v": results / "v53v_complete_source_review_return_acceptance_bridge_decision.csv",
    "v53w": results / "v53w_complete_source_review_return_chunk_execution_queue_decision.csv",
    "v53x": results / "v53x_complete_source_review_chunk_return_intake_decision.csv",
}
summaries = {name: read_csv(path)[0] for name, path in summary_paths.items()}
for name, field in [
    ("v53s", "v53s_complete_source_review_return_intake_ready"),
    ("v53t", "v53t_complete_source_audit_readiness_gate_ready"),
    ("v53u", "v53u_complete_source_review_return_operator_bundle_ready"),
    ("v53v", "v53v_complete_source_review_return_acceptance_bridge_ready"),
    ("v53w", "v53w_complete_source_review_return_chunk_execution_queue_ready"),
    ("v53x", "v53x_complete_source_review_chunk_return_intake_ready"),
]:
    if summaries[name].get(field) != "1":
        raise SystemExit(f"v53y requires {field}=1")

for name, path in summary_paths.items():
    copy(path, f"source_{name}/{path.name}")
for name, path in decision_paths.items():
    copy(path, f"source_{name}/{path.name}")

source_files = [
    ("v53s_complete_source_review_return_intake/intake_001/review_return_metric_rows.csv", "source_v53s/review_return_metric_rows.csv"),
    ("v53s_complete_source_review_return_intake/intake_001/review_return_artifact_gate_rows.csv", "source_v53s/review_return_artifact_gate_rows.csv"),
    ("v53t_complete_source_audit_readiness_gate/gate_001/complete_source_audit_readiness_requirement_rows.csv", "source_v53t/complete_source_audit_readiness_requirement_rows.csv"),
    ("v53v_complete_source_review_return_acceptance_bridge/bridge_001/complete_source_review_return_acceptance_metric_rows.csv", "source_v53v/complete_source_review_return_acceptance_metric_rows.csv"),
    ("v53v_complete_source_review_return_acceptance_bridge/bridge_001/runtime_gap_rows.csv", "source_v53v/runtime_gap_rows.csv"),
    ("v53w_complete_source_review_return_chunk_execution_queue/queue_001/review_return_chunk_command_rows.csv", "source_v53w/review_return_chunk_command_rows.csv"),
    ("v53x_complete_source_review_chunk_return_intake/intake_001/review_return_chunk_artifact_status_rows.csv", "source_v53x/review_return_chunk_artifact_status_rows.csv"),
    ("v53x_complete_source_review_chunk_return_intake/intake_001/review_return_aggregate_artifact_status_rows.csv", "source_v53x/review_return_aggregate_artifact_status_rows.csv"),
    ("v53x_complete_source_review_chunk_return_intake/intake_001/runtime_gap_rows.csv", "source_v53x/runtime_gap_rows.csv"),
]
for src_rel, dst_rel in source_files:
    copy(results / src_rel, dst_rel)

v53s = summaries["v53s"]
v53t = summaries["v53t"]
v53v = summaries["v53v"]
v53w = summaries["v53w"]
v53x = summaries["v53x"]

return_dir_supplied = int(return_dir is not None)
return_dir_exists = int(return_dir is not None and return_dir.is_dir())
machine_surface_ready = as_int(v53t, "machine_complete_source_surface_ready")
chunk_return_ready = as_int(v53x, "chunk_return_intake_ready")
aggregate_return_ready = as_int(v53x, "aggregate_review_return_ready")
v53s_refresh_ready = as_int(v53x, "v53s_refresh_ready")
review_return_ready = as_int(v53s, "review_return_ready")
answer_review_accepted = as_int(v53v, "answer_review_accepted_rows")
expected_human = as_int(v53s, "expected_human_review_rows")
expected_adjudication = as_int(v53s, "expected_adjudication_rows")
review_acceptance_ready = int(answer_review_accepted == expected_human and review_return_ready)
v53_audit_ready = as_int(v53t, "v53_ready")
v1_ready = as_int(v53v, "v1_0_comparison_ready")
v61_review_unblock_ready = int(review_acceptance_ready and answer_review_accepted == expected_human)

stage_rows = [
    {
        "refresh_stage_id": "machine-complete-source-surface",
        "stage_order": "1",
        "source_gate": "v53t",
        "stage_status": "ready" if machine_surface_ready else "blocked",
        "expected_return": "machine_complete_source_surface_ready=1",
        "actual_return": f"machine_complete_source_surface_ready={machine_surface_ready}",
        "blocking_reason": "ready" if machine_surface_ready else "machine surface incomplete",
    },
    {
        "refresh_stage_id": "chunk-return-intake",
        "stage_order": "2",
        "source_gate": "v53x",
        "stage_status": "ready" if chunk_return_ready else "blocked",
        "expected_return": "50/50 chunk artifacts accepted",
        "actual_return": f"accepted_chunk_return_artifact_rows={v53x['accepted_chunk_return_artifact_rows']}/{v53x['review_chunk_return_artifact_rows']}",
        "blocking_reason": "ready" if chunk_return_ready else "review chunk return artifacts missing or invalid",
    },
    {
        "refresh_stage_id": "aggregate-review-return-intake",
        "stage_order": "3",
        "source_gate": "v53s",
        "stage_status": "ready" if review_return_ready and aggregate_return_ready else "blocked",
        "expected_return": "v53s review_return_ready=1",
        "actual_return": f"review_return_ready={review_return_ready}; aggregate_review_return_ready={aggregate_return_ready}",
        "blocking_reason": "ready" if review_return_ready and aggregate_return_ready else "aggregate review return artifacts not accepted by v53s",
    },
    {
        "refresh_stage_id": "per-answer-review-acceptance",
        "stage_order": "4",
        "source_gate": "v53v",
        "stage_status": "ready" if review_acceptance_ready else "blocked",
        "expected_return": f"answer_review_accepted_rows={expected_human}",
        "actual_return": f"answer_review_accepted_rows={answer_review_accepted}",
        "blocking_reason": "ready" if review_acceptance_ready else "per-answer review acceptance incomplete",
    },
    {
        "refresh_stage_id": "v53-audit-readiness",
        "stage_order": "5",
        "source_gate": "v53t/v53v",
        "stage_status": "ready" if v53_audit_ready else "blocked",
        "expected_return": "v53_ready=1",
        "actual_return": f"v53_ready={v53_audit_ready}; quality_comparison_claim_ready={v53s['quality_comparison_claim_ready']}",
        "blocking_reason": "ready" if v53_audit_ready else "quality comparison/release claims remain blocked after review-return mechanics",
    },
]
write_csv(run_dir / "complete_source_review_return_refresh_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

ready_stage_rows = sum(1 for row in stage_rows if row["stage_status"] == "ready")
blocked_stage_rows = len(stage_rows) - ready_stage_rows

command_rows = [
    {
        "command_id": "verify-v53y-refresh-gate",
        "command": "results/v53y_complete_source_review_return_refresh_gate/refresh_001/operator_bundle/VERIFY_REVIEW_RETURN_REFRESH.sh",
        "ready_to_run_now": "1",
        "expected_return": "v53y refresh gate shape is valid",
    },
    {
        "command_id": "rerun-v53y-with-review-return-dir",
        "command": "V53Y_REVIEW_RETURN_DIR=/path/to/v53_review_return V53Y_REUSE_EXISTING=0 ./experiments/run_v53y_complete_source_review_return_refresh_gate.sh",
        "ready_to_run_now": str(int(return_dir_exists)),
        "expected_return": "chunk/aggregate review return refresh summaries update from supplied directory",
    },
    {
        "command_id": "refresh-v61-generation-admission-after-review",
        "command": "V61CX_REUSE_EXISTING=0 ./experiments/test_v61cx_post_full_shard_actual_generation_closure_queue.sh",
        "ready_to_run_now": str(v61_review_unblock_ready),
        "expected_return": "v61 review-return blocker clears after accepted v53 review return",
    },
]
write_csv(run_dir / "complete_source_review_return_refresh_command_rows.csv", list(command_rows[0].keys()), command_rows)
ready_command_rows = sum(1 for row in command_rows if row["ready_to_run_now"] == "1")

requirement_rows = [
    {"requirement_id": "return-directory-supplied", "status": status(return_dir_exists), "required_value": "existing review return directory", "actual_value": str(return_dir) if return_dir else "", "reason": "real review returns must be supplied outside the repo"},
    {"requirement_id": "v53x-chunk-intake", "status": status(chunk_return_ready), "required_value": "50 accepted chunk artifacts", "actual_value": f"{v53x['accepted_chunk_return_artifact_rows']}/{v53x['review_chunk_return_artifact_rows']}", "reason": "all chunk-level review returns must pass v53x"},
    {"requirement_id": "v53s-aggregate-intake", "status": status(review_return_ready), "required_value": "review_return_ready=1", "actual_value": str(review_return_ready), "reason": "aggregate review return artifacts must pass v53s"},
    {"requirement_id": "v53v-per-answer-acceptance", "status": status(review_acceptance_ready), "required_value": str(expected_human), "actual_value": str(answer_review_accepted), "reason": "all 7000 answer review rows must be accepted"},
    {"requirement_id": "v61-review-unblock", "status": status(v61_review_unblock_ready), "required_value": "1", "actual_value": str(v61_review_unblock_ready), "reason": "v61 generation admission can clear the review blocker only after v53 review acceptance"},
    {"requirement_id": "v53-ready", "status": status(v53_audit_ready), "required_value": "1", "actual_value": str(v53_audit_ready), "reason": "v53 readiness still requires post-review quality comparison readiness"},
]
write_csv(run_dir / "complete_source_review_return_refresh_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "review-return-directory", "status": "ready" if return_dir_exists else "blocked", "reason": f"return_dir_supplied={return_dir_supplied}; return_dir_exists={return_dir_exists}"},
    {"gap": "chunk-return-intake", "status": "ready" if chunk_return_ready else "blocked", "reason": f"accepted_chunk_return_artifact_rows={v53x['accepted_chunk_return_artifact_rows']}/{v53x['review_chunk_return_artifact_rows']}"},
    {"gap": "aggregate-review-return-intake", "status": "ready" if review_return_ready else "blocked", "reason": f"review_return_ready={review_return_ready}"},
    {"gap": "per-answer-review-acceptance", "status": "ready" if review_acceptance_ready else "blocked", "reason": f"answer_review_accepted_rows={answer_review_accepted}/{expected_human}"},
    {"gap": "v61-review-unblock", "status": "ready" if v61_review_unblock_ready else "blocked", "reason": f"v61_review_unblock_ready={v61_review_unblock_ready}"},
    {"gap": "v53-ready", "status": "ready" if v53_audit_ready else "blocked", "reason": f"v53_ready={v53_audit_ready}; quality_comparison_claim_ready={v53s['quality_comparison_claim_ready']}"},
    {"gap": "v1.0-comparison-ready", "status": "ready" if v1_ready else "blocked", "reason": f"v1_0_comparison_ready={v1_ready}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53y_complete_source_review_return_refresh_gate_metrics",
    "return_dir_supplied": str(return_dir_supplied),
    "return_dir_exists": str(return_dir_exists),
    "v53x_complete_source_review_chunk_return_intake_ready": v53x["v53x_complete_source_review_chunk_return_intake_ready"],
    "v53s_complete_source_review_return_intake_ready": v53s["v53s_complete_source_review_return_intake_ready"],
    "v53v_complete_source_review_return_acceptance_bridge_ready": v53v["v53v_complete_source_review_return_acceptance_bridge_ready"],
    "v53t_complete_source_audit_readiness_gate_ready": v53t["v53t_complete_source_audit_readiness_gate_ready"],
    "machine_complete_source_surface_ready": str(machine_surface_ready),
    "refresh_stage_rows": str(len(stage_rows)),
    "ready_refresh_stage_rows": str(ready_stage_rows),
    "blocked_refresh_stage_rows": str(blocked_stage_rows),
    "refresh_command_rows": str(len(command_rows)),
    "ready_refresh_command_rows": str(ready_command_rows),
    "review_chunk_rows": v53x["review_chunk_rows"],
    "review_chunk_return_artifact_rows": v53x["review_chunk_return_artifact_rows"],
    "accepted_chunk_return_artifact_rows": v53x["accepted_chunk_return_artifact_rows"],
    "aggregate_review_return_artifact_rows": v53x["aggregate_review_return_artifact_rows"],
    "accepted_aggregate_review_return_artifact_rows": v53x["accepted_aggregate_review_return_artifact_rows"],
    "v53s_refresh_ready": str(v53s_refresh_ready),
    "expected_human_review_rows": str(expected_human),
    "accepted_human_review_rows": v53s["accepted_human_review_rows"],
    "expected_adjudication_rows": str(expected_adjudication),
    "accepted_adjudication_rows": v53s["accepted_adjudication_rows"],
    "expected_reviewer_identity_rows": v53s["expected_reviewer_identity_rows"],
    "accepted_reviewer_identity_rows": v53s["accepted_reviewer_identity_rows"],
    "expected_conflict_disclosure_rows": v53s["expected_conflict_disclosure_rows"],
    "accepted_conflict_disclosure_rows": v53s["accepted_conflict_disclosure_rows"],
    "acceptance_summary_ready": v53s["acceptance_summary_ready"],
    "review_return_ready": str(review_return_ready),
    "review_return_acceptance_rows": v53v["review_return_acceptance_rows"],
    "answer_review_accepted_rows": str(answer_review_accepted),
    "human_review_blocked_acceptance_rows": v53v["human_review_blocked_acceptance_rows"],
    "adjudication_blocked_acceptance_rows": v53v["adjudication_blocked_acceptance_rows"],
    "v61_review_unblock_ready": str(v61_review_unblock_ready),
    "quality_comparison_claim_ready": v53s["quality_comparison_claim_ready"],
    "v53_ready": str(v53_audit_ready),
    "v1_0_comparison_ready": str(v1_ready),
    "real_release_package_ready": v53v["real_release_package_ready"],
    "route_jump_rows": "0",
}
write_csv(run_dir / "complete_source_review_return_refresh_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53y_complete_source_review_return_refresh_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "machine-complete-source-surface", "status": status(machine_surface_ready), "reason": f"machine_complete_source_surface_ready={machine_surface_ready}"},
    {"gate": "return-directory-supplied", "status": status(return_dir_exists), "reason": f"return_dir_exists={return_dir_exists}"},
    {"gate": "chunk-return-intake", "status": status(chunk_return_ready), "reason": f"accepted_chunk_return_artifact_rows={v53x['accepted_chunk_return_artifact_rows']}/{v53x['review_chunk_return_artifact_rows']}"},
    {"gate": "aggregate-review-return-intake", "status": status(review_return_ready), "reason": f"review_return_ready={review_return_ready}"},
    {"gate": "per-answer-review-acceptance", "status": status(review_acceptance_ready), "reason": f"answer_review_accepted_rows={answer_review_accepted}/{expected_human}"},
    {"gate": "v61-review-unblock", "status": status(v61_review_unblock_ready), "reason": f"v61_review_unblock_ready={v61_review_unblock_ready}"},
    {"gate": "v53-ready", "status": status(v53_audit_ready), "reason": f"v53_ready={v53_audit_ready}"},
    {"gate": "v1.0-comparison-ready", "status": status(v1_ready), "reason": f"v1_0_comparison_ready={v1_ready}"},
    {"gate": "real-release-package", "status": status(as_int(v53v, "real_release_package_ready")), "reason": f"real_release_package_ready={v53v['real_release_package_ready']}"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

(operator_dir / "README.md").write_text(
    "# v53y Review Return Refresh Gate\n\n"
    "Run this gate with `V53Y_REVIEW_RETURN_DIR=/path/to/v53_review_return` "
    "after external reviewers provide the chunk and aggregate return artifacts. "
    "The gate refreshes v53s/v53t/v53v/v53w/v53x and reports whether review "
    "return acceptance can unblock v61 generation admission.\n",
    encoding="utf-8",
)
verify_script = operator_dir / "VERIFY_REVIEW_RETURN_REFRESH.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_files=(
  "$BUNDLE_DIR/complete_source_review_return_refresh_stage_rows.csv"
  "$BUNDLE_DIR/complete_source_review_return_refresh_command_rows.csv"
  "$BUNDLE_DIR/complete_source_review_return_refresh_requirement_rows.csv"
  "$BUNDLE_DIR/complete_source_review_return_refresh_metric_rows.csv"
  "$BUNDLE_DIR/runtime_gap_rows.csv"
  "$BUNDLE_DIR/source_v53x/review_return_chunk_artifact_status_rows.csv"
  "$BUNDLE_DIR/source_v53s/review_return_metric_rows.csv"
  "$BUNDLE_DIR/source_v53v/complete_source_review_return_acceptance_metric_rows.csv"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v53y refresh file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$BUNDLE_DIR/complete_source_review_return_refresh_stage_rows.csv" | tr -d ' ')" == "6" ]] || { echo "expected five refresh stage rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/complete_source_review_return_refresh_command_rows.csv" | tr -d ' ')" == "4" ]] || { echo "expected three refresh command rows" >&2; exit 1; }

if find "$BUNDLE_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v53y bundle" >&2
  exit 1
fi

echo "v53y review return refresh gate shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

boundary = f"""# v53y Complete Source Review Return Refresh Gate Boundary

This artifact refreshes the v53 review-return chain after an optional external
return directory is supplied. It does not fabricate human/source review rows and
does not turn machine-prepared review packets into v1.0 comparison evidence.

Evidence emitted:

- return_dir_supplied={return_dir_supplied}
- return_dir_exists={return_dir_exists}
- machine_complete_source_surface_ready={machine_surface_ready}
- refresh_stage_rows={len(stage_rows)}
- ready_refresh_stage_rows={ready_stage_rows}
- blocked_refresh_stage_rows={blocked_stage_rows}
- review_chunk_rows={v53x['review_chunk_rows']}
- review_chunk_return_artifact_rows={v53x['review_chunk_return_artifact_rows']}
- accepted_chunk_return_artifact_rows={v53x['accepted_chunk_return_artifact_rows']}
- aggregate_review_return_artifact_rows={v53x['aggregate_review_return_artifact_rows']}
- accepted_aggregate_review_return_artifact_rows={v53x['accepted_aggregate_review_return_artifact_rows']}
- v53s_refresh_ready={v53s_refresh_ready}
- expected_human_review_rows={expected_human}
- accepted_human_review_rows={v53s['accepted_human_review_rows']}
- expected_adjudication_rows={expected_adjudication}
- accepted_adjudication_rows={v53s['accepted_adjudication_rows']}
- review_return_ready={review_return_ready}
- answer_review_accepted_rows={answer_review_accepted}
- v61_review_unblock_ready={v61_review_unblock_ready}
- quality_comparison_claim_ready={v53s['quality_comparison_claim_ready']}
- v53_ready={v53_audit_ready}
- v1_0_comparison_ready={v1_ready}

Allowed wording: complete-source review-return refresh gate is ready and reports
the exact remaining review-return blockers.

Blocked wording: accepted human-reviewed complete-source audit, v53 readiness,
v1.0 comparison readiness, v61 actual generation unblock, quality comparison
claim, or release readiness unless the corresponding accepted rows are present.
"""
(run_dir / "V53Y_COMPLETE_SOURCE_REVIEW_RETURN_REFRESH_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53y-complete-source-review-return-refresh-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53y_complete_source_review_return_refresh_gate_ready": 1,
    "return_dir_supplied": return_dir_supplied,
    "return_dir_exists": return_dir_exists,
    "machine_complete_source_surface_ready": machine_surface_ready,
    "refresh_stage_rows": len(stage_rows),
    "ready_refresh_stage_rows": ready_stage_rows,
    "blocked_refresh_stage_rows": blocked_stage_rows,
    "accepted_chunk_return_artifact_rows": as_int(v53x, "accepted_chunk_return_artifact_rows"),
    "accepted_aggregate_review_return_artifact_rows": as_int(v53x, "accepted_aggregate_review_return_artifact_rows"),
    "review_return_ready": review_return_ready,
    "answer_review_accepted_rows": answer_review_accepted,
    "v61_review_unblock_ready": v61_review_unblock_ready,
    "quality_comparison_claim_ready": as_int(v53s, "quality_comparison_claim_ready"),
    "v53_ready": v53_audit_ready,
    "v1_0_comparison_ready": v1_ready,
    "real_release_package_ready": as_int(v53v, "real_release_package_ready"),
    "source_v53x_summary_sha256": sha256(summary_paths["v53x"]),
    "source_v53s_summary_sha256": sha256(summary_paths["v53s"]),
    "source_v53v_summary_sha256": sha256(summary_paths["v53v"]),
    "source_v53t_summary_sha256": sha256(summary_paths["v53t"]),
}
(run_dir / "v53y_complete_source_review_return_refresh_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53y_complete_source_review_return_refresh_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
