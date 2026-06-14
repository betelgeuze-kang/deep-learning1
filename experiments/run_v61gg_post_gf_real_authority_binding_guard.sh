#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gg_post_gf_real_authority_binding_guard"
RUN_ID="${V61GG_RUN_ID:-guard_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V53_RETURN_ROOT="${V61GG_V53_RETURN_ROOT:-${V61GF_V53_RETURN_ROOT:-}}"
V53_RETURN_PROVENANCE="${V61GG_V53_RETURN_PROVENANCE:-${V61GF_V53_RETURN_PROVENANCE:-unspecified}}"
V61_RETURN_ROOT="${V61GG_V61_RETURN_ROOT:-${V61GF_V61_RETURN_ROOT:-}}"
V61_RETURN_PROVENANCE="${V61GG_V61_RETURN_PROVENANCE:-${V61GF_V61_RETURN_PROVENANCE:-unspecified}}"

if [[ "${V61GG_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gg_post_gf_real_authority_binding_guard_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GF_RUN_ID="${RUN_ID}_gf" \
V61GF_V53_RETURN_ROOT="$V53_RETURN_ROOT" \
V61GF_V53_RETURN_PROVENANCE="$V53_RETURN_PROVENANCE" \
V61GF_V61_RETURN_ROOT="$V61_RETURN_ROOT" \
V61GF_V61_RETURN_PROVENANCE="$V61_RETURN_PROVENANCE" \
V61GF_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gf_post_ge_dual_partial_return_replay_admission.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" "$V53_RETURN_ROOT" "$V53_RETURN_PROVENANCE" "$V61_RETURN_ROOT" "$V61_RETURN_PROVENANCE" <<'PY'
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
run_id = sys.argv[5]
v53_root_arg = sys.argv[6].strip()
v53_provenance = sys.argv[7].strip() or "unspecified"
v61_root_arg = sys.argv[8].strip()
v61_provenance = sys.argv[9].strip() or "unspecified"
results = root / "results"
prefix = "v61gg_post_gf_real_authority_binding_guard"
guard_dir = run_dir / "real_authority_binding_guard"
guard_dir.mkdir(parents=True, exist_ok=True)
gf_run_id = f"{run_id}_gf"
gf_prefix = "v61gf_post_ge_dual_partial_return_replay_admission"
v53_root = Path(v53_root_arg).expanduser().resolve() if v53_root_arg else None
v61_root = Path(v61_root_arg).expanduser().resolve() if v61_root_arg else None


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
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def as_int(row, key):
    try:
        return int(row.get(key, "0") or "0")
    except ValueError:
        return 0


def pass_block(flag):
    return "pass" if flag else "blocked"


def ready_blocked(flag):
    return "ready" if flag else "blocked"


def copy_source(source_id, src, folder):
    dst = run_dir / folder / src.name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return {
        "source_id": source_id,
        "path": dst.relative_to(run_dir).as_posix(),
        "bytes": str(dst.stat().st_size),
        "sha256": sha256(dst),
        "metadata_only": "1",
    }


def safe_relative(root_path, rel_value):
    if not rel_value:
        return None, "authority-path-empty"
    rel = Path(rel_value)
    if rel.is_absolute():
        return None, "authority-path-absolute"
    resolved = (root_path / rel).resolve()
    try:
        resolved.relative_to(root_path)
    except ValueError:
        return None, "authority-path-escapes-root"
    return resolved, ""


def load_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8")), ""
    except FileNotFoundError:
        return {}, "missing-marker"
    except json.JSONDecodeError:
        return {}, "invalid-json"


def validate_authority(root_path, marker_rel, kind):
    root_exists = int(root_path is not None and root_path.is_dir())
    marker_path = root_path / marker_rel if root_exists else None
    marker_exists = int(marker_path is not None and marker_path.is_file())
    errors = []
    payload = {}
    if marker_exists:
        payload, err = load_json(marker_path)
        if err:
            errors.append(err)
    else:
        errors.append("missing-marker")

    if kind == "v53":
        required_provenance = "real-external-return-bundle"
        expected_env = v53_provenance
        allowed_source = {"external-operator-return", "external-review-return"}
        sha_field = "reviewer_authority_sha256"
        path_fields = ["reviewer_authority_path", "authority_statement_path"]
        default_rel = "operator_attestation/reviewer_authority_statement.txt"
    else:
        required_provenance = "real-generation-intake-return-bundle"
        expected_env = v61_provenance
        allowed_source = {"external-generation-intake-return", "external-operator-return", required_provenance}
        sha_field = "generation_operator_authority_sha256"
        path_fields = ["generation_operator_authority_path", "reviewer_authority_path", "authority_statement_path"]
        default_rel = "review_return_provenance/operator_attestation/generation_operator_authority_statement.txt"

    provenance_value = payload.get("provenance") or payload.get("provenance_class")
    source_class = payload.get("source_class") or payload.get("provenance_class", "")
    if expected_env != required_provenance:
        errors.append("env-provenance-mismatch")
    if provenance_value != required_provenance:
        errors.append("marker-provenance-mismatch")
    if str(source_class).startswith("fixture"):
        errors.append("fixture-source-class")
    if source_class not in allowed_source:
        errors.append("source-class-not-allowed")

    expected_sha = payload.get(sha_field, "")
    if kind == "v61" and not expected_sha:
        expected_sha = payload.get("reviewer_authority_sha256", "")
    if not (isinstance(expected_sha, str) and expected_sha.startswith("sha256:")):
        errors.append("authority-sha-missing")

    authority_rel = ""
    for field in path_fields:
        if payload.get(field):
            authority_rel = payload[field]
            break
    if not authority_rel:
        authority_rel = default_rel
    authority_path = None
    authority_error = ""
    if root_exists:
        authority_path, authority_error = safe_relative(root_path, authority_rel)
        if authority_error:
            errors.append(authority_error)
    else:
        errors.append("root-missing")

    authority_exists = int(authority_path is not None and authority_path.is_file())
    authority_sha = ""
    authority_bytes = 0
    if authority_exists:
        authority_sha = sha256(authority_path)
        authority_bytes = authority_path.stat().st_size
        if authority_bytes <= 0:
            errors.append("authority-file-empty")
        try:
            text = authority_path.read_text(encoding="utf-8", errors="replace").lower()
        except OSError:
            text = ""
            errors.append("authority-file-unreadable")
        if "fixture" in text or "synthetic" in text:
            errors.append("authority-file-fixture-text")
        if expected_sha and authority_sha != expected_sha:
            errors.append("authority-sha-mismatch")
    else:
        errors.append("authority-file-missing")

    ready = int(root_exists and marker_exists and authority_exists and not errors)
    return {
        "root_exists": root_exists,
        "marker_exists": marker_exists,
        "authority_exists": authority_exists,
        "ready": ready,
        "marker_path": marker_rel,
        "authority_path": authority_rel,
        "authority_bytes": authority_bytes,
        "authority_sha256": authority_sha,
        "expected_authority_sha256": expected_sha,
        "source_class": str(source_class),
        "errors": ";".join(errors),
    }


source_paths = {
    "v61gf_summary": results / f"{gf_prefix}_summary.csv",
    "v61gf_decision": results / f"{gf_prefix}_decision.csv",
    "v61gf_stage_rows": results / gf_prefix / gf_run_id / "dual_partial_return_replay_admission_stage_rows.csv",
    "v61gf_command_rows": results / gf_prefix / gf_run_id / "dual_partial_return_replay_admission_command_rows.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gg source {label}: {path}")

source_rows = [copy_source(label, path, "source_v61gf") for label, path in source_paths.items()]
write_csv(run_dir / "real_authority_binding_guard_source_rows.csv", list(source_rows[0].keys()), source_rows)

gf = read_csv(source_paths["v61gf_summary"])[0]
if gf.get("v61gf_post_ge_dual_partial_return_replay_admission_ready") != "1":
    raise SystemExit("v61gg requires v61gf ready")

v53_auth = validate_authority(v53_root, "REAL_EXTERNAL_RETURN_PROVENANCE.json", "v53")
v61_auth = validate_authority(v61_root, "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json", "v61")
dual_authority_binding_ready = int(v53_auth["ready"] and v61_auth["ready"])
gf_replay_ready = as_int(gf, "real_return_replay_admission_ready")
authority_bound_replay_admission_ready = int(gf_replay_ready and dual_authority_binding_ready)

authority_rows = [
    {
        "root_id": "v53-external-return-root",
        "root_exists": str(v53_auth["root_exists"]),
        "marker_exists": str(v53_auth["marker_exists"]),
        "marker_path": v53_auth["marker_path"],
        "source_class": v53_auth["source_class"],
        "authority_path": v53_auth["authority_path"],
        "authority_exists": str(v53_auth["authority_exists"]),
        "authority_bytes": str(v53_auth["authority_bytes"]),
        "authority_sha256": v53_auth["authority_sha256"],
        "expected_authority_sha256": v53_auth["expected_authority_sha256"],
        "authority_binding_ready": str(v53_auth["ready"]),
        "errors": v53_auth["errors"],
    },
    {
        "root_id": "v61-generation-intake-return-root",
        "root_exists": str(v61_auth["root_exists"]),
        "marker_exists": str(v61_auth["marker_exists"]),
        "marker_path": v61_auth["marker_path"],
        "source_class": v61_auth["source_class"],
        "authority_path": v61_auth["authority_path"],
        "authority_exists": str(v61_auth["authority_exists"]),
        "authority_bytes": str(v61_auth["authority_bytes"]),
        "authority_sha256": v61_auth["authority_sha256"],
        "expected_authority_sha256": v61_auth["expected_authority_sha256"],
        "authority_binding_ready": str(v61_auth["ready"]),
        "errors": v61_auth["errors"],
    },
]
write_csv(run_dir / "real_authority_binding_guard_rows.csv", list(authority_rows[0].keys()), authority_rows)

stage_rows = [
    {"stage_id": "01-v61gf-source-ready", "status": "ready", "evidence": "v61gf ready"},
    {"stage_id": "02-v53-marker-and-provenance", "status": ready_blocked(v53_auth["marker_exists"] and not any(err in v53_auth["errors"].split(";") for err in ["marker-provenance-mismatch", "env-provenance-mismatch", "fixture-source-class", "source-class-not-allowed"])), "evidence": f"marker_exists={v53_auth['marker_exists']}; source_class={v53_auth['source_class']}; errors={v53_auth['errors']}"},
    {"stage_id": "03-v53-authority-file-binding", "status": ready_blocked(v53_auth["ready"]), "evidence": f"authority_exists={v53_auth['authority_exists']}; sha_match={int(v53_auth['authority_sha256'] == v53_auth['expected_authority_sha256'] and bool(v53_auth['authority_sha256']))}"},
    {"stage_id": "04-v61-marker-and-provenance", "status": ready_blocked(v61_auth["marker_exists"] and not any(err in v61_auth["errors"].split(";") for err in ["marker-provenance-mismatch", "env-provenance-mismatch", "fixture-source-class", "source-class-not-allowed"])), "evidence": f"marker_exists={v61_auth['marker_exists']}; source_class={v61_auth['source_class']}; errors={v61_auth['errors']}"},
    {"stage_id": "05-v61-authority-file-binding", "status": ready_blocked(v61_auth["ready"]), "evidence": f"authority_exists={v61_auth['authority_exists']}; sha_match={int(v61_auth['authority_sha256'] == v61_auth['expected_authority_sha256'] and bool(v61_auth['authority_sha256']))}"},
    {"stage_id": "06-dual-authority-binding", "status": ready_blocked(dual_authority_binding_ready), "evidence": f"dual_authority_binding_ready={dual_authority_binding_ready}"},
    {"stage_id": "07-v61gf-replay-admission", "status": ready_blocked(gf_replay_ready), "evidence": f"real_return_replay_admission_ready={gf_replay_ready}"},
    {"stage_id": "08-authority-bound-replay-admission", "status": ready_blocked(authority_bound_replay_admission_ready), "evidence": f"authority_bound_replay_admission_ready={authority_bound_replay_admission_ready}"},
    {"stage_id": "09-actual-generation", "status": "blocked", "evidence": "authority binding does not prove actual generation"},
]
write_csv(run_dir / "real_authority_binding_guard_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

decision_rows = [
    {"gate": "source-v61gf-ready", "status": "pass", "evidence": "v61gf ready"},
    {"gate": "v53-authority-binding", "status": pass_block(v53_auth["ready"]), "evidence": v53_auth["errors"] or "authority sha bound"},
    {"gate": "v61-authority-binding", "status": pass_block(v61_auth["ready"]), "evidence": v61_auth["errors"] or "authority sha bound"},
    {"gate": "dual-authority-binding", "status": pass_block(dual_authority_binding_ready), "evidence": f"dual_authority_binding_ready={dual_authority_binding_ready}"},
    {"gate": "v61gf-real-return-replay-admission", "status": pass_block(gf_replay_ready), "evidence": f"real_return_replay_admission_ready={gf_replay_ready}"},
    {"gate": "authority-bound-replay-admission", "status": pass_block(authority_bound_replay_admission_ready), "evidence": f"authority_bound_replay_admission_ready={authority_bound_replay_admission_ready}"},
    {"gate": "actual-generation", "status": "blocked", "evidence": "actual_model_generation_ready=0"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

for rel, src in [
    ("REAL_AUTHORITY_BINDING_GUARD_ROWS.csv", run_dir / "real_authority_binding_guard_rows.csv"),
    ("REAL_AUTHORITY_BINDING_GUARD_STAGE_ROWS.csv", run_dir / "real_authority_binding_guard_stage_rows.csv"),
]:
    shutil.copy2(src, guard_dir / rel)

(guard_dir / "VERIFY_REAL_AUTHORITY_BINDING_GUARD.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/REAL_AUTHORITY_BINDING_GUARD_MANIFEST.json\"",
        "test -s \"$DIR/REAL_AUTHORITY_BINDING_GUARD_ROWS.csv\"",
        "test -s \"$DIR/REAL_AUTHORITY_BINDING_GUARD_STAGE_ROWS.csv\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in authority guard package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(guard_dir / "VERIFY_REAL_AUTHORITY_BINDING_GUARD.sh").chmod(0o755)

summary = {
    "v61gg_post_gf_real_authority_binding_guard_ready": 1,
    "v61gf_post_ge_dual_partial_return_replay_admission_ready": 1,
    "v53_authority_marker_exists": v53_auth["marker_exists"],
    "v53_authority_file_exists": v53_auth["authority_exists"],
    "v53_authority_binding_ready": v53_auth["ready"],
    "v61_authority_marker_exists": v61_auth["marker_exists"],
    "v61_authority_file_exists": v61_auth["authority_exists"],
    "v61_authority_binding_ready": v61_auth["ready"],
    "dual_authority_binding_ready": dual_authority_binding_ready,
    "v61gf_row_acceptance_ready": as_int(gf, "row_acceptance_ready"),
    "v61gf_generation_execution_admission_ready": as_int(gf, "generation_execution_admission_ready"),
    "v61gf_dual_external_return_real_ready": as_int(gf, "dual_external_return_real_ready"),
    "v61gf_real_return_replay_admission_ready": gf_replay_ready,
    "v61gf_generation_acceptance_closure_ready": as_int(gf, "generation_acceptance_closure_ready"),
    "authority_bound_replay_admission_ready": authority_bound_replay_admission_ready,
    "actual_model_generation_ready": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61gg": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(row["status"] == "ready" for row in stage_rows),
    "blocked_stage_rows": sum(row["status"] == "blocked" for row in stage_rows),
    "authority_guard_rows": len(authority_rows),
    "source_file_rows": len(source_rows),
    "package_file_rows": 0,
    "metadata_only_package_file_rows": 0,
    "payload_like_package_file_rows": 0,
}

(guard_dir / "REAL_AUTHORITY_BINDING_GUARD_MANIFEST.json").write_text(json.dumps({
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "authority_rows": authority_rows,
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(guard_dir / "REAL_AUTHORITY_BINDING_GUARD.md").write_text(
    "\n".join([
        "# v61gg real authority binding guard",
        "",
        f"- v53_authority_binding_ready={v53_auth['ready']}",
        f"- v61_authority_binding_ready={v61_auth['ready']}",
        f"- dual_authority_binding_ready={dual_authority_binding_ready}",
        f"- v61gf_real_return_replay_admission_ready={gf_replay_ready}",
        f"- authority_bound_replay_admission_ready={authority_bound_replay_admission_ready}",
        "- actual_model_generation_ready=0",
        "",
        "Authority binding requires each real provenance marker to point to a non-empty authority statement file whose SHA-256 exactly matches the marker.",
        "",
    ]),
    encoding="utf-8",
)

package_files = sorted(path for path in guard_dir.rglob("*") if path.is_file())
package_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "real_authority_binding_guard_package_file_rows.csv", list(package_rows[0].keys()), package_rows)
summary["package_file_rows"] = len(package_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

boundary = "\n".join([
    "# V61GG Post-GF Real Authority Binding Guard",
    "",
    "- v61gg_post_gf_real_authority_binding_guard_ready=1",
    f"- v53_authority_binding_ready={v53_auth['ready']}",
    f"- v61_authority_binding_ready={v61_auth['ready']}",
    f"- dual_authority_binding_ready={dual_authority_binding_ready}",
    f"- v61gf_real_return_replay_admission_ready={gf_replay_ready}",
    f"- authority_bound_replay_admission_ready={authority_bound_replay_admission_ready}",
    "- actual_model_generation_ready=0",
    "- checkpoint_payload_bytes_committed_to_repo=0",
    "",
    "Blocked wording: this guard hardens real-root admission by requiring authority statement files bound by SHA-256. It does not itself create review rows, generation rows, production latency, near-frontier quality, v1.0 comparison, or release readiness.",
    "",
])
(run_dir / "V61GG_POST_GF_REAL_AUTHORITY_BINDING_GUARD_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gg": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
    })
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gg_post_gf_real_authority_binding_guard_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
