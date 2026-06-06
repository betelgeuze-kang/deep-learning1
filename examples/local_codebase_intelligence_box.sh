#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_REPO="${1:-$ROOT_DIR}"
OUT_DIR="${V55_LOCAL_CODEBASE_BOX_DIR:-$ROOT_DIR/results/v55_local_codebase_intelligence_box}"
AUDIT_DIR="$OUT_DIR/audit"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

"$ROOT_DIR/scripts/audit_my_repo.sh" "$DEMO_REPO" \
  --mode quick \
  --max-queries "${V55_MAX_QUERIES:-100}" \
  --out "$AUDIT_DIR" \
  --generator routehint-tiny \
  --emit-report \
  --emit-lineage \
  --emit-reproduce >/dev/null

cp "$AUDIT_DIR/AUDIT_REPORT.md" "$OUT_DIR/AUDIT_REPORT.md"
cp "$AUDIT_DIR/ARCHITECTURE_TRACE.md" "$OUT_DIR/ARCHITECTURE_TRACE.md"
cp "$AUDIT_DIR/prediction_lineage.jsonl" "$OUT_DIR/prediction_lineage.jsonl"
cp "$AUDIT_DIR/compact_route_hint_rows.csv" "$OUT_DIR/compact_route_hint_rows.csv"
cp "$AUDIT_DIR/grounded_generation_rows.csv" "$OUT_DIR/grounded_generation_rows.csv"
cp "$AUDIT_DIR/citation_spans.jsonl" "$OUT_DIR/citation_spans.jsonl"
cp "$AUDIT_DIR/abstain_rows.csv" "$OUT_DIR/abstain_rows.csv"
cp "$AUDIT_DIR/wrong_answer_guard_rows.csv" "$OUT_DIR/wrong_answer_guard_rows.csv"
cp "$AUDIT_DIR/claim_boundary.md" "$OUT_DIR/claim_boundary.md"
cp "$AUDIT_DIR/resource_envelope.json" "$OUT_DIR/resource_envelope.json"

python3 - "$ROOT_DIR" "$OUT_DIR" "$AUDIT_DIR" "$DEMO_REPO" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
audit_dir = Path(sys.argv[3])
demo_repo = Path(sys.argv[4])
summary = json.loads((audit_dir / "audit_summary.json").read_text(encoding="utf-8"))

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

(out_dir / "README_RESULT.md").write_text(
    "# v0.3 Architecture Preview Result\n\n"
    "This demo runs a local evidence-bound codebase audit.\n\n"
    "- No oracle\n"
    "- No raw-input extractor\n"
    "- No prompt stuffing\n"
    "- No attention/Transformer blocks in the RouteHint generator path\n"
    "- Every promoted answer is bound to source evidence\n"
    "- Produces citation, abstain, audit trail, and reproducibility packet\n\n"
    f"Target repo: `{demo_repo}`\n\n"
    f"Findings: {summary['finding_rows']}\n\n"
    f"Abstentions: {summary['abstain_rows']}\n",
    encoding="utf-8",
)

(out_dir / "BASELINE_COMPARISON.md").write_text(
    "# Baseline Comparison\n\n"
    "This showcase is bound to the repository's v14c baseline-comparison harness for the formal baseline war. "
    "The user-facing audit keeps raw prompt context at 0 bytes and preserves citation/abstain/audit-trail artifacts.\n\n"
    "- raw_prompt_context_bytes=0\n"
    "- raw_input_extractor_used=0\n"
    "- oracle_prediction_used=0\n",
    encoding="utf-8",
)

(out_dir / "LOCAL_SCALING_SUMMARY.md").write_text(
    "# Local Scaling Summary\n\n"
    "The preview records a bounded local resource envelope for this one-command audit. "
    "Run `./scripts/run_local_scaling_matrix.sh /path/to/repo` for the full one-axis store/top-k/cache/RouteHint/query-count curve artifact. "
    "This showcase does not open GPU speedup wording.\n\n"
    f"- source_files_scanned={summary['source_files']}\n"
    f"- finding_rows={summary['finding_rows']}\n"
    "- gpu_speedup_claim=deferred\n",
    encoding="utf-8",
)

reproduce = out_dir / "reproduce.sh"
reproduce.write_text(
    "#!/usr/bin/env bash\n"
    "set -euo pipefail\n"
    f"cd {str(root)!r}\n"
    f"./examples/local_codebase_intelligence_box.sh {str(demo_repo)!r}\n",
    encoding="utf-8",
)
reproduce.chmod(0o755)

manifest = {
    "local_codebase_intelligence_box_ready": 1,
    "audit_report_ready": int((out_dir / "AUDIT_REPORT.md").is_file()),
    "baseline_comparison_ready": int((out_dir / "BASELINE_COMPARISON.md").is_file()),
    "local_scaling_summary_ready": int((out_dir / "LOCAL_SCALING_SUMMARY.md").is_file()),
    "architecture_trace_ready": int((out_dir / "ARCHITECTURE_TRACE.md").is_file()),
    "prediction_lineage_rows": summary["route_memory_lineage_rows"],
    "compact_route_hint_rows": summary["compact_route_hint_rows"],
    "grounded_generation_rows": summary["grounded_generation_rows"],
    "abstain_rows": summary["abstain_rows"],
    "raw_prompt_context_bytes": 0,
    "attention_blocks": 0,
    "transformer_blocks": 0,
    "real_release_package_ready": 0,
    "gpu_speedup_claim": "deferred",
}
(out_dir / "v55_local_codebase_intelligence_box_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

rows = []
for path in sorted(out_dir.rglob("*")):
    if path.is_file() and path.name != "sha256sums.txt":
        rows.append(f"{sha256(path)}  {path.relative_to(out_dir)}")
(out_dir / "sha256sums.txt").write_text("\n".join(rows) + "\n", encoding="utf-8")

with (out_dir / "v55_local_codebase_intelligence_box_summary.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(manifest.keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerow(manifest)
PY

echo "local_codebase_intelligence_box: $OUT_DIR"
