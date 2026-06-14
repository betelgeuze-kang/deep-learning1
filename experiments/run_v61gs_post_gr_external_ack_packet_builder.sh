#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gs_post_gr_external_ack_packet_builder"
RUN_ID="${V61GS_RUN_ID:-packet_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61GS_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61gs_post_gr_external_ack_packet_builder_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61GR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61gr_post_gq_receipt_bound_external_ack_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RUN_ID" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
run_id = sys.argv[5]
results = root / "results"
prefix = "v61gs_post_gr_external_ack_packet_builder"
package_dir = run_dir / "external_ack_packet_builder"
package_dir.mkdir(parents=True, exist_ok=True)

GR_PREFIX = "v61gr_post_gq_receipt_bound_external_ack_gate"
EXPECTED_ACK = "operator-confirmed-real-external-review-and-generation-return"
EXPECTED_SCOPE = "first-real-slice-dual-replay"
ALLOWED_SOURCE_CLASSES = {"external-operator-return-ack", "external-review-and-generation-return-ack"}
NONFINAL_TOKENS = ["replace_with", "template", "fixture", "synthetic", "dry run", "sample", "example"]


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


def is_inside(child, parent):
    try:
        child.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def has_nonfinal_text(value):
    lowered = str(value).lower()
    return any(token in lowered for token in NONFINAL_TOKENS)


def valid_sha(value):
    return isinstance(value, str) and value.startswith("sha256:") and len(value) == 71 and all(c in "0123456789abcdef" for c in value[7:])


def validate_ack(ack_path, receipt_sha, root_id):
    errors = []
    payload = {}
    if ack_path is None:
        return payload, ["missing-ack-file"]
    if not ack_path.is_file():
        return payload, ["missing-ack-file"]
    try:
        payload = json.loads(ack_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return payload, ["invalid-json"]
    source_class = str(payload.get("acknowledgement_source_class", ""))
    statement = str(payload.get("external_return_authority_statement", ""))
    if source_class not in ALLOWED_SOURCE_CLASSES or has_nonfinal_text(source_class):
        errors.append("source-class-not-accepted")
    if payload.get("external_return_authority_ack") != EXPECTED_ACK:
        errors.append("ack-value-mismatch")
    if payload.get("ack_scope") != EXPECTED_SCOPE:
        errors.append("ack-scope-mismatch")
    if len(statement) < 80 or has_nonfinal_text(statement):
        errors.append("ack-statement-not-final")
    if payload.get("operator_input_receipt_sha256") != receipt_sha or not valid_sha(receipt_sha):
        errors.append("receipt-sha-mismatch")
    bound_root_id = str(payload.get("operator_input_root_id", ""))
    if bound_root_id and root_id and bound_root_id != root_id:
        errors.append("root-id-mismatch")
    return payload, errors


source_paths = {
    "v61gr_summary": results / f"{GR_PREFIX}_summary.csv",
    "v61gr_decision": results / f"{GR_PREFIX}_decision.csv",
}
for label, path in source_paths.items():
    if not path.is_file():
        raise SystemExit(f"missing v61gs source {label}: {path}")

source_rows = [copy_source(label, path, "source_v61gr") for label, path in source_paths.items()]
write_csv(run_dir / "external_ack_packet_builder_source_rows.csv", list(source_rows[0].keys()), source_rows)

gr = read_csv(source_paths["v61gr_summary"])[0]
if gr.get("v61gr_post_gq_receipt_bound_external_ack_gate_ready") != "1":
    raise SystemExit("v61gs requires v61gr ready")

operator_root_raw = os.environ.get("V61GS_OPERATOR_INPUT_ROOT", os.environ.get("V61GR_OPERATOR_INPUT_ROOT", os.environ.get("V61GI_OPERATOR_INPUT_ROOT", ""))).strip()
ack_file_raw = os.environ.get("V61GS_EXTERNAL_ACK_FILE", os.environ.get("V61GR_EXTERNAL_ACK_FILE", "")).strip()
operator_root = Path(operator_root_raw).expanduser().resolve() if operator_root_raw else None
ack_file = Path(ack_file_raw).expanduser().resolve() if ack_file_raw else None
operator_root_supplied = int(operator_root is not None)
operator_root_exists = int(operator_root is not None and operator_root.is_dir())
operator_root_outside_repo = int(operator_root is not None and not is_inside(operator_root, root))
ack_file_supplied = int(ack_file is not None)
ack_file_exists = int(ack_file is not None and ack_file.is_file())
ack_file_outside_repo = int(ack_file is not None and not is_inside(ack_file, root))

receipt_path = operator_root / "OPERATOR_INPUT_RECEIPT.json" if operator_root else None
receipt_exists = int(receipt_path is not None and receipt_path.is_file())
receipt_sha = sha256(receipt_path) if receipt_exists else ""
receipt_root_id = ""
if receipt_exists:
    try:
        receipt_root_id = json.loads(receipt_path.read_text(encoding="utf-8")).get("operator_input_root_id", "")
    except json.JSONDecodeError:
        receipt_root_id = ""

ack_payload, ack_errors = validate_ack(ack_file, receipt_sha, receipt_root_id)
ack_file_preflight_ready = int(ack_file_exists and ack_file_outside_repo and receipt_exists and not ack_errors)

template_payload = {
    "acknowledgement_source_class": "external-operator-return-ack",
    "ack_scope": EXPECTED_SCOPE,
    "external_return_authority_ack": EXPECTED_ACK,
    "external_return_authority_statement": "REPLACE_WITH_FINAL_EXTERNAL_OPERATOR_STATEMENT_AT_LEAST_80_CHARS",
    "operator_input_receipt_sha256": receipt_sha or "REPLACE_WITH_OPERATOR_INPUT_RECEIPT_SHA256",
    "operator_input_root_id": receipt_root_id or "REPLACE_WITH_OPERATOR_INPUT_ROOT_ID",
}
(package_dir / "EXTERNAL_ACK.json.template").write_text(json.dumps(template_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

schema_payload = {
    "required": [
        "acknowledgement_source_class",
        "ack_scope",
        "external_return_authority_ack",
        "external_return_authority_statement",
        "operator_input_receipt_sha256",
        "operator_input_root_id",
    ],
    "expected_external_return_authority_ack": EXPECTED_ACK,
    "expected_ack_scope": EXPECTED_SCOPE,
    "allowed_acknowledgement_source_class": sorted(ALLOWED_SOURCE_CLASSES),
    "operator_input_receipt_sha256": receipt_sha,
    "operator_input_root_id": receipt_root_id,
    "nonfinal_tokens_rejected": NONFINAL_TOKENS,
}
(package_dir / "EXTERNAL_ACK_SCHEMA.json").write_text(json.dumps(schema_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

(package_dir / "VALIDATE_EXTERNAL_ACK_FILE.py").write_text(
    "\n".join([
        "#!/usr/bin/env python3",
        "import json, os, sys",
        "from pathlib import Path",
        "",
        f"EXPECTED_ACK = {EXPECTED_ACK!r}",
        f"EXPECTED_SCOPE = {EXPECTED_SCOPE!r}",
        f"ALLOWED_SOURCE_CLASSES = {sorted(ALLOWED_SOURCE_CLASSES)!r}",
        f"NONFINAL_TOKENS = {NONFINAL_TOKENS!r}",
        f"RECEIPT_SHA = {receipt_sha!r}",
        f"ROOT_ID = {receipt_root_id!r}",
        "",
        "def has_nonfinal_text(value):",
        "    lowered = str(value).lower()",
        "    return any(token in lowered for token in NONFINAL_TOKENS)",
        "",
        "ack_raw = os.environ.get('V61GS_EXTERNAL_ACK_FILE', '').strip()",
        "if not ack_raw:",
        "    raise SystemExit('set V61GS_EXTERNAL_ACK_FILE')",
        "path = Path(ack_raw).expanduser()",
        "if not path.is_file():",
        "    raise SystemExit('missing external ack file')",
        "payload = json.loads(path.read_text(encoding='utf-8'))",
        "errors = []",
        "if payload.get('acknowledgement_source_class') not in ALLOWED_SOURCE_CLASSES or has_nonfinal_text(payload.get('acknowledgement_source_class', '')):",
        "    errors.append('source-class-not-accepted')",
        "if payload.get('external_return_authority_ack') != EXPECTED_ACK:",
        "    errors.append('ack-value-mismatch')",
        "if payload.get('ack_scope') != EXPECTED_SCOPE:",
        "    errors.append('ack-scope-mismatch')",
        "statement = str(payload.get('external_return_authority_statement', ''))",
        "if len(statement) < 80 or has_nonfinal_text(statement):",
        "    errors.append('ack-statement-not-final')",
        "if payload.get('operator_input_receipt_sha256') != RECEIPT_SHA:",
        "    errors.append('receipt-sha-mismatch')",
        "if ROOT_ID and payload.get('operator_input_root_id') != ROOT_ID:",
        "    errors.append('root-id-mismatch')",
        "if errors:",
        "    raise SystemExit('external ack invalid: ' + ';'.join(errors))",
        "print('external ack validates against receipt')",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VALIDATE_EXTERNAL_ACK_FILE.py").chmod(0o755)

ack_rows = [{
    "ack_file_supplied": str(ack_file_supplied),
    "ack_file_exists": str(ack_file_exists),
    "ack_file_outside_repo": str(ack_file_outside_repo),
    "ack_file_sha256": sha256(ack_file) if ack_file_exists else "",
    "operator_input_root_supplied": str(operator_root_supplied),
    "operator_input_root_exists": str(operator_root_exists),
    "operator_input_root_outside_repo": str(operator_root_outside_repo),
    "operator_input_receipt_exists": str(receipt_exists),
    "operator_input_receipt_sha256": receipt_sha,
    "operator_input_root_id": receipt_root_id,
    "ack_file_preflight_ready": str(ack_file_preflight_ready),
    "errors": ";".join(ack_errors),
}]
write_csv(run_dir / "external_ack_packet_preflight_rows.csv", list(ack_rows[0].keys()), ack_rows)

command_rows = [
    {"command_id": "01-verify-ack-packet", "ready_to_run_now": "1", "command": "results/v61gs_post_gr_external_ack_packet_builder/packet_001/external_ack_packet_builder/VERIFY_EXTERNAL_ACK_PACKET_BUILDER.sh", "purpose": "verify this ack packet"},
    {"command_id": "02-print-ready-commands", "ready_to_run_now": "1", "command": "results/v61gs_post_gr_external_ack_packet_builder/packet_001/external_ack_packet_builder/READY_NOW_COMMANDS.sh", "purpose": "show ack validation command"},
    {"command_id": "03-validate-external-ack-file", "ready_to_run_now": str(ack_file_preflight_ready), "command": "V61GS_EXTERNAL_ACK_FILE=<ack.json> results/v61gs_post_gr_external_ack_packet_builder/packet_001/external_ack_packet_builder/VALIDATE_EXTERNAL_ACK_FILE.py", "purpose": "validate external ack file against materialized receipt"},
    {"command_id": "04-run-receipt-bound-gate", "ready_to_run_now": str(ack_file_preflight_ready), "command": "V61GR_OPERATOR_INPUT_ROOT=<operator-input-root> V61GR_OUTPUT_ROOT=<output-root> V61GR_EXTERNAL_ACK_FILE=<ack.json> ./experiments/run_v61gr_post_gq_receipt_bound_external_ack_gate.sh", "purpose": "run v61gr after ack packet validation"},
]
write_csv(run_dir / "external_ack_packet_command_rows.csv", list(command_rows[0].keys()), command_rows)

(package_dir / "EXTERNAL_ACK_PACKET_PREFLIGHT_ROWS.csv").write_text((run_dir / "external_ack_packet_preflight_rows.csv").read_text(encoding="utf-8"), encoding="utf-8")
(package_dir / "EXTERNAL_ACK_PACKET_COMMAND_ROWS.csv").write_text((run_dir / "external_ack_packet_command_rows.csv").read_text(encoding="utf-8"), encoding="utf-8")

(package_dir / "VERIFY_EXTERNAL_ACK_PACKET_BUILDER.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
        "test -s \"$DIR/EXTERNAL_ACK_SCHEMA.json\"",
        "test -s \"$DIR/EXTERNAL_ACK.json.template\"",
        "test -x \"$DIR/VALIDATE_EXTERNAL_ACK_FILE.py\"",
        "test -s \"$DIR/EXTERNAL_ACK_PACKET_PREFLIGHT_ROWS.csv\"",
        "test -s \"$DIR/EXTERNAL_ACK_PACKET_COMMAND_ROWS.csv\"",
        "test -s \"$DIR/EXTERNAL_ACK_PACKET_BUILDER_MANIFEST.json\"",
        "if find \"$DIR\" -type f \\( -name '*.safetensors' -o -name '*.gguf' -o -name '*.bin' -o -name '*.pt' -o -name '*.pth' \\) | grep -q .; then",
        "  echo 'payload-like file in v61gs package' >&2",
        "  exit 1",
        "fi",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "VERIFY_EXTERNAL_ACK_PACKET_BUILDER.sh").chmod(0o755)

(package_dir / "READY_NOW_COMMANDS.sh").write_text(
    "\n".join([
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "echo 'Fill EXTERNAL_ACK.json.template outside the repo, then validate:'",
        "echo 'V61GS_OPERATOR_INPUT_ROOT=<operator-input-root> V61GS_EXTERNAL_ACK_FILE=<ack.json> ./experiments/run_v61gs_post_gr_external_ack_packet_builder.sh'",
        "echo 'V61GS_EXTERNAL_ACK_FILE=<ack.json> results/v61gs_post_gr_external_ack_packet_builder/packet_001/external_ack_packet_builder/VALIDATE_EXTERNAL_ACK_FILE.py'",
        "",
    ]),
    encoding="utf-8",
)
(package_dir / "READY_NOW_COMMANDS.sh").chmod(0o755)

summary = {
    "v61gs_post_gr_external_ack_packet_builder_ready": 1,
    "v61gr_post_gq_receipt_bound_external_ack_gate_ready": 1,
    "contains_real_external_evidence": 0,
    "operator_input_root_supplied": operator_root_supplied,
    "operator_input_root_exists": operator_root_exists,
    "operator_input_root_outside_repo": operator_root_outside_repo,
    "operator_input_receipt_exists": receipt_exists,
    "operator_input_receipt_sha256": receipt_sha,
    "operator_input_root_id": receipt_root_id,
    "ack_file_supplied": ack_file_supplied,
    "ack_file_exists": ack_file_exists,
    "ack_file_outside_repo": ack_file_outside_repo,
    "ack_file_preflight_ready": ack_file_preflight_ready,
    "ack_template_bound_to_receipt": int(receipt_exists and bool(receipt_sha)),
    "schema_file_rows": 1,
    "template_file_rows": 1,
    "command_rows": len(command_rows),
    "ready_command_rows": sum(row["ready_to_run_now"] == "1" for row in command_rows),
    "blocked_command_rows": sum(row["ready_to_run_now"] == "0" for row in command_rows),
    "real_external_review_return_rows": 0,
    "real_generation_result_artifacts": 0,
    "dual_external_return_real_ready": 0,
    "real_return_replay_admission_ready": 0,
    "generation_acceptance_closure_ready": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61gs": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}

manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "expected_external_ack": EXPECTED_ACK,
    "expected_scope": EXPECTED_SCOPE,
    "summary": summary,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(package_dir / "EXTERNAL_ACK_PACKET_BUILDER_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

package_files = sorted(path for path in package_dir.rglob("*") if path.is_file())
package_file_rows = []
for path in package_files:
    payload_like = int(path.suffix.lower() in {".safetensors", ".gguf", ".bin", ".pt", ".pth"})
    package_file_rows.append({
        "path": path.relative_to(run_dir).as_posix(),
        "bytes": str(path.stat().st_size),
        "sha256": sha256(path),
        "metadata_only": str(int(not payload_like)),
        "payload_like": str(payload_like),
    })
write_csv(run_dir / "external_ack_packet_package_file_rows.csv", list(package_file_rows[0].keys()), package_file_rows)
summary["package_file_rows"] = len(package_file_rows)
summary["metadata_only_package_file_rows"] = sum(row["metadata_only"] == "1" for row in package_file_rows)
summary["payload_like_package_file_rows"] = sum(row["payload_like"] == "1" for row in package_file_rows)
write_csv(summary_csv, list(summary.keys()), [summary])
write_csv(run_dir / f"{prefix}_summary.csv", list(summary.keys()), [summary])

decision_rows = [
    {"gate": "source-v61gr-ready", "status": "pass", "evidence": "v61gr ready"},
    {"gate": "operator-input-root", "status": "pass" if operator_root_exists and operator_root_outside_repo else "blocked", "evidence": f"exists={operator_root_exists}; outside_repo={operator_root_outside_repo}"},
    {"gate": "operator-input-receipt", "status": "pass" if receipt_exists else "blocked", "evidence": f"receipt_exists={receipt_exists}"},
    {"gate": "ack-template-bound-to-receipt", "status": "pass" if receipt_exists else "blocked", "evidence": f"receipt_sha={receipt_sha}"},
    {"gate": "ack-file-preflight", "status": "pass" if ack_file_preflight_ready else "blocked", "evidence": ";".join(ack_errors) or "ack valid"},
    {"gate": "real-counter-unchanged", "status": "pass", "evidence": "packet builder never executes replay"},
    {"gate": "zero-repo-checkpoint-payload", "status": "pass", "evidence": "checkpoint_payload_bytes_committed_to_repo=0"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)
write_csv(run_dir / f"{prefix}_decision.csv", list(decision_rows[0].keys()), decision_rows)

(run_dir / "V61GS_POST_GR_EXTERNAL_ACK_PACKET_BUILDER_BOUNDARY.md").write_text(
    "\n".join([
        "# V61GS Post-GR External Ack Packet Builder",
        "",
        "- v61gs_post_gr_external_ack_packet_builder_ready=1",
        f"- ack_template_bound_to_receipt={summary['ack_template_bound_to_receipt']}",
        f"- ack_file_preflight_ready={ack_file_preflight_ready}",
        "- real_external_review_return_rows=0",
        "- real_generation_result_artifacts=0",
        "- actual_model_generation_ready=0",
        "- checkpoint_payload_bytes_committed_to_repo=0",
        "",
    ]),
    encoding="utf-8",
)

top_manifest = {
    "artifact": prefix,
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "summary": summary,
    "decisions": decision_rows,
    "checkpoint_payload_bytes_downloaded_by_v61gs": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
    "route_jump_rows": 0,
}
(run_dir / f"{prefix}_manifest.json").write_text(json.dumps(top_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

hash_rows = []
for path in sorted(p for p in run_dir.rglob("*") if p.is_file() and p.name != "sha256_manifest.csv"):
    hash_rows.append({"path": path.relative_to(run_dir).as_posix(), "bytes": str(path.stat().st_size), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", list(hash_rows[0].keys()), hash_rows)

print(f"v61gs_post_gr_external_ack_packet_builder_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
