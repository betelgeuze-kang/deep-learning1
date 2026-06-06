#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO="${1:-$ROOT_DIR}"
OUT_DIR="${V54_ROUTEHINT_MAINLINE_DIR:-$ROOT_DIR/results/v54_routehint_generator_mainline}"

"$ROOT_DIR/scripts/audit_my_repo.sh" "$TARGET_REPO" \
  --mode quick \
  --max-queries "${V54_MAX_QUERIES:-80}" \
  --out "$OUT_DIR" \
  --generator routehint-tiny \
  --emit-report \
  --emit-lineage \
  --emit-reproduce >/dev/null

python3 - "$OUT_DIR" <<'PY'
import csv
import json
import sys
from pathlib import Path

out_dir = Path(sys.argv[1])
summary = json.loads((out_dir / "audit_summary.json").read_text(encoding="utf-8"))

manifest = {
    "routehint_generator_mainline_ready": int(
        summary.get("compact_route_hint_rows", 0) > 0
        and summary.get("grounded_generation_rows", 0) > 0
        and summary.get("raw_prompt_context_bytes") == 0
        and summary.get("attention_blocks") == 0
        and summary.get("transformer_blocks") == 0
        and summary.get("oracle_prediction_used") == 0
        and summary.get("raw_input_extractor_used") == 0
    ),
    "raw_prompt_context_appended_rows": 0,
    "attention_blocks": 0,
    "transformer_blocks": 0,
    "proposal_hint_used_rows": summary.get("compact_route_hint_rows", 0),
    "generation_rows": summary.get("grounded_generation_rows", 0),
    "abstain_rows": summary.get("abstain_rows", 0),
    "unsupported_claim_rows": summary.get("unsupported_claim_rows", 0),
    "real_release_package_ready": 0,
    "gpu_speedup_claim": "deferred",
}
(out_dir / "generation_metrics.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(out_dir / "generator_boundary.md").write_text(
    "# RouteHint Generator Boundary\n\n"
    "This mainline preview uses compact RouteHint rows from RouteMemory evidence and a tiny non-attention generator path. "
    "It does not append raw retrieved text to the prompt, does not use attention or Transformer decoder blocks, "
    "does not use an oracle answer, and does not promote production-ready or GPU-speedup claims.\n",
    encoding="utf-8",
)
with (out_dir / "v54_routehint_generator_mainline_summary.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(manifest.keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerow(manifest)

print(f"routehint_generator_mainline: {out_dir}")
PY
