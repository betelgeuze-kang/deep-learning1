#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bw_ubuntu1_partial_page_hash_witness"
RUN_ID="${V61BW_RUN_ID:-hash_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT="${V61BW_WAREHOUSE_ROOT:-/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse}"
MAX_PAGES="${V61BW_MAX_PAGES:-0}"

if [[ "${V61BW_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bw_ubuntu1_partial_page_hash_witness_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BU_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61BU_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61bu_ubuntu1_partial_checkpoint_materialization_witness.sh" >/dev/null
V61Q_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61q_real_checkpoint_page_map.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT" "$MAX_PAGES" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
warehouse_root = sys.argv[5]
max_pages = int(sys.argv[6])
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


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


v61bu_dir = results / "v61bu_ubuntu1_partial_checkpoint_materialization_witness" / "witness_001"
v61t_dir = results / "v61t_local_checkpoint_materialization_verifier" / "verify_001"
v61q_dir = results / "v61q_real_checkpoint_page_map" / "map_001"
v61bu_summary_path = results / "v61bu_ubuntu1_partial_checkpoint_materialization_witness_summary.csv"
v61q_summary_path = results / "v61q_real_checkpoint_page_map_summary.csv"
v61t_summary_path = results / "v61t_local_checkpoint_materialization_verifier_summary.csv"
v61bu_summary = read_csv(v61bu_summary_path)[0]
v61q_summary = read_csv(v61q_summary_path)[0]
v61t_summary = read_csv(v61t_summary_path)[0]

if v61bu_summary.get("v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready") != "1":
    raise SystemExit("v61bw requires v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready=1")
if v61q_summary.get("v61q_real_checkpoint_page_map_ready") != "1":
    raise SystemExit("v61bw requires v61q_real_checkpoint_page_map_ready=1")
if v61t_summary.get("v61t_local_checkpoint_materialization_verifier_ready") != "1":
    raise SystemExit("v61bw requires v61t_local_checkpoint_materialization_verifier_ready=1")

for src, rel in [
    (v61bu_summary_path, "source_v61bu/v61bu_ubuntu1_partial_checkpoint_materialization_witness_summary.csv"),
    (results / "v61bu_ubuntu1_partial_checkpoint_materialization_witness_decision.csv", "source_v61bu/v61bu_ubuntu1_partial_checkpoint_materialization_witness_decision.csv"),
    (v61bu_dir / "partial_checkpoint_materialization_witness_rows.csv", "source_v61bu/partial_checkpoint_materialization_witness_rows.csv"),
    (v61bu_dir / "partial_checkpoint_materialization_metric_rows.csv", "source_v61bu/partial_checkpoint_materialization_metric_rows.csv"),
    (v61bu_dir / "sha256_manifest.csv", "source_v61bu/sha256_manifest.csv"),
    (v61t_summary_path, "source_v61t/v61t_local_checkpoint_materialization_verifier_summary.csv"),
    (results / "v61t_local_checkpoint_materialization_verifier_decision.csv", "source_v61t/v61t_local_checkpoint_materialization_verifier_decision.csv"),
    (v61t_dir / "local_checkpoint_materialization_rows.csv", "source_v61t/local_checkpoint_materialization_rows.csv"),
    (v61t_dir / "local_checkpoint_materialization_metric_rows.csv", "source_v61t/local_checkpoint_materialization_metric_rows.csv"),
    (v61q_summary_path, "source_v61q/v61q_real_checkpoint_page_map_summary.csv"),
    (results / "v61q_real_checkpoint_page_map_decision.csv", "source_v61q/v61q_real_checkpoint_page_map_decision.csv"),
    (v61q_dir / "checkpoint_shard_page_summary_rows.csv", "source_v61q/checkpoint_shard_page_summary_rows.csv"),
    (v61q_dir / "checkpoint_unique_page_rows.csv", "source_v61q/checkpoint_unique_page_rows.csv"),
    (v61q_dir / "v61q_real_checkpoint_page_map_manifest.json", "source_v61q/v61q_real_checkpoint_page_map_manifest.json"),
    (v61q_dir / "sha256_manifest.csv", "source_v61q/sha256_manifest.csv"),
]:
    copy(src, rel)

materialization_rows = read_csv(v61t_dir / "local_checkpoint_materialization_rows.csv")
page_rows = read_csv(v61q_dir / "checkpoint_unique_page_rows.csv")
shard_page_summary_rows = read_csv(v61q_dir / "checkpoint_shard_page_summary_rows.csv")
if len(materialization_rows) != 59 or len(shard_page_summary_rows) != 59:
    raise SystemExit("v61bw expects 59-row materialization and shard summary surfaces")

identity_rows = [
    row
    for row in materialization_rows
    if row["local_identity_verified"] == "1" and row["local_file_exists"] == "1"
]
identity_by_shard = {row["shard_name"]: row for row in identity_rows}
pages_by_shard = defaultdict(list)
for row in page_rows:
    if row["shard_name"] in identity_by_shard:
        pages_by_shard[row["shard_name"]].append(row)
for rows in pages_by_shard.values():
    rows.sort(key=lambda item: int(item["shard_page_index"]))

page_hash_rows = []
shard_status_rows = []
total_planned_pages = 0
total_planned_bytes = 0
total_hashed_pages = 0
total_hashed_bytes = 0
cap_exhausted = False

for identity in sorted(identity_rows, key=lambda row: int(row["shard_index"])):
    shard_name = identity["shard_name"]
    local_path = Path(identity["target_path"])
    shard_pages = pages_by_shard[shard_name]
    planned_pages = len(shard_pages)
    planned_bytes = sum(int(page["page_bytes_in_shard"]) for page in shard_pages)
    hashed_pages = 0
    hashed_bytes = 0
    shard_hasher = hashlib.sha256()
    read_status = "identity-verified-local-shard"
    with local_path.open("rb") as handle:
        for page in shard_pages:
            if max_pages > 0 and total_hashed_pages >= max_pages:
                cap_exhausted = True
                break
            page_start = int(page["page_start_byte"])
            page_end = int(page["page_end_byte_exclusive"])
            expected_bytes = int(page["page_bytes_in_shard"])
            handle.seek(page_start)
            data = handle.read(expected_bytes)
            bytes_read = len(data)
            page_hash = sha256_bytes(data) if bytes_read else ""
            verified = int(bytes_read == expected_bytes and page_start + bytes_read == page_end)
            if not verified:
                read_status = "page-read-mismatch"
            else:
                shard_hasher.update(data)
            row_id = f"v61bw:{shard_name}:page:{int(page['shard_page_index']):08d}"
            page_hash_rows.append(
                {
                    "page_hash_witness_row_id": row_id,
                    "model_id": model_id,
                    "shard_index": identity["shard_index"],
                    "shard_name": shard_name,
                    "page_id": page["page_id"],
                    "shard_page_index": page["shard_page_index"],
                    "page_start_byte": page["page_start_byte"],
                    "page_end_byte_exclusive": page["page_end_byte_exclusive"],
                    "page_size_bytes": page["page_size_bytes"],
                    "page_bytes_in_shard": page["page_bytes_in_shard"],
                    "tensor_segment_count": page["tensor_segment_count"],
                    "payload_bytes_mapped": page["payload_bytes_mapped"],
                    "header_or_padding_bytes": page["header_or_padding_bytes"],
                    "target_path": str(local_path),
                    "bytes_read": str(bytes_read),
                    "local_page_sha256": page_hash,
                    "page_hash_verified": str(verified),
                    "local_identity_verified": identity["local_identity_verified"],
                    "checkpoint_payload_bytes_downloaded_by_v61bw": "0",
                    "checkpoint_payload_bytes_committed_to_repo": "0",
                }
            )
            hashed_pages += verified
            hashed_bytes += bytes_read if verified else 0
            total_hashed_pages += verified
            total_hashed_bytes += bytes_read if verified else 0
        total_planned_pages += planned_pages
        total_planned_bytes += planned_bytes
        shard_ready = int(planned_pages > 0 and hashed_pages == planned_pages and hashed_bytes == planned_bytes)
        shard_status_rows.append(
            {
                "model_id": model_id,
                "shard_index": identity["shard_index"],
                "shard_name": shard_name,
                "target_path": str(local_path),
                "expected_bytes": identity["expected_bytes"],
                "actual_bytes": identity["actual_bytes"],
                "local_identity_verified": identity["local_identity_verified"],
                "planned_page_hash_rows": str(planned_pages),
                "hashed_page_rows": str(hashed_pages),
                "planned_page_hash_bytes": str(planned_bytes),
                "hashed_page_bytes": str(hashed_bytes),
                "observed_full_shard_sha256": "sha256:" + shard_hasher.hexdigest() if hashed_pages else "",
                "partial_full_shard_page_hash_ready": str(shard_ready),
                "page_hash_cap_exhausted": str(int(cap_exhausted)),
                "read_status": read_status if not cap_exhausted else "page-hash-cap-exhausted",
                "checkpoint_payload_bytes_downloaded_by_v61bw": "0",
                "checkpoint_payload_bytes_committed_to_repo": "0",
            }
        )

if not shard_status_rows:
    shard_status_rows.append(
        {
            "model_id": model_id,
            "shard_index": "0",
            "shard_name": "none",
            "target_path": warehouse_root,
            "expected_bytes": "0",
            "actual_bytes": "0",
            "local_identity_verified": "0",
            "planned_page_hash_rows": "0",
            "hashed_page_rows": "0",
            "planned_page_hash_bytes": "0",
            "hashed_page_bytes": "0",
            "observed_full_shard_sha256": "",
            "partial_full_shard_page_hash_ready": "0",
            "page_hash_cap_exhausted": "0",
            "read_status": "no-identity-verified-local-shard",
            "checkpoint_payload_bytes_downloaded_by_v61bw": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

page_hash_fields = [
    "page_hash_witness_row_id",
    "model_id",
    "shard_index",
    "shard_name",
    "page_id",
    "shard_page_index",
    "page_start_byte",
    "page_end_byte_exclusive",
    "page_size_bytes",
    "page_bytes_in_shard",
    "tensor_segment_count",
    "payload_bytes_mapped",
    "header_or_padding_bytes",
    "target_path",
    "bytes_read",
    "local_page_sha256",
    "page_hash_verified",
    "local_identity_verified",
    "checkpoint_payload_bytes_downloaded_by_v61bw",
    "checkpoint_payload_bytes_committed_to_repo",
]
write_csv(run_dir / "partial_page_hash_witness_rows.csv", page_hash_fields, page_hash_rows)
write_csv(run_dir / "partial_page_hash_shard_status_rows.csv", list(shard_status_rows[0].keys()), shard_status_rows)

identity_shards = len(identity_rows)
identity_bytes = sum(int(row["actual_bytes"]) for row in identity_rows)
checkpoint_shards = int(v61q_summary["checkpoint_shard_rows"])
total_checkpoint_pages = int(v61q_summary["checkpoint_unique_page_rows"])
total_checkpoint_bytes = int(v61bu_summary["total_checkpoint_bytes_expected"])
partial_full_shard_ready = int(identity_shards > 0 and total_hashed_pages == total_planned_pages and total_hashed_bytes == total_planned_bytes and not cap_exhausted)
full_page_hash_ready = int(total_hashed_pages == total_checkpoint_pages and identity_shards == checkpoint_shards and partial_full_shard_ready)

requirement_rows = [
    {
        "requirement_id": "v61bu-partial-materialization-input",
        "status": "pass",
        "required_value": "v61bu ready",
        "actual_value": v61bu_summary["v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready"],
        "reason": "partial local shard identity witness is bound",
    },
    {
        "requirement_id": "v61q-page-map-input",
        "status": "pass",
        "required_value": "v61q ready",
        "actual_value": v61q_summary["v61q_real_checkpoint_page_map_ready"],
        "reason": "real safetensors page map is bound",
    },
    {
        "requirement_id": "identity-verified-local-shard",
        "status": "pass" if identity_shards > 0 else "blocked",
        "required_value": ">=1 identity verified local shard",
        "actual_value": str(identity_shards),
        "reason": "page hashing only runs on shards accepted by v61t/v61bu identity checks",
    },
    {
        "requirement_id": "partial-full-shard-page-hash-witness",
        "status": "pass" if partial_full_shard_ready else "blocked",
        "required_value": "all pages for each identity shard hashed",
        "actual_value": f"{total_hashed_pages}/{total_planned_pages}",
        "reason": "records local page hashes for every page in resident identity-verified shard(s)",
    },
    {
        "requirement_id": "full-safetensors-page-hash-coverage",
        "status": "pass" if full_page_hash_ready else "blocked",
        "required_value": str(total_checkpoint_pages),
        "actual_value": str(total_hashed_pages),
        "reason": "full coverage waits for every checkpoint shard to be materialized and page-hashed",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0 repo checkpoint payload bytes",
        "actual_value": "0",
        "reason": "v61bw emits page-hash metadata only; checkpoint payload remains outside the repository",
    },
    {
        "requirement_id": "actual-model-generation",
        "status": "blocked",
        "required_value": "materialization + full page hash + generation rows",
        "actual_value": "0",
        "reason": "v61bw is a page-hash witness, not a generation runner",
    },
]
write_csv(run_dir / "partial_page_hash_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bw_ubuntu1_partial_page_hash_witness_metrics",
    "model_id": model_id,
    "v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready": v61bu_summary["v61bu_ubuntu1_partial_checkpoint_materialization_witness_ready"],
    "v61q_real_checkpoint_page_map_ready": v61q_summary["v61q_real_checkpoint_page_map_ready"],
    "target_root_path": warehouse_root,
    "checkpoint_shard_rows": str(checkpoint_shards),
    "total_checkpoint_bytes_expected": str(total_checkpoint_bytes),
    "total_checkpoint_unique_page_rows": str(total_checkpoint_pages),
    "local_identity_verified_shard_rows": str(identity_shards),
    "local_identity_verified_bytes": str(identity_bytes),
    "identity_shard_page_rows": str(total_planned_pages),
    "identity_shard_page_bytes": str(total_planned_bytes),
    "page_hash_witness_rows": str(total_hashed_pages),
    "page_hash_witness_bytes": str(total_hashed_bytes),
    "page_hash_cap_limit": str(max_pages),
    "page_hash_cap_exhausted": str(int(cap_exhausted)),
    "partial_full_shard_page_hash_ready": str(partial_full_shard_ready),
    "full_safetensors_page_hash_binding_ready": str(full_page_hash_ready),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bw": "0",
    "observed_external_checkpoint_payload_bytes": str(identity_bytes),
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "partial_page_hash_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("identity-verified-local-shard", "ready" if identity_shards > 0 else "blocked", f"identity_shards={identity_shards}/59"),
    ("partial-full-shard-page-hash-witness", "ready" if partial_full_shard_ready else "blocked", f"page_hash_witness_rows={total_hashed_pages}/{total_planned_pages}"),
    ("full-safetensors-page-hash-binding", "ready" if full_page_hash_ready else "blocked", f"page_hash_witness_rows={total_hashed_pages}/{total_checkpoint_pages}"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("production-latency", "blocked", "partial page-hash witness is not production latency evidence"),
    ("release-package", "blocked", "no release audit/review evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61bw_ubuntu1_partial_page_hash_witness_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61bu-partial-materialization-input", "status": "pass", "reason": "v61bu partial materialization witness is bound"},
    {"gate": "v61q-page-map-input", "status": "pass", "reason": "v61q page map is bound"},
    {"gate": "identity-verified-local-shard", "status": "pass" if identity_shards > 0 else "blocked", "reason": f"identity_shards={identity_shards}/59"},
    {"gate": "partial-full-shard-page-hash-witness", "status": "pass" if partial_full_shard_ready else "blocked", "reason": f"page_hash_witness_rows={total_hashed_pages}/{total_planned_pages}"},
    {"gate": "full-safetensors-page-hash-binding", "status": "pass" if full_page_hash_ready else "blocked", "reason": f"page_hash_witness_rows={total_hashed_pages}/{total_checkpoint_pages}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61bw writes hash metadata only; checkpoint payload stays outside repo"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bw Ubuntu-1 Partial Page-Hash Witness Boundary

This gate reads identity-verified ubuntu-1 checkpoint shard files and emits
local 2 MiB page-hash rows for the resident shard payload. It does not download
checkpoint payload bytes and does not commit checkpoint payload bytes to the
repository.

Evidence emitted:

- local_identity_verified_shard_rows={identity_shards}
- local_identity_verified_bytes={identity_bytes}
- identity_shard_page_rows={total_planned_pages}
- identity_shard_page_bytes={total_planned_bytes}
- page_hash_witness_rows={total_hashed_pages}
- page_hash_witness_bytes={total_hashed_bytes}
- partial_full_shard_page_hash_ready={partial_full_shard_ready}
- full_safetensors_page_hash_binding_ready={full_page_hash_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bw=0
- observed_external_checkpoint_payload_bytes={identity_bytes}
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: partial ubuntu-1 local page-hash witness over
identity-verified checkpoint shard(s). Blocked wording: full safetensors
page-hash coverage, actual model generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61BW_UBUNTU1_PARTIAL_PAGE_HASH_WITNESS_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bw_ubuntu1_partial_page_hash_witness",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bw_ubuntu1_partial_page_hash_witness_ready": 1,
    "source_v61bu_summary_sha256": sha256(v61bu_summary_path),
    "source_v61q_summary_sha256": sha256(v61q_summary_path),
    "local_identity_verified_shard_rows": identity_shards,
    "local_identity_verified_bytes": identity_bytes,
    "identity_shard_page_rows": total_planned_pages,
    "page_hash_witness_rows": total_hashed_pages,
    "page_hash_witness_bytes": total_hashed_bytes,
    "partial_full_shard_page_hash_ready": partial_full_shard_ready,
    "full_safetensors_page_hash_binding_ready": full_page_hash_ready,
    "checkpoint_payload_bytes_downloaded_by_v61bw": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bw_ubuntu1_partial_page_hash_witness_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bw_ubuntu1_partial_page_hash_witness_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
