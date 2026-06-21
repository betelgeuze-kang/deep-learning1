#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
MOE_ROWS="$RESULTS_DIR/v61_moe_block_forward_parity/moe_block_forward_parity_rows.csv"
LOGITS_ROWS="$RESULTS_DIR/v61_one_token_logits_parity/one_token_logits_parity_rows.csv"
DECODE_ROWS="$RESULTS_DIR/v61_sixteen_token_decode/sixteen_token_decode_rows.csv"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61-one-token-contract.XXXXXX")"
BAD_OUTPUT="$TMP_DIR/expect_fail.out"
cd "$ROOT_DIR"

cleanup() {
  if [ -n "${REMOTE_BINDING_ROWS:-}" ] && [ -n "${REMOTE_BINDING_BACKUP:-}" ] && [ -f "$REMOTE_BINDING_BACKUP" ]; then
    cp "$REMOTE_BINDING_BACKUP" "$REMOTE_BINDING_ROWS" 2>/dev/null || true
  fi
  if [ -n "${TORCH_PARITY_ROWS:-}" ] && [ -n "${TORCH_PARITY_BACKUP:-}" ] && [ -f "$TORCH_PARITY_BACKUP" ]; then
    cp "$TORCH_PARITY_BACKUP" "$TORCH_PARITY_ROWS" 2>/dev/null || true
  fi
  if [ -n "${V61AB_METRIC_ROWS:-}" ] && [ -n "${V61AB_METRIC_BACKUP:-}" ] && [ -f "$V61AB_METRIC_BACKUP" ]; then
    cp "$V61AB_METRIC_BACKUP" "$V61AB_METRIC_ROWS" 2>/dev/null || true
  fi
  if [ -n "${V61AA_METRIC_ROWS:-}" ] && [ -n "${V61AA_METRIC_BACKUP:-}" ] && [ -f "$V61AA_METRIC_BACKUP" ]; then
    cp "$V61AA_METRIC_BACKUP" "$V61AA_METRIC_ROWS" 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

expect_fail_with() {
  local expected="$1"
  shift
  if "$@" >"$BAD_OUTPUT" 2>&1; then
    echo "v61 one-token negative control unexpectedly passed: $*" >&2
    cat "$BAD_OUTPUT" >&2
    exit 1
  fi
  if ! grep -F "$expected" "$BAD_OUTPUT" >/dev/null; then
    echo "v61 one-token verifier failed, but not for the expected guard" >&2
    echo "expected diagnostic: $expected" >&2
    cat "$BAD_OUTPUT" >&2
    exit 1
  fi
}

"$ROOT_DIR/experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh" >/dev/null

REMOTE_BINDING_ROWS="$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier/verify_001/source_v61v/remote_sample_tensor_binding_rows.csv"
REMOTE_BINDING_BACKUP="$TMP_DIR/remote_sample_tensor_binding_rows.csv.bak"
cp "$REMOTE_BINDING_ROWS" "$REMOTE_BINDING_BACKUP"
python3 - "$REMOTE_BINDING_ROWS" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["model_id"] = "fixture/not-mixtral"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "model_id expected mistralai/Mixtral-8x22B-v0.1, got fixture/not-mixtral" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"
cp "$REMOTE_BINDING_BACKUP" "$REMOTE_BINDING_ROWS"

python3 - "$REMOTE_BINDING_ROWS" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["remote_page_sha256"] = "sha256:" + "z" * 64
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "remote_hash_bound=1 requires remote_page_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"
cp "$REMOTE_BINDING_BACKUP" "$REMOTE_BINDING_ROWS"

TORCH_PARITY_ROWS="$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe/probe_001/hotset_tensor_tile_torch_parity_rows.csv"
TORCH_PARITY_BACKUP="$TMP_DIR/hotset_tensor_tile_torch_parity_rows.csv.bak"
cp "$TORCH_PARITY_ROWS" "$TORCH_PARITY_BACKUP"
python3 - "$TORCH_PARITY_ROWS" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["model_id"] = "fixture/not-mixtral"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "model_id expected mistralai/Mixtral-8x22B-v0.1, got fixture/not-mixtral" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"
cp "$TORCH_PARITY_BACKUP" "$TORCH_PARITY_ROWS"

python3 - "$TORCH_PARITY_ROWS" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["torch_abs_delta"] = "999"
rows[0]["torch_tolerance"] = "1e-06"
rows[0]["torch_matvec_parity_pass"] = "1"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "torch_matvec_parity_pass=1 requires torch_abs_delta <= torch_tolerance" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"
cp "$TORCH_PARITY_BACKUP" "$TORCH_PARITY_ROWS"

V61AB_METRIC_ROWS="$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe/probe_001/hotset_tensor_tile_quant_metric_rows.csv"
V61AB_METRIC_BACKUP="$TMP_DIR/hotset_tensor_tile_quant_metric_rows.csv.bak"
cp "$V61AB_METRIC_ROWS" "$V61AB_METRIC_BACKUP"
python3 - "$V61AB_METRIC_ROWS" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["tensor_tile_probe_rows"] = "0"
rows[0]["tile_bf16_value_rows"] = "0"
rows[0]["hotset_numeric_tile_probe_ready"] = "1"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "tensor_tile_probe_rows expected 128, got 0" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"
cp "$V61AB_METRIC_BACKUP" "$V61AB_METRIC_ROWS"

V61AA_METRIC_ROWS="$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier/verify_001/hotset_tensor_slice_metric_rows.csv"
V61AA_METRIC_BACKUP="$TMP_DIR/hotset_tensor_slice_metric_rows.csv.bak"
cp "$V61AA_METRIC_ROWS" "$V61AA_METRIC_BACKUP"
python3 - "$V61AA_METRIC_ROWS" <<'PY'
import csv
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    rows = list(reader)
    fieldnames = reader.fieldnames or []
rows[0]["tensor_slice_rows"] = "0"
rows[0]["bf16_tensor_slice_stats_ready"] = "1"
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
expect_fail_with \
  "tensor_slice_rows expected 16, got 0" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"
cp "$V61AA_METRIC_BACKUP" "$V61AA_METRIC_ROWS"

bad_json() {
  local name="$1"
  shift
  local path="$TMP_DIR/$name.json"
  python3 - "$ROOT_DIR/v61/one_token_path.json" "$path" "$@" <<'PY'
import json
import sys

source, target, mutation = sys.argv[1:4]
with open(source, encoding="utf-8") as handle:
    data = json.load(handle)
if mutation == "blocked-count":
    data["policy"]["blocked_before_ssd_resident_runtime_claim_count"] = 2
elif mutation == "ssd-runtime-ready":
    data["policy"]["ssd_resident_real_model_runtime_claim_ready"] = True
elif mutation == "real-model-ready":
    data["policy"]["real_model_execution_ready"] = True
elif mutation == "expert-pass":
    for row in data["milestones"]:
        if row["milestone_id"] == "real-expert-ffn-forward-parity":
            row["current_status"] = "pass"
            row.pop("blocked_by", None)
            break
elif mutation == "blocked-list":
    data["policy"]["blocked_before_ssd_resident_runtime_claim"] = [
        "real-expert-ffn-forward-parity",
        "real-moe-block-forward-parity",
    ]
elif mutation == "logits-not-required":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "one-token-logits-parity-rows":
            row["required_for_runtime_claim"] = False
            break
elif mutation == "logits-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "one-token-logits-parity-rows":
            row["required_columns"] = [
                column
                for column in row["required_columns"]
                if column != "logits_parity_pass"
            ]
            break
elif mutation == "logits-mean-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "one-token-logits-parity-rows":
            row["required_columns"] = [
                column
                for column in row["required_columns"]
                if column != "mean_abs_delta"
            ]
            break
elif mutation == "logits-topk-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "one-token-logits-parity-rows":
            row["required_columns"] = [
                column
                for column in row["required_columns"]
                if column != "top_k_token_ranking_match"
            ]
            break
elif mutation == "logits-activation-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "one-token-logits-parity-rows":
            row["required_columns"] = [
                column
                for column in row["required_columns"]
                if column != "layer_activation_trace_sha256"
            ]
            break
elif mutation == "expert-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "expert-ffn-forward-parity-rows":
            row["required_columns"] = [
                column
                for column in row["required_columns"]
                if column != "expert_ffn_parity_pass"
            ]
            break
elif mutation == "expert-rmsnorm-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "expert-ffn-forward-parity-rows":
            row["required_columns"] = [
                column
                for column in row["required_columns"]
                if column != "rmsnorm_payload_sha256"
            ]
            break
elif mutation == "expert-pass-field":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "expert-ffn-forward-parity-rows":
            row["pass_field"] = "expert_ffn_ready"
            break
elif mutation == "missing-artifact-count":
    data["policy"]["missing_required_artifact_count"] = 4
elif mutation == "missing-decode-artifact":
    data["policy"]["missing_required_artifact_ids"] = [
        artifact_id
        for artifact_id in data["policy"]["missing_required_artifact_ids"]
        if artifact_id != "sixteen-token-decode-rows"
    ]
elif mutation == "decode-pass-field":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "sixteen-token-decode-rows":
            row["pass_field"] = "decode_ready"
            break
elif mutation == "cache-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "cold-warm-cache-measurement-rows":
            row["required_columns"] = [
                column
                for column in row["required_columns"]
                if column != "cache_state"
            ]
            break
elif mutation == "runtime-metric-column-drop":
    for row in data["required_artifacts"]:
        if row["artifact_id"] == "ssd-bytes-miss-tps-rows":
            row["required_columns"] = [
                column
                for column in row["required_columns"]
                if column != "bytes_per_token_cold"
            ]
            break
else:
    raise SystemExit(f"unknown mutation: {mutation}")
with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
  printf '%s\n' "$path"
}

bad_path="$(bad_json blocked_count_bad blocked-count)"
expect_fail_with \
  "blocked_before_ssd_resident_runtime_claim_count" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json ssd_runtime_ready_bad ssd-runtime-ready)"
expect_fail_with \
  "SSD-resident real model runtime claim must stay false until milestones 1-6 pass" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json real_model_ready_bad real-model-ready)"
expect_fail_with \
  "real_model_execution_ready must stay false until one-token evidence exists" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json expert_pass_bad expert-pass)"
expect_fail_with \
  "current_status expected blocked, got pass" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json blocked_list_bad blocked-list)"
expect_fail_with \
  "blocked_before_ssd_resident_runtime_claim must list the still-blocked milestones before runtime claim" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json logits_not_required_bad logits-not-required)"
expect_fail_with \
  "required_for_runtime_claim must be true" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json logits_column_drop_bad logits-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v61 artifact header order" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json expert_column_drop_bad expert-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v61 artifact header order" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json expert_rmsnorm_column_drop_bad expert-rmsnorm-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v61 artifact header order" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json logits_mean_column_drop_bad logits-mean-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v61 artifact header order" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json logits_topk_column_drop_bad logits-topk-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v61 artifact header order" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json logits_activation_column_drop_bad logits-activation-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v61 artifact header order" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json expert_pass_field_bad expert-pass-field)"
expect_fail_with \
  "pass_field expected expert_ffn_parity_pass, got expert_ffn_ready" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json missing_artifact_count_bad missing-artifact-count)"
expect_fail_with \
  "policy.missing_required_artifact_count expected 5, got 4" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json missing_decode_artifact_bad missing-decode-artifact)"
expect_fail_with \
  "policy.missing_required_artifact_ids expected" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json decode_pass_field_bad decode-pass-field)"
expect_fail_with \
  "pass_field expected decode_parity_pass, got decode_ready" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json cache_column_drop_bad cache-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v61 artifact header order" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

bad_path="$(bad_json runtime_metric_column_drop_bad runtime-metric-column-drop)"
expect_fail_with \
  "required_columns must exactly match the v61 artifact header order" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$bad_path" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

EXPERT_ROWS="$TMP_DIR/expert_ffn_forward_parity_rows.csv"
EXPERT_BAD_JSON="$TMP_DIR/expert_temp_path_bad.json"
python3 - "$ROOT_DIR/v61/one_token_path.json" "$EXPERT_BAD_JSON" "$EXPERT_ROWS" <<'PY'
import json
import sys
from pathlib import Path

source, target, expert_rows = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))
for row in data["required_artifacts"]:
    if row["artifact_id"] == "expert-ffn-forward-parity-rows":
        row["path"] = expert_rows
        break
Path(target).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
cat >"$EXPERT_ROWS" <<'CSV'
checkpoint_id,model_revision,config_sha256,tokenizer_revision,shard_index_sha256,full_manifest_sha256,layer_index,expert_index,token_id,router_top_k,rmsnorm_tensor_name,rmsnorm_payload_sha256,router_tensor_name,router_payload_sha256,w1_tensor_name,w2_tensor_name,w3_tensor_name,contract_ready,fixture_execution_ready,real_model_execution_ready,heldout_metric_ready,human_review_ready,independent_reproduction_ready,release_ready,local_checkpoint_root_supplied,checkpoint_payload_bytes_committed_to_repo,actual_model_generation_ready,route_jump_rows,status,reason,w1_shape,w2_shape,w3_shape,w1_payload_sha256,w2_payload_sha256,w3_payload_sha256,input_hidden_size,intermediate_size,output_hidden_size,residual_input_sha256,residual_output_sha256,transformers_capture_backend,transformers_capture_module_path,transformers_capture_artifact_sha256,transformers_expert_output_sha256,independent_runtime_output_sha256,candidate_output_sha256,torch_reference_output_sha256,max_abs_delta,tolerance,expert_ffn_parity_pass
fixture-checkpoint,fixture-revision,sha256:1212121212121212121212121212121212121212121212121212121212121212,fixture-tokenizer,sha256:3434343434343434343434343434343434343434343434343434343434343434,sha256:5656565656565656565656565656565656565656565656565656565656565656,0,0,1,2,model.layers.0.input_layernorm.weight,sha256:7777777777777777777777777777777777777777777777777777777777777777,model.layers.0.block_sparse_moe.gate.weight,sha256:8888888888888888888888888888888888888888888888888888888888888888,model.layers.0.block_sparse_moe.experts.0.w1.weight,model.layers.0.block_sparse_moe.experts.0.w2.weight,model.layers.0.block_sparse_moe.experts.0.w3.weight,1,0,1,0,0,0,0,1,0,0,0,blocked,malicious blocked expert FFN artifact claims real execution,"[14336,6144]","[6144,14336]","[14336,6144]",sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,6144,14336,6144,sha256:9999999999999999999999999999999999999999999999999999999999999999,sha256:abababababababababababababababababababababababababababababababab,transformers,model.layers.0.block_sparse_moe.experts.0,sha256:fafafafafafafafafafafafafafafafafafafafafafafafafafafafafafafafa,sha256:cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd,sha256:efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef,sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,sha256:cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd,0,1e-06,1
CSV
expect_fail_with \
  "blocked milestone real-expert-ffn-forward-parity cannot contain expert_ffn_parity_pass=1 rows" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$EXPERT_BAD_JSON" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

cat >"$EXPERT_ROWS" <<'CSV'
checkpoint_id,model_revision,config_sha256,tokenizer_revision,shard_index_sha256,full_manifest_sha256,layer_index,expert_index,token_id,router_top_k,rmsnorm_tensor_name,rmsnorm_payload_sha256,router_tensor_name,router_payload_sha256,w1_tensor_name,w2_tensor_name,w3_tensor_name,contract_ready,fixture_execution_ready,real_model_execution_ready,heldout_metric_ready,human_review_ready,independent_reproduction_ready,release_ready,local_checkpoint_root_supplied,checkpoint_payload_bytes_committed_to_repo,actual_model_generation_ready,route_jump_rows,status,reason,w1_shape,w2_shape,w3_shape,w1_payload_sha256,w2_payload_sha256,w3_payload_sha256,input_hidden_size,intermediate_size,output_hidden_size,residual_input_sha256,residual_output_sha256,transformers_capture_backend,transformers_capture_module_path,transformers_capture_artifact_sha256,transformers_expert_output_sha256,independent_runtime_output_sha256,candidate_output_sha256,torch_reference_output_sha256,max_abs_delta,tolerance,expert_ffn_parity_pass
fixture-checkpoint,fixture-revision,sha256:1212121212121212121212121212121212121212121212121212121212121212,fixture-tokenizer,sha256:3434343434343434343434343434343434343434343434343434343434343434,sha256:5656565656565656565656565656565656565656565656565656565656565656,0,0,1,2,model.layers.0.input_layernorm.weight,sha256:7777777777777777777777777777777777777777777777777777777777777777,model.layers.0.block_sparse_moe.gate.weight,sha256:8888888888888888888888888888888888888888888888888888888888888888,model.layers.0.block_sparse_moe.experts.0.w1.weight,model.layers.0.block_sparse_moe.experts.0.w2.weight,model.layers.0.block_sparse_moe.experts.0.w3.weight,1,0,1,0,0,0,0,1,0,0,0,blocked,malicious real expert FFN pass omits original Transformers output,"[14336,6144]","[6144,14336]","[14336,6144]",sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,6144,14336,6144,sha256:9999999999999999999999999999999999999999999999999999999999999999,sha256:abababababababababababababababababababababababababababababababab,transformers,model.layers.0.block_sparse_moe.experts.0,sha256:fafafafafafafafafafafafafafafafafafafafafafafafafafafafafafafa,,sha256:efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef,sha256:efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef,sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,0,1e-06,1
CSV
expect_fail_with \
  "real expert_ffn_parity_pass=1 requires transformers_expert_output_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$EXPERT_BAD_JSON" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

cat >"$EXPERT_ROWS" <<'CSV'
checkpoint_id,model_revision,config_sha256,tokenizer_revision,shard_index_sha256,full_manifest_sha256,layer_index,expert_index,token_id,router_top_k,rmsnorm_tensor_name,rmsnorm_payload_sha256,router_tensor_name,router_payload_sha256,w1_tensor_name,w2_tensor_name,w3_tensor_name,contract_ready,fixture_execution_ready,real_model_execution_ready,heldout_metric_ready,human_review_ready,independent_reproduction_ready,release_ready,local_checkpoint_root_supplied,checkpoint_payload_bytes_committed_to_repo,actual_model_generation_ready,route_jump_rows,status,reason,w1_shape,w2_shape,w3_shape,w1_payload_sha256,w2_payload_sha256,w3_payload_sha256,input_hidden_size,intermediate_size,output_hidden_size,residual_input_sha256,residual_output_sha256,transformers_capture_backend,transformers_capture_module_path,transformers_capture_artifact_sha256,transformers_expert_output_sha256,independent_runtime_output_sha256,candidate_output_sha256,torch_reference_output_sha256,max_abs_delta,tolerance,expert_ffn_parity_pass
fixture-checkpoint,fixture-revision,sha256:1212121212121212121212121212121212121212121212121212121212121212,fixture-tokenizer,sha256:3434343434343434343434343434343434343434343434343434343434343434,sha256:5656565656565656565656565656565656565656565656565656565656565656,0,0,1,2,model.layers.0.input_layernorm.weight,sha256:7777777777777777777777777777777777777777777777777777777777777777,model.layers.0.block_sparse_moe.gate.weight,sha256:8888888888888888888888888888888888888888888888888888888888888888,model.layers.0.block_sparse_moe.experts.0.w1.weight,model.layers.0.block_sparse_moe.experts.0.w2.weight,model.layers.0.block_sparse_moe.experts.0.w3.weight,1,0,1,0,0,0,0,1,0,0,0,blocked,malicious real expert FFN pass omits original Transformers capture artifact,"[14336,6144]","[6144,14336]","[14336,6144]",sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,6144,14336,6144,sha256:9999999999999999999999999999999999999999999999999999999999999999,sha256:abababababababababababababababababababababababababababababababab,transformers,model.layers.0.block_sparse_moe.experts.0,,sha256:cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd,sha256:efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef,sha256:efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef,sha256:cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd,0,1e-06,1
CSV
expect_fail_with \
  "real expert_ffn_parity_pass=1 requires transformers_capture_artifact_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$EXPERT_BAD_JSON" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

write_bad_expert_row() {
  local mode="$1"
  python3 - "$ROOT_DIR/v61/one_token_path.json" "$EXPERT_ROWS" "$mode" <<'PY'
import csv
import json
import sys
from pathlib import Path

contract_path, rows_path, mode = sys.argv[1:4]
data = json.loads(Path(contract_path).read_text(encoding="utf-8"))
columns = next(
    row["required_columns"]
    for row in data["required_artifacts"]
    if row["artifact_id"] == "expert-ffn-forward-parity-rows"
)
values = {column: "" for column in columns}
values.update({
    "checkpoint_id": "fixture-checkpoint",
    "model_revision": "fixture-revision",
    "config_sha256": "sha256:" + "1" * 64,
    "tokenizer_revision": "fixture-tokenizer",
    "shard_index_sha256": "sha256:" + "2" * 64,
    "full_manifest_sha256": "sha256:" + "3" * 64,
    "layer_index": "0",
    "expert_index": "0",
    "token_id": "1",
    "router_top_k": "2",
    "rmsnorm_tensor_name": "model.layers.0.input_layernorm.weight",
    "rmsnorm_payload_sha256": "sha256:" + "4" * 64,
    "router_tensor_name": "model.layers.0.block_sparse_moe.gate.weight",
    "router_payload_sha256": "sha256:" + "5" * 64,
    "w1_tensor_name": "model.layers.0.block_sparse_moe.experts.0.w1.weight",
    "w2_tensor_name": "model.layers.0.block_sparse_moe.experts.0.w2.weight",
    "w3_tensor_name": "model.layers.0.block_sparse_moe.experts.0.w3.weight",
    "contract_ready": "1",
    "fixture_execution_ready": "0",
    "real_model_execution_ready": "1",
    "heldout_metric_ready": "0",
    "human_review_ready": "0",
    "independent_reproduction_ready": "0",
    "release_ready": "0",
    "local_checkpoint_root_supplied": "1",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "route_jump_rows": "0",
    "status": "blocked",
    "reason": "malicious real expert FFN parity row",
    "w1_shape": "[14336,6144]",
    "w2_shape": "[6144,14336]",
    "w3_shape": "[14336,6144]",
    "w1_payload_sha256": "sha256:" + "6" * 64,
    "w2_payload_sha256": "sha256:" + "7" * 64,
    "w3_payload_sha256": "sha256:" + "8" * 64,
    "input_hidden_size": "6144",
    "intermediate_size": "14336",
    "output_hidden_size": "6144",
    "residual_input_sha256": "sha256:" + "9" * 64,
    "residual_output_sha256": "sha256:" + "a" * 64,
    "transformers_capture_backend": "transformers",
    "transformers_capture_module_path": "model.layers.0.block_sparse_moe.experts.0",
    "transformers_capture_artifact_sha256": "sha256:" + "b" * 64,
    "transformers_expert_output_sha256": "sha256:" + "c" * 64,
    "independent_runtime_output_sha256": "sha256:" + "d" * 64,
    "candidate_output_sha256": "sha256:" + "d" * 64,
    "torch_reference_output_sha256": "sha256:" + "c" * 64,
    "max_abs_delta": "0",
    "tolerance": "1e-06",
    "expert_ffn_parity_pass": "1",
})
if mode == "missing_backend":
    values["transformers_capture_backend"] = ""
elif mode == "missing_module_path":
    values["transformers_capture_module_path"] = ""
elif mode == "independent_mismatch":
    values["candidate_output_sha256"] = "sha256:" + "e" * 64
elif mode == "transformers_mismatch":
    values["torch_reference_output_sha256"] = "sha256:" + "f" * 64
else:
    raise SystemExit(f"unknown mode: {mode}")
path = Path(rows_path)
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=columns, lineterminator="\n")
    writer.writeheader()
    writer.writerow(values)
PY
}

write_bad_expert_row missing_backend
expect_fail_with \
  "real expert_ffn_parity_pass=1 requires transformers_capture_backend" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$EXPERT_BAD_JSON" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

write_bad_expert_row missing_module_path
expect_fail_with \
  "real expert_ffn_parity_pass=1 requires transformers_capture_module_path" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$EXPERT_BAD_JSON" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

write_bad_expert_row independent_mismatch
expect_fail_with \
  "real expert_ffn_parity_pass=1 requires candidate_output_sha256 to match independent_runtime_output_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$EXPERT_BAD_JSON" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

write_bad_expert_row transformers_mismatch
expect_fail_with \
  "real expert_ffn_parity_pass=1 requires torch_reference_output_sha256 to match transformers_expert_output_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$EXPERT_BAD_JSON" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

if [ -e "$MOE_ROWS" ]; then
  echo "refusing to overwrite existing v61 MoE block artifact: $MOE_ROWS" >&2
  exit 1
fi
mkdir -p "$(dirname "$MOE_ROWS")"
cleanup() {
  rm -f "$MOE_ROWS"
  rm -f "$LOGITS_ROWS"
  rm -f "$DECODE_ROWS"
  rmdir "$(dirname "$MOE_ROWS")" 2>/dev/null || true
  rmdir "$(dirname "$LOGITS_ROWS")" 2>/dev/null || true
  rmdir "$(dirname "$DECODE_ROWS")" 2>/dev/null || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$MOE_ROWS" <<'CSV'
checkpoint_id,model_revision,layer_index,token_id,contract_ready,fixture_execution_ready,real_model_execution_ready,heldout_metric_ready,human_review_ready,independent_reproduction_ready,release_ready,local_checkpoint_root_supplied,checkpoint_payload_bytes_committed_to_repo,actual_model_generation_ready,route_jump_rows,status,reason,expert_ffn_artifact_sha256,input_hidden_sha256,router_tensor_name,router_payload_sha256,router_logits_sha256,selected_expert_ids,selected_expert_weights,selected_expert_payload_sha256s,expert_output_sha256,moe_block_output_sha256,torch_reference_output_sha256,max_abs_delta,tolerance,moe_block_parity_pass
fixture-checkpoint,fixture-revision,0,1,1,0,1,0,0,0,0,1,0,0,0,blocked,malicious blocked artifact claims real execution,sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,model.layers.0.block_sparse_moe.gate.weight,sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,0,1.0,sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,sha256:1111111111111111111111111111111111111111111111111111111111111111,sha256:2222222222222222222222222222222222222222222222222222222222222222,0,1e-06,0
CSV

expect_fail_with \
  "forbids real_model_execution_ready=1" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$MOE_ROWS"

cat >"$MOE_ROWS" <<'CSV'
checkpoint_id,model_revision,layer_index,token_id,contract_ready,fixture_execution_ready,real_model_execution_ready,heldout_metric_ready,human_review_ready,independent_reproduction_ready,release_ready,local_checkpoint_root_supplied,checkpoint_payload_bytes_committed_to_repo,actual_model_generation_ready,route_jump_rows,status,reason,expert_ffn_artifact_sha256,input_hidden_sha256,router_tensor_name,router_payload_sha256,router_logits_sha256,selected_expert_ids,selected_expert_weights,selected_expert_payload_sha256s,expert_output_sha256,moe_block_output_sha256,torch_reference_output_sha256,max_abs_delta,tolerance,moe_block_parity_pass
fixture-checkpoint,fixture-revision,0,1,1,0,0,0,0,0,0,1,0,0,0,blocked,malicious blocked artifact claims local checkpoint root,sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,model.layers.0.block_sparse_moe.gate.weight,sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,0,1.0,sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,sha256:1111111111111111111111111111111111111111111111111111111111111111,sha256:2222222222222222222222222222222222222222222222222222222222222222,0,1e-06,0
CSV

expect_fail_with \
  "forbids local_checkpoint_root_supplied=1" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$MOE_ROWS"

if [ -e "$LOGITS_ROWS" ]; then
  echo "refusing to overwrite existing v61 one-token logits artifact: $LOGITS_ROWS" >&2
  exit 1
fi
mkdir -p "$(dirname "$LOGITS_ROWS")"
cat >"$LOGITS_ROWS" <<'CSV'
checkpoint_id,model_revision,tokenizer_revision,contract_ready,fixture_execution_ready,real_model_execution_ready,heldout_metric_ready,human_review_ready,independent_reproduction_ready,release_ready,local_checkpoint_root_supplied,checkpoint_payload_bytes_committed_to_repo,actual_model_generation_ready,route_jump_rows,status,reason,moe_block_artifact_sha256,tokenizer_input_sha256,token_id,router_top_k,layer_activation_trace_sha256,layer_activation_trace_rows,route_path_sha256,final_hidden_sha256,lm_head_tensor_name,lm_head_payload_sha256,vocab_size,logit_count,candidate_logits_sha256,torch_reference_logits_sha256,max_abs_delta,mean_abs_delta,tolerance,top1_token_id,reference_top1_token_id,top_k_token_count,candidate_top_k_token_ids,reference_top_k_token_ids,top_k_token_ranking_match,logits_parity_pass
fixture-checkpoint,fixture-revision,fixture-tokenizer,1,0,0,0,0,0,0,1,0,0,0,blocked,malicious blocked logits artifact claims parity,sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,1,2,sha256:abababababababababababababababababababababababababababababababab,32,sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,model.embed_tokens.weight,sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,32000,32000,sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,sha256:1111111111111111111111111111111111111111111111111111111111111111,0,0,1e-06,1,1,5,1|2|3|4|5,1|2|3|4|5,1,1
CSV

expect_fail_with \
  "blocked milestone one-token-logits-parity cannot contain logits_parity_pass=1 rows" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row() {
  local mode="$1"
  python3 - "$ROOT_DIR/v61/one_token_path.json" "$LOGITS_ROWS" "$mode" <<'PY'
import csv
import json
import sys
from pathlib import Path

contract_path, rows_path, mode = sys.argv[1:4]
data = json.loads(Path(contract_path).read_text(encoding="utf-8"))
columns = next(
    row["required_columns"]
    for row in data["required_artifacts"]
    if row["artifact_id"] == "one-token-logits-parity-rows"
)
values = {column: "" for column in columns}
values.update({
    "checkpoint_id": "fixture-checkpoint",
    "model_revision": "fixture-revision",
    "config_sha256": "sha256:" + "2" * 64,
    "tokenizer_revision": "fixture-tokenizer",
    "shard_index_sha256": "sha256:" + "3" * 64,
    "full_manifest_sha256": "sha256:" + "4" * 64,
    "contract_ready": "1",
    "fixture_execution_ready": "0",
    "real_model_execution_ready": "0",
    "heldout_metric_ready": "0",
    "human_review_ready": "0",
    "independent_reproduction_ready": "0",
    "release_ready": "0",
    "local_checkpoint_root_supplied": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "route_jump_rows": "0",
    "status": "blocked",
    "reason": "malicious blocked logits artifact claims parity",
    "moe_block_artifact_sha256": "sha256:" + "a" * 64,
    "tokenizer_input_sha256": "sha256:" + "b" * 64,
    "token_id": "1",
    "router_top_k": "2",
    "layer_activation_trace_sha256": "sha256:" + "a0" * 32,
    "layer_activation_trace_rows": "32",
    "route_path_sha256": "sha256:" + "c" * 64,
    "final_hidden_sha256": "sha256:" + "d" * 64,
    "lm_head_tensor_name": "lm_head.weight",
    "lm_head_payload_sha256": "sha256:" + "e" * 64,
    "vocab_size": "32000",
    "logit_count": "32000",
    "candidate_logits_sha256": "sha256:" + "f" * 64,
    "torch_reference_logits_sha256": "sha256:" + "1" * 64,
    "max_abs_delta": "0",
    "mean_abs_delta": "0",
    "tolerance": "1e-06",
    "top1_token_id": "1",
    "reference_top1_token_id": "1",
    "top_k_token_count": "5",
    "candidate_top_k_token_ids": "1|2|3|4|5",
    "reference_top_k_token_ids": "1|2|3|4|5",
    "top_k_token_ranking_match": "1",
    "logits_parity_pass": "1",
})
if mode == "topk_bad":
    values["top_k_token_ranking_match"] = "0"
elif mode == "topk_ids_bad":
    values["candidate_top_k_token_ids"] = "1|2|3|4|9"
elif mode == "topk_count_bad":
    values["top_k_token_count"] = "4"
elif mode == "topk_oob_bad":
    values["vocab_size"] = "3"
    values["logit_count"] = "3"
elif mode == "candidate_topk_token_oob_bad":
    values["vocab_size"] = "6"
    values["logit_count"] = "6"
    values["candidate_top_k_token_ids"] = "1|2|3|4|6"
elif mode == "reference_topk_token_oob_bad":
    values["vocab_size"] = "6"
    values["logit_count"] = "6"
    values["reference_top_k_token_ids"] = "1|2|3|4|6"
elif mode == "topk_duplicate_bad":
    values["candidate_top_k_token_ids"] = "1|2|2|4|5"
    values["reference_top_k_token_ids"] = "1|2|2|4|5"
elif mode == "reference_topk_duplicate_bad":
    values["reference_top_k_token_ids"] = "1|2|2|4|5"
elif mode == "candidate_logits_hash_bad":
    values["candidate_logits_sha256"] = "sha256:" + "z" * 64
elif mode == "blank_checkpoint_bad":
    values["checkpoint_id"] = ""
elif mode == "blank_model_revision_bad":
    values["model_revision"] = ""
elif mode == "blank_tokenizer_revision_bad":
    values["tokenizer_revision"] = ""
elif mode == "config_hash_bad":
    values["config_sha256"] = "sha256:" + "z" * 64
elif mode == "shard_index_hash_bad":
    values["shard_index_sha256"] = ""
elif mode == "full_manifest_hash_bad":
    values["full_manifest_sha256"] = "not-a-sha"
elif mode == "mean_bad":
    values["mean_abs_delta"] = "0.01"
elif mode == "max_bad":
    values["max_abs_delta"] = "0.01"
elif mode == "activation_bad":
    values["layer_activation_trace_sha256"] = ""
elif mode == "activation_rows_bad":
    values["layer_activation_trace_rows"] = "0"
elif mode == "topk_parse_bad":
    values["candidate_top_k_token_ids"] = "1|two|3|4|5"
elif mode == "real_ready_without_pass":
    values["real_model_execution_ready"] = "1"
    values["logits_parity_pass"] = "0"
elif mode == "blocked_fixture_ready_claim":
    values["fixture_execution_ready"] = "1"
    values["status"] = "pass"
    values["logits_parity_pass"] = "0"
elif mode == "blocked_status_pass_claim":
    values["status"] = "pass"
    values["logits_parity_pass"] = "0"
else:
    raise SystemExit(f"unknown mode: {mode}")
path = Path(rows_path)
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=columns, lineterminator="\n")
    writer.writeheader()
    writer.writerow(values)
PY
}

write_bad_logits_row topk_bad
expect_fail_with \
  "logits_parity_pass=1 requires top_k_token_ranking_match=1" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row topk_ids_bad
expect_fail_with \
  "logits_parity_pass=1 requires candidate_top_k_token_ids to match reference_top_k_token_ids" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row topk_count_bad
expect_fail_with \
  "logits_parity_pass=1 requires candidate_top_k_token_ids length to equal top_k_token_count" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row topk_oob_bad
expect_fail_with \
  "logits_parity_pass=1 requires top_k_token_count <= vocab_size" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row candidate_topk_token_oob_bad
expect_fail_with \
  "logits_parity_pass=1 requires candidate_top_k_token_ids < vocab_size" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row reference_topk_token_oob_bad
expect_fail_with \
  "logits_parity_pass=1 requires reference_top_k_token_ids < vocab_size" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row topk_duplicate_bad
expect_fail_with \
  "logits_parity_pass=1 requires unique candidate_top_k_token_ids" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row reference_topk_duplicate_bad
expect_fail_with \
  "logits_parity_pass=1 requires unique reference_top_k_token_ids" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row candidate_logits_hash_bad
expect_fail_with \
  "logits_parity_pass=1 requires candidate_logits_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row blank_checkpoint_bad
expect_fail_with \
  "logits_parity_pass=1 requires checkpoint_id" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row blank_model_revision_bad
expect_fail_with \
  "logits_parity_pass=1 requires model_revision" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row blank_tokenizer_revision_bad
expect_fail_with \
  "logits_parity_pass=1 requires tokenizer_revision" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row config_hash_bad
expect_fail_with \
  "logits_parity_pass=1 requires config_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row shard_index_hash_bad
expect_fail_with \
  "logits_parity_pass=1 requires shard_index_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row full_manifest_hash_bad
expect_fail_with \
  "logits_parity_pass=1 requires full_manifest_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row mean_bad
expect_fail_with \
  "logits_parity_pass=1 requires max_abs_delta and mean_abs_delta <= tolerance" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row max_bad
expect_fail_with \
  "logits_parity_pass=1 requires max_abs_delta and mean_abs_delta <= tolerance" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row activation_bad
expect_fail_with \
  "logits_parity_pass=1 requires layer_activation_trace_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row activation_rows_bad
expect_fail_with \
  "logits_parity_pass=1 requires positive integer layer_activation_trace_rows" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row topk_parse_bad
expect_fail_with \
  "logits_parity_pass=1 requires parseable candidate_top_k_token_ids" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row real_ready_without_pass
expect_fail_with \
  "real_model_execution_ready=1 requires logits_parity_pass=1" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row blocked_fixture_ready_claim
expect_fail_with \
  "blocked milestone one-token-logits-parity forbids fixture_execution_ready=1" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

write_bad_logits_row blocked_status_pass_claim
expect_fail_with \
  "blocked milestone one-token-logits-parity requires status=blocked" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

if [ -e "$DECODE_ROWS" ]; then
  echo "refusing to overwrite existing v61 sixteen-token decode artifact: $DECODE_ROWS" >&2
  exit 1
fi
mkdir -p "$(dirname "$DECODE_ROWS")"

write_bad_decode_row() {
  local mode="$1"
  python3 - "$ROOT_DIR/v61/one_token_path.json" "$DECODE_ROWS" "$mode" <<'PY'
import csv
import json
import sys
from pathlib import Path

contract_path, rows_path, mode = sys.argv[1:4]
data = json.loads(Path(contract_path).read_text(encoding="utf-8"))
columns = next(
    row["required_columns"]
    for row in data["required_artifacts"]
    if row["artifact_id"] == "sixteen-token-decode-rows"
)
values = {column: "" for column in columns}
values.update({
    "checkpoint_id": "fixture-checkpoint",
    "model_revision": "fixture-revision",
    "tokenizer_revision": "fixture-tokenizer",
    "contract_ready": "1",
    "fixture_execution_ready": "0",
    "real_model_execution_ready": "0",
    "heldout_metric_ready": "0",
    "human_review_ready": "0",
    "independent_reproduction_ready": "0",
    "release_ready": "0",
    "local_checkpoint_root_supplied": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "route_jump_rows": "0",
    "status": "blocked",
    "reason": "malicious blocked decode artifact claims parity",
    "logits_parity_artifact_sha256": "sha256:" + "a" * 64,
    "prompt_input_sha256": "sha256:" + "b" * 64,
    "decode_token_count": "3",
    "candidate_token_ids": "1|2|3",
    "reference_token_ids": "1|2|3",
    "candidate_text_sha256": "sha256:" + "c" * 64,
    "reference_text_sha256": "sha256:" + "c" * 64,
    "max_token_mismatch_count": "0",
    "decode_parity_pass": "1",
})
if mode == "token_ids_bad":
    values["candidate_token_ids"] = "1|2|9"
elif mode == "logits_hash_bad":
    values["logits_parity_artifact_sha256"] = "sha256:" + "z" * 64
elif mode == "prompt_hash_bad":
    values["prompt_input_sha256"] = "sha256:" + "z" * 64
elif mode == "mismatch_count_bad":
    values["max_token_mismatch_count"] = "1"
elif mode == "text_hash_mismatch_bad":
    values["reference_text_sha256"] = "sha256:" + "d" * 64
elif mode == "token_count_bad":
    values["decode_token_count"] = "2"
elif mode == "real_ready_bad_raw":
    values["real_model_execution_ready"] = "1"
    values["candidate_text_sha256"] = "sha256:" + "z" * 64
elif mode == "real_ready_without_pass":
    values["real_model_execution_ready"] = "1"
    values["decode_parity_pass"] = "0"
else:
    raise SystemExit(f"unknown mode: {mode}")
path = Path(rows_path)
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=columns, lineterminator="\n")
    writer.writeheader()
    writer.writerow(values)
PY
}

write_bad_decode_row token_ids_bad
expect_fail_with \
  "decode_parity_pass=1 requires candidate_token_ids to match reference_token_ids" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$DECODE_ROWS"

write_bad_decode_row logits_hash_bad
expect_fail_with \
  "decode_parity_pass=1 requires logits_parity_artifact_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$DECODE_ROWS"

write_bad_decode_row prompt_hash_bad
expect_fail_with \
  "decode_parity_pass=1 requires prompt_input_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$DECODE_ROWS"

write_bad_decode_row mismatch_count_bad
expect_fail_with \
  "decode_parity_pass=1 requires max_token_mismatch_count=0" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$DECODE_ROWS"

write_bad_decode_row text_hash_mismatch_bad
expect_fail_with \
  "decode_parity_pass=1 requires candidate_text_sha256 to match reference_text_sha256" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$DECODE_ROWS"

write_bad_decode_row token_count_bad
expect_fail_with \
  "decode_parity_pass=1 requires candidate_token_ids length to equal decode_token_count" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$DECODE_ROWS"

write_bad_decode_row real_ready_bad_raw
expect_fail_with \
  "real_model_execution_ready=1 is not supported by sixteen-token decode raw parity evidence" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$DECODE_ROWS"

write_bad_decode_row real_ready_without_pass
expect_fail_with \
  "real_model_execution_ready=1 requires decode_parity_pass=1" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$DECODE_ROWS"

CACHE_ROWS="$TMP_DIR/cold_warm_cache_measurement_rows.csv"
CACHE_BAD_JSON="$TMP_DIR/cache_temp_path_bad.json"
python3 - "$ROOT_DIR/v61/one_token_path.json" "$CACHE_BAD_JSON" "$CACHE_ROWS" <<'PY'
import csv
import json
import sys
from pathlib import Path

source, target, rows_path = sys.argv[1:4]
data = json.loads(Path(source).read_text(encoding="utf-8"))
columns = next(
    row["required_columns"]
    for row in data["required_artifacts"]
    if row["artifact_id"] == "cold-warm-cache-measurement-rows"
)
for row in data["required_artifacts"]:
    if row["artifact_id"] == "cold-warm-cache-measurement-rows":
        row["path"] = rows_path
        break
values = {column: "" for column in columns}
values.update({
    "measurement_id": "cold",
    "cache_state": "cold",
    "checkpoint_id": "fixture-checkpoint",
    "model_revision": "fixture-revision",
    "contract_ready": "1",
    "fixture_execution_ready": "0",
    "real_model_execution_ready": "1",
    "heldout_metric_ready": "0",
    "human_review_ready": "0",
    "independent_reproduction_ready": "0",
    "release_ready": "0",
    "local_checkpoint_root_supplied": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "actual_model_generation_ready": "0",
    "route_jump_rows": "0",
    "status": "blocked",
    "reason": "malicious blocked cache artifact claims real execution",
    "decode_artifact_sha256": "sha256:" + "a" * 64,
    "runtime_settings_sha256": "sha256:" + "b" * 64,
    "tokens_decoded": "16",
    "wall_time_ms": "10",
    "first_token_latency_ms": "2",
    "steady_state_tps": "100",
    "ssd_bytes_read": "0",
    "cache_miss_count": "0",
    "cache_hit_count": "1",
    "cache_measurement_pass": "0",
})
Path(target).write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
path = Path(rows_path)
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=columns, lineterminator="\n")
    writer.writeheader()
    writer.writerow(values)
PY
expect_fail_with \
  "blocked milestone cold-warm-cache-measurement forbids real_model_execution_ready=1" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$CACHE_BAD_JSON" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

"$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv" >/dev/null

echo "v61 one-token path contract smoke passed"
