#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61a_ssd_weight_page_store"
RUN_ID="${V61A_RUN_ID:-store_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61A_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61a_ssd_weight_page_store_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
store_dir = run_dir / "weight_store"
store_dir.mkdir(parents=True, exist_ok=True)

PAGE_SIZE = 2 * 1024 * 1024
HEADER_SIZE = 64
LAYERS = 3
EXPERTS = 4
MAGIC = 0x56363141


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


quant_profiles = [
    {
        "quant_profile_id": "q5-router-hot",
        "quant_bits": "5",
        "assignment": "router-and-hot-expert-pages",
        "quality_risk": "low",
        "ssd_bytes_multiplier": "0.625",
    },
    {
        "quant_profile_id": "q4-active-default",
        "quant_bits": "4",
        "assignment": "active-expert-default",
        "quality_risk": "medium",
        "ssd_bytes_multiplier": "0.500",
    },
    {
        "quant_profile_id": "q3-cold-expert",
        "quant_bits": "3",
        "assignment": "cold-expert-pages",
        "quality_risk": "high",
        "ssd_bytes_multiplier": "0.375",
    },
]
write_csv(run_dir / "quant_profile_rows.csv", list(quant_profiles[0].keys()), quant_profiles)

page_rows = []
tensor_rows = []
expert_totals = {f"expert_{idx}": {"pages": 0, "bytes": 0, "hot": 0} for idx in range(EXPERTS)}
checksum_rows = []
page_id = 0

for layer_id in range(LAYERS):
    for expert_idx in range(EXPERTS):
        expert_id = f"expert_{expert_idx}"
        tensor_id = f"layer_{layer_id:02d}.{expert_id}.ffn_w1"
        if expert_idx == 0:
            quant_profile_id = "q5-router-hot"
            hotness_label = "vram-hot"
        elif expert_idx == 1:
            quant_profile_id = "q4-active-default"
            hotness_label = "warm-prefetch"
        else:
            quant_profile_id = "q3-cold-expert"
            hotness_label = "nvme-cold"
        page_name = f"page_{page_id:04d}_l{layer_id}_e{expert_idx}.bin"
        page_path = store_dir / page_name
        header = struct.pack(
            "<IIIIIIII",
            MAGIC,
            page_id,
            layer_id,
            expert_idx,
            PAGE_SIZE,
            HEADER_SIZE,
            int(quant_profile_id[1]),
            0xC001D00D,
        )
        header = header + bytes(HEADER_SIZE - len(header))
        body = bytes(((page_id * 29 + layer_id * 11 + expert_idx * 7 + i) % 256) for i in range(PAGE_SIZE - HEADER_SIZE))
        page_path.write_bytes(header + body)
        page_sha = sha256(page_path)
        page_rows.append(
            {
                "page_id": f"page_{page_id:04d}",
                "tensor_id": tensor_id,
                "layer_id": str(layer_id),
                "expert_id": expert_id,
                "page_index": "0",
                "page_path": f"weight_store/{page_name}",
                "page_offset": "0",
                "page_size_bytes": str(PAGE_SIZE),
                "payload_offset_bytes": str(HEADER_SIZE),
                "quant_profile_id": quant_profile_id,
                "prefetch_group_id": f"layer_{layer_id:02d}_expert_{expert_idx}",
                "hotness_label": hotness_label,
                "page_sha256": page_sha,
                "aligned_2mb": "1",
            }
        )
        tensor_rows.append(
            {
                "tensor_id": tensor_id,
                "layer_id": str(layer_id),
                "expert_id": expert_id,
                "tensor_role": "moe-ffn-w1",
                "page_count": "1",
                "total_bytes": str(PAGE_SIZE),
                "quant_profile_id": quant_profile_id,
            }
        )
        expert_totals[expert_id]["pages"] += 1
        expert_totals[expert_id]["bytes"] += PAGE_SIZE
        expert_totals[expert_id]["hot"] += int(hotness_label == "vram-hot")
        checksum_rows.append(
            {
                "page_id": f"page_{page_id:04d}",
                "page_path": f"weight_store/{page_name}",
                "sha256": page_sha,
                "bytes": str(PAGE_SIZE),
                "checksum_verified_at_write": "1",
            }
        )
        page_id += 1

write_csv(run_dir / "weight_page_rows.csv", list(page_rows[0].keys()), page_rows)
write_csv(run_dir / "weight_tensor_rows.csv", list(tensor_rows[0].keys()), tensor_rows)
write_csv(run_dir / "page_checksum_rows.csv", list(checksum_rows[0].keys()), checksum_rows)

expert_rows = []
for expert_id, totals in expert_totals.items():
    expert_idx = int(expert_id.split("_")[1])
    expert_rows.append(
        {
            "expert_id": expert_id,
            "layer_count": str(LAYERS),
            "page_count": str(totals["pages"]),
            "total_bytes": str(totals["bytes"]),
            "router_rank_hint": str(expert_idx),
            "active_probability_hint": f"{0.45 if expert_idx == 0 else 0.25 if expert_idx == 1 else 0.15:.2f}",
            "default_hotness": "vram-hot" if expert_idx == 0 else "warm-prefetch" if expert_idx == 1 else "nvme-cold",
        }
    )
write_csv(run_dir / "weight_expert_rows.csv", list(expert_rows[0].keys()), expert_rows)

tiny_moe_rows = []
for token_id in range(4):
    top1 = token_id % EXPERTS
    top2 = (top1 + 1) % EXPERTS
    tiny_moe_rows.append(
        {
            "token_id": str(token_id),
            "route_state_id": f"route_state_{token_id:02d}",
            "top1_expert_id": f"expert_{top1}",
            "top2_expert_id": f"expert_{top2}",
            "active_expert_count": "2",
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "tiny_moe_fixture_rows.csv", list(tiny_moe_rows[0].keys()), tiny_moe_rows)

manifest = {
    "manifest_scope": "v61a-ssd-weight-page-store",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61a_ssd_weight_page_store_ready": 1,
    "page_size_bytes": PAGE_SIZE,
    "ssd_pages_total": len(page_rows),
    "ssd_model_bytes_total": len(page_rows) * PAGE_SIZE,
    "layer_count": LAYERS,
    "expert_count": EXPERTS,
    "tiny_moe_fixture_ready": 1,
    "route_jump_rows": 0,
    "decode_runtime_ready": 0,
}
(run_dir / "v61a_ssd_weight_page_store_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)

(run_dir / "V61A_SSD_WEIGHT_PAGE_STORE_BOUNDARY.md").write_text(
    "# v61a SSD Weight Page Store Boundary\n\n"
    "This artifact creates a deterministic SSD-resident MoE weight page store. "
    "It is a page-store and metadata contract only; it does not claim decode readiness, near-frontier quality, GPU speedup, or release readiness.\n\n"
    f"- page_size_bytes={PAGE_SIZE}\n"
    f"- ssd_pages_total={len(page_rows)}\n"
    f"- ssd_model_bytes_total={len(page_rows) * PAGE_SIZE}\n"
    f"- expert_count={EXPERTS}\n"
    f"- layer_count={LAYERS}\n"
    "- tiny_moe_fixture_ready=1\n"
    "- route_jump_rows=0\n\n"
    "Next required layers: direct I/O reader, VRAM hot cache, page dequant matmul, expert router, and predictive prefetch.\n",
    encoding="utf-8",
)

artifact_rels = [
    "weight_page_rows.csv",
    "weight_tensor_rows.csv",
    "weight_expert_rows.csv",
    "quant_profile_rows.csv",
    "page_checksum_rows.csv",
    "tiny_moe_fixture_rows.csv",
    "v61a_ssd_weight_page_store_manifest.json",
    "V61A_SSD_WEIGHT_PAGE_STORE_BOUNDARY.md",
] + [row["page_path"] for row in page_rows]
sha_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary = {
    "v61a_ssd_weight_page_store_ready": "1",
    "ssd_model_bytes_total": str(len(page_rows) * PAGE_SIZE),
    "ssd_pages_total": str(len(page_rows)),
    "page_size_bytes": str(PAGE_SIZE),
    "weight_tensor_rows": str(len(tensor_rows)),
    "weight_expert_rows": str(len(expert_rows)),
    "quant_profile_rows": str(len(quant_profiles)),
    "tiny_moe_fixture_ready": "1",
    "route_jump_rows": "0",
    "decode_runtime_ready": "0",
    "near_frontier_claim_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("ssd-weight-page-store", "pass", "deterministic 2MB-aligned SSD page files and metadata are emitted"),
    ("page-checksums", "pass", "all page checksums are written and bound to metadata"),
    ("tiny-moe-fixture", "pass", "tiny MoE route fixture is emitted with route_jump_rows=0"),
    ("decode-runtime", "blocked", "v61a is a page-store contract only"),
    ("near-frontier-claim", "blocked", "no quality or speed claim is opened"),
    ("release-package", "blocked", "v61a is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

print(f"v61a_ssd_weight_page_store_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
