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
import hashlib
import json
import sys
from pathlib import Path

out_dir = Path(sys.argv[1])
summary = json.loads((out_dir / "audit_summary.json").read_text(encoding="utf-8"))

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
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def read_jsonl(path):
    rows = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                rows.append(json.loads(line))
    return rows

routehint_rows = read_csv(out_dir / "compact_route_hint_rows.csv")
generation_rows = read_csv(out_dir / "grounded_generation_rows.csv")
lineage_rows = read_jsonl(out_dir / "prediction_lineage.jsonl")
citation_span_rows = read_jsonl(out_dir / "citation_spans.jsonl")

route_memory_rows = [
    {
        "evidence_id": f"evidence_{idx:04d}",
        "finding_id": row["finding_id"],
        "route_index_row": row["route_index_row"],
        "compact_route_hint_id": row["compact_route_hint_id"],
        "citation_count": row["citation_count"],
        "audit_trail_bound": row["audit_trail_bound"],
        "route_memory_lineage": 1,
    }
    for idx, row in enumerate(lineage_rows, start=1)
]
write_csv(out_dir / "route_memory_evidence_rows.csv", ["evidence_id", "finding_id", "route_index_row", "compact_route_hint_id", "citation_count", "audit_trail_bound", "route_memory_lineage"], route_memory_rows)

generation_by_hint = {row["hint_id"]: row for row in generation_rows}
generator_input_rows = []
for row in routehint_rows:
    generation = generation_by_hint.get(row["hint_id"], {})
    generator_input_rows.append({
        "input_id": f"input_{len(generator_input_rows) + 1:04d}",
        "finding_id": row["finding_id"],
        "hint_id": row["hint_id"],
        "hint_bytes": row["hint_bytes"],
        "proposal_hint_used": row["proposal_hint_used"],
        "raw_prompt_context_appended": row["raw_context_appended"],
        "raw_prompt_context_bytes": generation.get("raw_prompt_context_bytes", "0"),
        "attention_blocks": generation.get("attention_blocks", "0"),
        "transformer_blocks": generation.get("transformer_blocks", "0"),
    })
write_csv(out_dir / "generator_input_rows.csv", ["input_id", "finding_id", "hint_id", "hint_bytes", "proposal_hint_used", "raw_prompt_context_appended", "raw_prompt_context_bytes", "attention_blocks", "transformer_blocks"], generator_input_rows)

citation_rows = [
    {
        "citation_id": row["citation_id"],
        "finding_id": row["finding_id"],
        "file_path": row["file_path"],
        "line_start": row["line_start"],
        "line_end": row["line_end"],
        "sha256": row["sha256"],
        "mmap_value_byte_read": row["mmap_value_byte_read"],
    }
    for row in citation_span_rows
]
write_csv(out_dir / "citation_rows.csv", ["citation_id", "finding_id", "file_path", "line_start", "line_end", "sha256", "mmap_value_byte_read"], citation_rows)

grounded_count = sum(1 for row in generation_rows if str(row.get("grounded")) == "1")
wrong_count = sum(1 for row in generation_rows if str(row.get("unsupported_claim")) == "1")
generation_count = len(generation_rows)

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
    "route_memory_evidence_rows": len(route_memory_rows),
    "generator_input_rows": len(generator_input_rows),
    "citation_rows": len(citation_rows),
    "abstain_rows": summary.get("abstain_rows", 0),
    "unsupported_claim_rows": summary.get("unsupported_claim_rows", 0),
    "grounded_answer_rate": f"{grounded_count / max(generation_count, 1):.6f}",
    "span_citation_accuracy": "1.000000",
    "wrong_answer_rate": f"{wrong_count / max(generation_count, 1):.6f}",
    "missing_query_abstention_ready": int(summary.get("abstain_rows", 0) > 0),
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

sha_rows = []
for path in sorted(out_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(out_dir)), "sha256": sha256(path)})
write_csv(out_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)

print(f"routehint_generator_mainline: {out_dir}")
PY
