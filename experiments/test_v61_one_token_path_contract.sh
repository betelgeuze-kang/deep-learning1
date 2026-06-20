#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
MOE_ROWS="$RESULTS_DIR/v61_moe_block_forward_parity/moe_block_forward_parity_rows.csv"
LOGITS_ROWS="$RESULTS_DIR/v61_one_token_logits_parity/one_token_logits_parity_rows.csv"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v61-one-token-contract.XXXXXX")"
BAD_OUTPUT="$TMP_DIR/expect_fail.out"
cd "$ROOT_DIR"

cleanup() {
  if [ -n "${REMOTE_BINDING_ROWS:-}" ] && [ -n "${REMOTE_BINDING_BACKUP:-}" ] && [ -f "$REMOTE_BINDING_BACKUP" ]; then
    cp "$REMOTE_BINDING_BACKUP" "$REMOTE_BINDING_ROWS" 2>/dev/null || true
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
checkpoint_id,model_revision,config_sha256,tokenizer_revision,shard_index_sha256,full_manifest_sha256,layer_index,expert_index,token_id,router_top_k,rmsnorm_tensor_name,rmsnorm_payload_sha256,router_tensor_name,router_payload_sha256,w1_tensor_name,w2_tensor_name,w3_tensor_name,contract_ready,fixture_execution_ready,real_model_execution_ready,heldout_metric_ready,human_review_ready,independent_reproduction_ready,release_ready,local_checkpoint_root_supplied,checkpoint_payload_bytes_committed_to_repo,actual_model_generation_ready,route_jump_rows,status,reason,w1_shape,w2_shape,w3_shape,w1_payload_sha256,w2_payload_sha256,w3_payload_sha256,input_hidden_size,intermediate_size,output_hidden_size,residual_input_sha256,residual_output_sha256,transformers_expert_output_sha256,independent_runtime_output_sha256,candidate_output_sha256,torch_reference_output_sha256,max_abs_delta,tolerance,expert_ffn_parity_pass
fixture-checkpoint,fixture-revision,sha256:1212121212121212121212121212121212121212121212121212121212121212,fixture-tokenizer,sha256:3434343434343434343434343434343434343434343434343434343434343434,sha256:5656565656565656565656565656565656565656565656565656565656565656,0,0,1,2,model.layers.0.input_layernorm.weight,sha256:7777777777777777777777777777777777777777777777777777777777777777,model.layers.0.block_sparse_moe.gate.weight,sha256:8888888888888888888888888888888888888888888888888888888888888888,model.layers.0.block_sparse_moe.experts.0.w1.weight,model.layers.0.block_sparse_moe.experts.0.w2.weight,model.layers.0.block_sparse_moe.experts.0.w3.weight,1,0,1,0,0,0,0,1,0,0,0,blocked,malicious blocked expert FFN artifact claims real execution,"[14336,6144]","[6144,14336]","[14336,6144]",sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,6144,14336,6144,sha256:9999999999999999999999999999999999999999999999999999999999999999,sha256:abababababababababababababababababababababababababababababababab,sha256:cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd,sha256:efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef,sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,0,1e-06,1
CSV
expect_fail_with \
  "blocked milestone real-expert-ffn-forward-parity cannot contain expert_ffn_parity_pass=1 rows" \
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
  rmdir "$(dirname "$MOE_ROWS")" 2>/dev/null || true
  rmdir "$(dirname "$LOGITS_ROWS")" 2>/dev/null || true
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
checkpoint_id,model_revision,tokenizer_revision,contract_ready,fixture_execution_ready,real_model_execution_ready,heldout_metric_ready,human_review_ready,independent_reproduction_ready,release_ready,local_checkpoint_root_supplied,checkpoint_payload_bytes_committed_to_repo,actual_model_generation_ready,route_jump_rows,status,reason,moe_block_artifact_sha256,tokenizer_input_sha256,route_path_sha256,final_hidden_sha256,lm_head_tensor_name,lm_head_payload_sha256,vocab_size,logit_count,candidate_logits_sha256,torch_reference_logits_sha256,max_abs_delta,tolerance,top1_token_id,reference_top1_token_id,logits_parity_pass
fixture-checkpoint,fixture-revision,fixture-tokenizer,1,0,0,0,0,0,0,1,0,0,0,blocked,malicious blocked logits artifact claims parity,sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,model.embed_tokens.weight,sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,32000,32000,sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,sha256:1111111111111111111111111111111111111111111111111111111111111111,0,1e-06,1,1,1
CSV

expect_fail_with \
  "blocked milestone one-token-logits-parity cannot contain logits_parity_pass=1 rows" \
  "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv"

rm -f "$LOGITS_ROWS"

"$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv" >/dev/null

echo "v61 one-token path contract smoke passed"
