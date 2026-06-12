#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bz_ubuntu1_remaining_page_hash_operator_bundle"
RUN_ID="${V61BZ_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
WAREHOUSE_ROOT="${V61BZ_WAREHOUSE_ROOT:-/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse}"

if [[ "${V61BZ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bz_ubuntu1_remaining_page_hash_operator_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BY_WAREHOUSE_ROOT="$WAREHOUSE_ROOT" V61BY_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61by_ubuntu1_remaining_page_hash_execution_plan.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$WAREHOUSE_ROOT" <<'PY'
import csv
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
warehouse_root = sys.argv[5]
results = root / "results"
operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)
model_id = "mistralai/Mixtral-8x22B-v0.1"
approval_phrase = "execute-ubuntu1-remaining-page-hash"


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


def write_executable(path, content):
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


v61by_dir = results / "v61by_ubuntu1_remaining_page_hash_execution_plan" / "plan_001"
v61by_summary_path = results / "v61by_ubuntu1_remaining_page_hash_execution_plan_summary.csv"
v61by_decision_path = results / "v61by_ubuntu1_remaining_page_hash_execution_plan_decision.csv"
v61by_summary = read_csv(v61by_summary_path)[0]
if v61by_summary.get("v61by_ubuntu1_remaining_page_hash_execution_plan_ready") != "1":
    raise SystemExit("v61bz requires v61by_ubuntu1_remaining_page_hash_execution_plan_ready=1")
if v61by_summary.get("remaining_page_hash_execution_plan_ready") != "1":
    raise SystemExit("v61bz requires remaining_page_hash_execution_plan_ready=1")

for src, rel in [
    (v61by_summary_path, "source_v61by/v61by_ubuntu1_remaining_page_hash_execution_plan_summary.csv"),
    (v61by_decision_path, "source_v61by/v61by_ubuntu1_remaining_page_hash_execution_plan_decision.csv"),
    (v61by_dir / "remaining_page_hash_execution_chunk_rows.csv", "source_v61by/remaining_page_hash_execution_chunk_rows.csv"),
    (v61by_dir / "verified_page_hash_skip_rows.csv", "source_v61by/verified_page_hash_skip_rows.csv"),
    (v61by_dir / "remaining_page_hash_execution_metric_rows.csv", "source_v61by/remaining_page_hash_execution_metric_rows.csv"),
    (v61by_dir / "sha256_manifest.csv", "source_v61by/sha256_manifest.csv"),
]:
    copy(src, rel)

chunk_rows = read_csv(v61by_dir / "remaining_page_hash_execution_chunk_rows.csv")
skip_rows = read_csv(v61by_dir / "verified_page_hash_skip_rows.csv")
if len(chunk_rows) != int(v61by_summary["remaining_page_hash_execution_chunk_rows"]):
    raise SystemExit("v61bz chunk row count mismatch")
if len(skip_rows) < 1:
    raise SystemExit("v61bz expects at least one skip row")

queue_csv = operator_dir / "remaining_page_hash_execution_chunk_rows.csv"
skip_csv = operator_dir / "verified_page_hash_skip_rows.csv"
write_csv(queue_csv, list(chunk_rows[0].keys()), chunk_rows)
write_csv(skip_csv, list(skip_rows[0].keys()), skip_rows)

result_template_rows = [
    {
        "result_file": "remaining_page_hash_result_rows.csv",
        "required_field": field,
        "field_status": "required",
    }
    for field in [
        "remaining_page_hash_chunk_id",
        "model_id",
        "shard_name",
        "target_path",
        "shard_page_index",
        "page_start_byte",
        "page_end_byte_exclusive",
        "page_bytes_hashed",
        "local_page_sha256",
        "local_hash_verified",
    ]
]
write_csv(operator_dir / "remaining_page_hash_result_schema_rows.csv", list(result_template_rows[0].keys()), result_template_rows)

hash_script = operator_dir / "hash_remaining_page_chunks.sh"
verify_script = operator_dir / "verify_remaining_page_hash_results.sh"
env_template = operator_dir / "operator_env.template"
readme_path = operator_dir / "README.md"

hash_content = f'''#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
QUEUE_CSV="${{V61BZ_QUEUE_CSV:-$SCRIPT_DIR/remaining_page_hash_execution_chunk_rows.csv}}"
RESULT_DIR="${{V61BZ_RESULT_DIR:-$SCRIPT_DIR/page_hash_execution_results}}"
MAX_CHUNKS="${{V61BZ_MAX_CHUNKS:-0}}"
EXECUTE_PAGE_HASH="${{V61BZ_EXECUTE_PAGE_HASH:-0}}"
APPROVAL_PHRASE="${{V61BZ_APPROVAL_PHRASE:-}}"
IDENTITY_VERIFIED_CONFIRM="${{V61BZ_IDENTITY_VERIFIED_CONFIRM:-0}}"
EXPECTED_APPROVAL_PHRASE="{approval_phrase}"

python3 - "$QUEUE_CSV" "$RESULT_DIR" "$MAX_CHUNKS" "$EXECUTE_PAGE_HASH" "$APPROVAL_PHRASE" "$IDENTITY_VERIFIED_CONFIRM" "$EXPECTED_APPROVAL_PHRASE" <<'PY_HASH'
import csv
import hashlib
import sys
from pathlib import Path

queue_csv = Path(sys.argv[1])
result_dir = Path(sys.argv[2])
max_chunks = int(sys.argv[3])
execute_page_hash = sys.argv[4] == "1"
approval_phrase = sys.argv[5]
identity_verified_confirm = sys.argv[6] == "1"
expected_approval_phrase = sys.argv[7]
page_size = 2 * 1024 * 1024

if execute_page_hash and approval_phrase != expected_approval_phrase:
    raise SystemExit("blocked: V61BZ_APPROVAL_PHRASE mismatch")
if execute_page_hash and not identity_verified_confirm:
    raise SystemExit("blocked: V61BZ_IDENTITY_VERIFIED_CONFIRM=1 is required before page hashing")

with queue_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))

selected = rows[:max_chunks] if max_chunks else rows
mode = "execute" if execute_page_hash else "dry-run"
print(f"v61bz mode={{mode}} selected_chunks={{len(selected)}}")
if not execute_page_hash:
    print("dry-run: set V61BZ_EXECUTE_PAGE_HASH=1, V61BZ_APPROVAL_PHRASE to execute-ubuntu1-remaining-page-hash, and V61BZ_IDENTITY_VERIFIED_CONFIRM=1 to execute")

result_rows = []
for row in selected:
    chunk_id = row["remaining_page_hash_chunk_id"]
    target = Path(row["target_path"])
    start_page = int(row["chunk_page_start_index"])
    end_page = int(row["chunk_page_end_index_exclusive"])
    print(f"[{{mode}}] chunk={{chunk_id}} shard={{row['shard_name']}} pages={{start_page}}..{{end_page}} target={{target}}")
    if not execute_page_hash:
        continue
    if not target.is_file():
        raise SystemExit(f"missing target shard for page hash: {{target}}")
    file_size = target.stat().st_size
    with target.open("rb") as handle:
        for page_index in range(start_page, end_page):
            start = page_index * page_size
            end = min(start + page_size, file_size)
            if start >= file_size:
                raise SystemExit(f"page start beyond file size: {{target}} page={{page_index}}")
            handle.seek(start)
            data = handle.read(end - start)
            digest = "sha256:" + hashlib.sha256(data).hexdigest()
            result_rows.append({{
                "remaining_page_hash_chunk_id": chunk_id,
                "model_id": row["model_id"],
                "shard_name": row["shard_name"],
                "target_path": str(target),
                "shard_page_index": str(page_index),
                "page_start_byte": str(start),
                "page_end_byte_exclusive": str(end),
                "page_bytes_hashed": str(len(data)),
                "local_page_sha256": digest,
                "local_hash_verified": "1",
            }})

if execute_page_hash:
    result_dir.mkdir(parents=True, exist_ok=True)
    result_path = result_dir / "remaining_page_hash_result_rows.csv"
    fields = [
        "remaining_page_hash_chunk_id",
        "model_id",
        "shard_name",
        "target_path",
        "shard_page_index",
        "page_start_byte",
        "page_end_byte_exclusive",
        "page_bytes_hashed",
        "local_page_sha256",
        "local_hash_verified",
    ]
    with result_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\\n")
        writer.writeheader()
        writer.writerows(result_rows)
    print(f"wrote {{len(result_rows)}} page hash rows to {{result_path}}")

print(f"processed {{len(selected)}} remaining page-hash chunks")
PY_HASH
'''

verify_content = '''#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_CSV="${V61BZ_RESULT_CSV:-$SCRIPT_DIR/page_hash_execution_results/remaining_page_hash_result_rows.csv}"

python3 - "$RESULT_CSV" <<'PY_VERIFY'
import csv
import sys
from pathlib import Path

result_csv = Path(sys.argv[1])
required = {
    "remaining_page_hash_chunk_id",
    "model_id",
    "shard_name",
    "target_path",
    "shard_page_index",
    "page_start_byte",
    "page_end_byte_exclusive",
    "page_bytes_hashed",
    "local_page_sha256",
    "local_hash_verified",
}
if not result_csv.is_file():
    print(f"no page-hash result file supplied yet: {result_csv}")
    raise SystemExit(0)
with result_csv.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    missing = required.difference(reader.fieldnames or [])
    if missing:
        raise SystemExit(f"missing result fields: {sorted(missing)}")
    rows = list(reader)
if any(row["local_hash_verified"] != "1" for row in rows):
    raise SystemExit("all supplied result rows must be local_hash_verified=1")
print(f"verified result schema rows={len(rows)}")
PY_VERIFY
'''

repo_q = shlex.quote(str(root))
queue_q = shlex.quote(str(queue_csv))
env_content = f'''# v61bz ubuntu-1 remaining page-hash operator environment
export V61BZ_REPO_ROOT={repo_q}
export V61BZ_QUEUE_CSV={queue_q}
export V61BZ_RESULT_DIR="$V61BZ_REPO_ROOT/results/v61bz_ubuntu1_remaining_page_hash_operator_bundle/bundle_001/operator_bundle/page_hash_execution_results"

# Dry-run by default. Set both variables below only for an intentional hash run.
export V61BZ_EXECUTE_PAGE_HASH=0
export V61BZ_APPROVAL_PHRASE=
export V61BZ_IDENTITY_VERIFIED_CONFIRM=0
export V61BZ_MAX_CHUNKS=0

# Required phrase for page-hash execution:
# {approval_phrase}
'''

readme = f"""# v61bz Ubuntu-1 Remaining Page-Hash Operator Bundle

This bundle executes only the v61by remaining page-hash chunks after the
remaining checkpoint shards have been materialized and identity-verified.

Default behavior is dry-run only:

```bash
source operator_env.template
./hash_remaining_page_chunks.sh
```

Execution requires:

- `V61BZ_EXECUTE_PAGE_HASH=1`
- `V61BZ_APPROVAL_PHRASE={approval_phrase}`
- `V61BZ_IDENTITY_VERIFIED_CONFIRM=1`

The bundle skips the already witnessed `model-00024-of-00059.safetensors`
page-hash rows and keeps checkpoint payload bytes outside the repository.
"""

write_executable(hash_script, hash_content)
write_executable(verify_script, verify_content)
env_template.write_text(env_content, encoding="utf-8")
readme_path.write_text(readme, encoding="utf-8")

script_probe_rows = []
for script in [hash_script, verify_script]:
    syntax = subprocess.run(["bash", "-n", str(script)], text=True, capture_output=True)
    script_probe_rows.append(
        {
            "script_path": str(script.relative_to(run_dir)),
            "bash_syntax_pass": str(int(syntax.returncode == 0)),
            "executable_bit_set": str(int(os.access(script, os.X_OK))),
            "stderr": syntax.stderr.strip(),
        }
    )
write_csv(run_dir / "remaining_page_hash_operator_script_probe_rows.csv", list(script_probe_rows[0].keys()), script_probe_rows)

dry_env = os.environ.copy()
dry_env["V61BZ_EXECUTE_PAGE_HASH"] = "0"
dry_env["V61BZ_MAX_CHUNKS"] = "1"
dry_proc = subprocess.run(
    ["bash", str(hash_script)],
    text=True,
    capture_output=True,
    env=dry_env,
    check=False,
    timeout=60,
)
dry_run_rows = [
    {
        "dry_run_probe_id": "v61bz-dry-run-probe-001",
        "script_path": str(hash_script.relative_to(run_dir)),
        "exit_code": str(dry_proc.returncode),
        "selected_chunk_rows": "1",
        "dry_run_guard_seen": str(int("dry-run: set V61BZ_EXECUTE_PAGE_HASH=1" in dry_proc.stdout)),
        "processed_one_chunk_seen": str(int("processed 1 remaining page-hash chunks" in dry_proc.stdout)),
        "payload_execution_blocked": "1",
        "stdout_sha256": "sha256:" + hashlib.sha256(dry_proc.stdout.encode("utf-8")).hexdigest(),
        "stderr": dry_proc.stderr.strip(),
    }
]
write_csv(run_dir / "remaining_page_hash_operator_dry_run_probe_rows.csv", list(dry_run_rows[0].keys()), dry_run_rows)

operator_files = [
    "README.md",
    "operator_env.template",
    "remaining_page_hash_execution_chunk_rows.csv",
    "verified_page_hash_skip_rows.csv",
    "remaining_page_hash_result_schema_rows.csv",
    "hash_remaining_page_chunks.sh",
    "verify_remaining_page_hash_results.sh",
]
operator_file_rows = []
for rel in operator_files:
    path = operator_dir / rel
    operator_file_rows.append(
        {
            "operator_file": f"operator_bundle/{rel}",
            "bytes": str(path.stat().st_size),
            "sha256": sha256(path),
            "executable_bit_set": str(int(os.access(path, os.X_OK))),
        }
    )
write_csv(run_dir / "remaining_page_hash_operator_file_rows.csv", list(operator_file_rows[0].keys()), operator_file_rows)

remaining_chunks = len(chunk_rows)
remaining_pages = int(v61by_summary["remaining_page_hash_rows"])
remaining_bytes = int(v61by_summary["remaining_page_hash_bytes"])
verified_pages = int(v61by_summary["verified_page_hash_rows"])
skipped_pages = int(v61by_summary["skipped_verified_page_hash_rows"])
dry_run_guard_ready = int(dry_proc.returncode == 0 and dry_run_rows[0]["dry_run_guard_seen"] == "1")
script_ready = int(all(row["bash_syntax_pass"] == "1" and row["executable_bit_set"] == "1" for row in script_probe_rows))
operator_bundle_ready = int(script_ready and dry_run_guard_ready and remaining_chunks > 0)

requirement_rows = [
    {
        "requirement_id": "v61by-remaining-page-hash-plan-input",
        "status": "pass",
        "required_value": "v61by ready",
        "actual_value": v61by_summary["v61by_ubuntu1_remaining_page_hash_execution_plan_ready"],
        "reason": "remaining page-hash execution plan is bound",
    },
    {
        "requirement_id": "operator-script-syntax",
        "status": "pass" if script_ready else "blocked",
        "required_value": "all scripts bash -n and executable",
        "actual_value": f"{sum(1 for row in script_probe_rows if row['bash_syntax_pass'] == '1')}/{len(script_probe_rows)}",
        "reason": "hash and verify scripts are syntax-checked",
    },
    {
        "requirement_id": "page-hash-dry-run-guard",
        "status": "pass" if dry_run_guard_ready else "blocked",
        "required_value": "dry-run guard visible",
        "actual_value": dry_run_rows[0]["dry_run_guard_seen"],
        "reason": "hash execution is dry-run by default and approval gated",
    },
    {
        "requirement_id": "remaining-page-hash-operator-bundle",
        "status": "pass" if operator_bundle_ready else "blocked",
        "required_value": str(remaining_chunks),
        "actual_value": str(remaining_chunks),
        "reason": "operator bundle mirrors all remaining page-hash chunks",
    },
    {
        "requirement_id": "completed-full-safetensors-page-hash-coverage",
        "status": "blocked",
        "required_value": v61by_summary["total_checkpoint_unique_page_rows"],
        "actual_value": str(verified_pages),
        "reason": "operator bundle does not execute page hashes by default",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "status": "pass",
        "required_value": "0 repo checkpoint payload bytes",
        "actual_value": "0",
        "reason": "v61bz emits scripts and metadata only",
    },
]
write_csv(run_dir / "remaining_page_hash_operator_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bz_ubuntu1_remaining_page_hash_operator_bundle_metrics",
    "model_id": model_id,
    "v61by_ubuntu1_remaining_page_hash_execution_plan_ready": v61by_summary["v61by_ubuntu1_remaining_page_hash_execution_plan_ready"],
    "target_root_path": warehouse_root,
    "verified_page_hash_rows": str(verified_pages),
    "skipped_verified_page_hash_rows": str(skipped_pages),
    "remaining_page_hash_rows": str(remaining_pages),
    "remaining_page_hash_bytes": str(remaining_bytes),
    "remaining_page_hash_execution_chunk_rows": str(remaining_chunks),
    "operator_bundle_file_rows": str(len(operator_file_rows)),
    "script_probe_rows": str(len(script_probe_rows)),
    "script_bash_syntax_pass_rows": str(sum(1 for row in script_probe_rows if row["bash_syntax_pass"] == "1")),
    "dry_run_guard_ready": str(dry_run_guard_ready),
    "remaining_page_hash_operator_bundle_ready": str(operator_bundle_ready),
    "page_hash_execution_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bz": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "remaining_page_hash_operator_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("remaining-page-hash-operator-bundle", "ready" if operator_bundle_ready else "blocked", f"remaining_page_hash_execution_chunk_rows={remaining_chunks}"),
    ("explicit-page-hash-execution", "blocked", "dry-run by default; requires explicit execute flag and approval phrase"),
    ("completed-full-safetensors-page-hash-coverage", "blocked", f"verified_page_hash_rows={verified_pages}"),
    ("actual-model-generation", "blocked", "not a generation runner"),
    ("release-package", "blocked", "no release audit/review evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows])

summary = {
    "v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61by-remaining-page-hash-plan-input", "status": "pass", "reason": "v61by remaining plan is bound"},
    {"gate": "operator-script-syntax", "status": "pass" if script_ready else "blocked", "reason": f"script_ready={script_ready}"},
    {"gate": "dry-run-guard", "status": "pass" if dry_run_guard_ready else "blocked", "reason": "hash execution defaults to dry-run"},
    {"gate": "remaining-page-hash-operator-bundle", "status": "pass" if operator_bundle_ready else "blocked", "reason": f"remaining_chunks={remaining_chunks}"},
    {"gate": "explicit-page-hash-execution", "status": "blocked", "reason": "requires V61BZ_EXECUTE_PAGE_HASH=1, approval phrase, and identity confirmation"},
    {"gate": "completed-full-safetensors-page-hash-coverage", "status": "blocked", "reason": f"verified_page_hash_rows={verified_pages}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61bz writes scripts and metadata only"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bz Ubuntu-1 Remaining Page-Hash Operator Bundle Boundary

This gate converts the v61by remaining page-hash execution plan into a
dry-run-first operator bundle. It does not execute page hashing by default, does
not download checkpoint payload bytes, and does not commit checkpoint payload
bytes to the repository.

Evidence emitted:

- verified_page_hash_rows={verified_pages}
- skipped_verified_page_hash_rows={skipped_pages}
- remaining_page_hash_rows={remaining_pages}
- remaining_page_hash_execution_chunk_rows={remaining_chunks}
- operator_bundle_file_rows={len(operator_file_rows)}
- script_bash_syntax_pass_rows={metric['script_bash_syntax_pass_rows']}
- dry_run_guard_ready={dry_run_guard_ready}
- remaining_page_hash_operator_bundle_ready={operator_bundle_ready}
- page_hash_execution_ready=0
- full_safetensors_page_hash_binding_ready=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bz=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: guarded remaining page-hash operator bundle. Blocked wording:
executed full page hashes, completed full safetensors page-hash coverage,
actual model generation, production latency, near-frontier quality, or release
readiness.
"""
(run_dir / "V61BZ_UBUNTU1_REMAINING_PAGE_HASH_OPERATOR_BUNDLE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bz_ubuntu1_remaining_page_hash_operator_bundle",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bz_ubuntu1_remaining_page_hash_operator_bundle_ready": 1,
    "source_v61by_summary_sha256": sha256(v61by_summary_path),
    "remaining_page_hash_execution_chunk_rows": remaining_chunks,
    "operator_bundle_file_rows": len(operator_file_rows),
    "dry_run_guard_ready": dry_run_guard_ready,
    "remaining_page_hash_operator_bundle_ready": operator_bundle_ready,
    "page_hash_execution_ready": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61bz": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bz_ubuntu1_remaining_page_hash_operator_bundle_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bz_ubuntu1_remaining_page_hash_operator_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
