#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
MOE_ROWS="$RESULTS_DIR/v61_moe_block_forward_parity/moe_block_forward_parity_rows.csv"
BAD_OUTPUT="$(mktemp)"
cd "$ROOT_DIR"
trap 'rm -f "$BAD_OUTPUT"' EXIT

"$ROOT_DIR/experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh" >/dev/null

if [ -e "$MOE_ROWS" ]; then
  echo "refusing to overwrite existing v61 MoE block artifact: $MOE_ROWS" >&2
  exit 1
fi
mkdir -p "$(dirname "$MOE_ROWS")"
cleanup() {
  rm -f "$MOE_ROWS"
  rm -f "$BAD_OUTPUT"
  rmdir "$(dirname "$MOE_ROWS")" 2>/dev/null || true
}
trap cleanup EXIT

cat >"$MOE_ROWS" <<'CSV'
checkpoint_id,model_revision,layer_index,token_id,contract_ready,fixture_execution_ready,real_model_execution_ready,heldout_metric_ready,human_review_ready,independent_reproduction_ready,release_ready,local_checkpoint_root_supplied,checkpoint_payload_bytes_committed_to_repo,actual_model_generation_ready,route_jump_rows,status,reason,expert_ffn_artifact_sha256,input_hidden_sha256,router_tensor_name,router_payload_sha256,router_logits_sha256,selected_expert_ids,selected_expert_weights,selected_expert_payload_sha256s,expert_output_sha256,moe_block_output_sha256,torch_reference_output_sha256,max_abs_delta,tolerance,moe_block_parity_pass
fixture-checkpoint,fixture-revision,0,1,1,0,1,0,0,0,0,1,0,0,0,blocked,malicious blocked artifact claims real execution,sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,model.layers.0.block_sparse_moe.gate.weight,sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,0,1.0,sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,sha256:1111111111111111111111111111111111111111111111111111111111111111,sha256:2222222222222222222222222222222222222222222222222222222222222222,0,1e-06,0
CSV

if "$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv" >"$BAD_OUTPUT" 2>&1; then
  echo "v61 one-token verifier accepted a blocked artifact with real_model_execution_ready=1" >&2
  cat "$BAD_OUTPUT" >&2
  exit 1
fi
if ! grep -q "forbids real_model_execution_ready=1" "$BAD_OUTPUT"; then
  echo "v61 one-token verifier failed, but not for the blocked real execution guard" >&2
  cat "$BAD_OUTPUT" >&2
  exit 1
fi

rm -f "$MOE_ROWS"

"$ROOT_DIR/tools/verify_artifact.py" v61-one-token "$ROOT_DIR/v61/one_token_path.json" \
  --v61aa-summary "$RESULTS_DIR/v61aa_hotset_tensor_slice_verifier_summary.csv" \
  --v61ab-summary "$RESULTS_DIR/v61ab_hotset_tensor_tile_quant_probe_summary.csv" >/dev/null

echo "v61 one-token path contract smoke passed"
