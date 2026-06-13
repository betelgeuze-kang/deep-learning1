#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fj_post_fi_real_manifest_external_review_send_return_bundle"
RUN_ID="${V61FJ_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FJ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fj_post_fi_real_manifest_external_review_send_return_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh" >/dev/null
V61FH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null
V61FG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fg_post_ff_real_manifest_external_review_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
bundle_dir = run_dir / "real_manifest_external_review_send_return_bundle"
review_packet_dir = bundle_dir / "review_packet"
return_scaffold_dir = bundle_dir / "return_scaffold"
review_packet_dir.mkdir(parents=True, exist_ok=True)
return_scaffold_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_hex(path):
    return sha256(path).split(":", 1)[1]


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
    return dst


sources = {
    "v61fi": {
        "summary": results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_summary.csv",
        "decision": results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_decision.csv",
        "dir": results / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge" / "bridge_001",
        "ready_field": "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready",
    },
    "v61fh": {
        "summary": results / "v61fh_post_fg_real_manifest_external_review_return_intake_summary.csv",
        "decision": results / "v61fh_post_fg_real_manifest_external_review_return_intake_decision.csv",
        "dir": results / "v61fh_post_fg_real_manifest_external_review_return_intake" / "intake_001",
        "ready_field": "v61fh_post_fg_real_manifest_external_review_return_intake_ready",
    },
    "v61fg": {
        "summary": results / "v61fg_post_ff_real_manifest_external_review_packet_summary.csv",
        "decision": results / "v61fg_post_ff_real_manifest_external_review_packet_decision.csv",
        "dir": results / "v61fg_post_ff_real_manifest_external_review_packet" / "packet_001",
        "ready_field": "v61fg_post_ff_real_manifest_external_review_packet_ready",
    },
}

summaries = {}
for label, spec in sources.items():
    if not spec["summary"].is_file():
        raise SystemExit(f"missing v61fj source summary: {spec['summary']}")
    summaries[label] = read_csv(spec["summary"])[0]
    if summaries[label].get(spec["ready_field"]) != "1":
        raise SystemExit(f"v61fj requires {label} {spec['ready_field']}=1")
    copy(spec["summary"], f"source_{label}/{spec['summary'].name}")
    if spec["decision"].is_file():
        copy(spec["decision"], f"source_{label}/{spec['decision'].name}")

for label, rel in [
    ("v61fi", "post_fh_real_manifest_external_review_acceptance_bridge_rows.csv"),
    ("v61fi", "post_fh_real_manifest_external_review_acceptance_blocker_rows.csv"),
    ("v61fh", "real_manifest_external_review_required_artifact_rows.csv"),
    ("v61fh", "real_manifest_external_review_return_intake/REQUIRED_REVIEW_RETURN_ARTIFACTS.csv"),
    ("v61fg", "post_ff_real_manifest_external_review_checklist_rows.csv"),
]:
    copy(sources[label]["dir"] / rel, f"source_{label}/{rel}")

v61fi = summaries["v61fi"]
v61fh = summaries["v61fh"]
v61fg = summaries["v61fg"]

packet_src = sources["v61fg"]["dir"] / "real_manifest_external_review_packet"
packet_files = sorted(path for path in packet_src.rglob("*") if path.is_file())
for src in packet_files:
    rel = src.relative_to(packet_src)
    dst = review_packet_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)

required_artifacts = read_csv(sources["v61fh"]["dir"] / "real_manifest_external_review_required_artifact_rows.csv")
template_rows = []
for artifact in required_artifacts:
    rel = artifact["relative_path"]
    template_name = rel + ".template"
    template_path = return_scaffold_dir / template_name
    template_path.parent.mkdir(parents=True, exist_ok=True)
    fields = artifact["required_fields"].split(";")
    if artifact["artifact_type"] == "csv":
        template_path.write_text(",".join(fields) + "\n", encoding="utf-8")
    else:
        payload = {field: f"fill-real-{field}" for field in fields}
        payload["template_only_not_evidence"] = True
        payload["expected_artifact"] = rel
        template_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    template_rows.append(
        {
            "artifact_id": artifact["artifact_id"],
            "expected_return_artifact": rel,
            "template_artifact": str(Path("return_scaffold") / template_name),
            "artifact_type": artifact["artifact_type"],
            "required_rows": artifact["required_rows"],
            "required_fields": artifact["required_fields"],
            "template_file_ready": "1",
            "accepted_by_default": "0",
        }
    )
write_csv(run_dir / "post_fi_real_manifest_external_review_return_template_rows.csv", list(template_rows[0].keys()), template_rows)
write_csv(bundle_dir / "RETURN_TEMPLATE_ROWS.csv", list(template_rows[0].keys()), template_rows)

instructions = bundle_dir / "SEND_RETURN_BUNDLE_README.md"
instructions.write_text(
    "\n".join(
        [
            "# v61fj Real Manifest External Review Send/Return Bundle",
            "",
            "This bundle sends the v61fg zero-payload review packet together with",
            "template-only return scaffolds for v61fh. It is not accepted review",
            "evidence and contains no checkpoint payload bytes.",
            "",
            "Reviewer steps:",
            "",
            "1. Run `./VERIFY_SEND_RETURN_BUNDLE.sh`.",
            "2. Inspect `review_packet/`.",
            "3. Copy files from `return_scaffold/*.template` into a real return directory without the `.template` suffix.",
            "4. Fill every required field with real review evidence.",
            "5. Return the filled directory to `V61FH_EXTERNAL_REVIEW_RETURN_DIR`.",
            "",
            "Blocked claims:",
            "- external_review_return_ready=0 until real return evidence is supplied and accepted.",
            "- actual_model_generation_ready=0.",
            "- production latency, near-frontier quality, and release readiness remain blocked.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61fj-post-fi-real-manifest-external-review-send-return-bundle",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "review_packet_files": len(packet_files),
    "return_template_files": len(template_rows),
    "required_review_return_artifacts": int(v61fh["required_review_return_artifacts"]),
    "send_return_bundle_ready": 1,
    "external_review_return_ready": int(v61fi["external_review_return_ready"]),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(bundle_dir / "SEND_RETURN_BUNDLE_MANIFEST.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

verify_script = bundle_dir / "VERIFY_SEND_RETURN_BUNDLE.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'cd "$(dirname "$0")"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "import hashlib",
            "import json",
            "from pathlib import Path",
            "",
            "root = Path('.')",
            "for line in (root / 'SEND_RETURN_BUNDLE_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "manifest = json.loads((root / 'SEND_RETURN_BUNDLE_MANIFEST.json').read_text(encoding='utf-8'))",
            "templates = list(csv.DictReader((root / 'RETURN_TEMPLATE_ROWS.csv').open(newline='', encoding='utf-8')))",
            "if len(templates) != manifest['return_template_files']:",
            "    raise SystemExit('template row count mismatch')",
            "if any(row['accepted_by_default'] != '0' for row in templates):",
            "    raise SystemExit('templates must not be accepted by default')",
            "if manifest['external_review_return_ready'] != 0:",
            "    raise SystemExit('external review return must remain blocked')",
            "if manifest['actual_model_generation_ready'] != 0:",
            "    raise SystemExit('actual generation must remain blocked')",
            "if manifest['checkpoint_payload_bytes_committed_to_repo'] != 0:",
            "    raise SystemExit('checkpoint payload must remain zero')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

bundle_file_list = sorted(
    str(path.relative_to(bundle_dir))
    for path in bundle_dir.rglob("*")
    if path.is_file() and path.name not in {"SEND_RETURN_BUNDLE_FILE_LIST.txt", "SEND_RETURN_BUNDLE_SHA256SUMS.txt"}
)
(bundle_dir / "SEND_RETURN_BUNDLE_FILE_LIST.txt").write_text("\n".join(bundle_file_list) + "\n", encoding="utf-8")
sha_targets = sorted(path for path in bundle_dir.rglob("*") if path.is_file() and path.name != "SEND_RETURN_BUNDLE_SHA256SUMS.txt")
(bundle_dir / "SEND_RETURN_BUNDLE_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(bundle_dir)}\n" for path in sha_targets),
    encoding="utf-8",
)

bundle_file_rows = []
for path in sorted(bundle_dir.rglob("*")):
    if path.is_file():
        rel = str(path.relative_to(bundle_dir))
        bundle_file_rows.append(
            {
                "bundle_file": rel,
                "size_bytes": str(path.stat().st_size),
                "sha256": sha256(path),
                "review_packet_file": "1" if rel.startswith("review_packet/") else "0",
                "return_template_file": "1" if rel.startswith("return_scaffold/") else "0",
                "payload_like_file": "1" if path.suffix in {".safetensors", ".bin", ".pt"} else "0",
                "accepted_by_default": "0" if rel.startswith("return_scaffold/") else "",
            }
        )
write_csv(run_dir / "post_fi_real_manifest_external_review_send_return_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

requirement_rows = [
    {"requirement_id": "v61fi-acceptance-bridge-input", "status": "pass", "required_value": "1", "actual_value": v61fi["v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready"], "reason": "v61fi bridge is ready"},
    {"requirement_id": "review-packet-files-copied", "status": "pass", "required_value": v61fg["packet_file_rows"], "actual_value": str(len(packet_files)), "reason": "v61fg review packet copied into send bundle"},
    {"requirement_id": "return-template-files-created", "status": "pass", "required_value": v61fh["required_review_return_artifacts"], "actual_value": str(len(template_rows)), "reason": "one template per required review-return artifact"},
    {"requirement_id": "templates-not-accepted-evidence", "status": "pass", "required_value": "0 accepted_by_default", "actual_value": str(sum(row["accepted_by_default"] == "1" for row in template_rows)), "reason": "templates are scaffold only"},
    {"requirement_id": "external-review-return", "status": "blocked", "required_value": "1", "actual_value": v61fi["external_review_return_ready"], "reason": "real review return not supplied"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": "0", "reason": "actual generation remains blocked"},
]
write_csv(run_dir / "post_fi_real_manifest_external_review_send_return_bundle_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

summary = {
    "v61fj_post_fi_real_manifest_external_review_send_return_bundle_ready": "1",
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready": v61fi["v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready"],
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": v61fh["v61fh_post_fg_real_manifest_external_review_return_intake_ready"],
    "v61fg_post_ff_real_manifest_external_review_packet_ready": v61fg["v61fg_post_ff_real_manifest_external_review_packet_ready"],
    "send_return_bundle_ready": "1",
    "review_packet_files": str(len(packet_files)),
    "return_template_files": str(len(template_rows)),
    "bundle_file_rows": str(len(bundle_file_rows)),
    "metadata_only_bundle_file_rows": str(len(bundle_file_rows)),
    "payload_like_bundle_file_rows": str(sum(row["payload_like_file"] == "1" for row in bundle_file_rows)),
    "required_review_return_artifacts": v61fh["required_review_return_artifacts"],
    "accepted_review_return_artifacts": v61fh["accepted_review_return_artifacts"],
    "missing_review_return_artifacts": v61fh["missing_review_return_artifacts"],
    "candidate_external_review_return_ready": v61fi["candidate_external_review_return_ready"],
    "external_review_return_ready": v61fi["external_review_return_ready"],
    "real_return_replay_admission_ready": v61fi["real_return_replay_admission_ready"],
    "row_acceptance_ready": v61fi["row_acceptance_ready"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["requirement_id"], "status": row["status"], "reason": row["reason"]}
    for row in requirement_rows
]
decision_rows.append({"gate": "repo-checkpoint-payload", "status": "pass", "reason": "send-return bundle is metadata/template only"})
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = run_dir / "V61FJ_POST_FI_REAL_MANIFEST_EXTERNAL_REVIEW_SEND_RETURN_BUNDLE_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fj Post-v61fi Real Manifest External Review Send/Return Bundle Boundary",
            "",
            f"- send_return_bundle_ready={summary['send_return_bundle_ready']}",
            f"- review_packet_files={summary['review_packet_files']}",
            f"- return_template_files={summary['return_template_files']}",
            f"- bundle_file_rows={summary['bundle_file_rows']}",
            f"- required_review_return_artifacts={summary['required_review_return_artifacts']}",
            f"- accepted_review_return_artifacts={summary['accepted_review_return_artifacts']}/{summary['required_review_return_artifacts']}",
            f"- external_review_return_ready={summary['external_review_return_ready']}",
            f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={summary['row_acceptance_ready']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fj creates a zero-payload reviewer send/return scaffold bundle.",
            "",
            "Blocked wording:",
            "- Do not claim accepted external review, replay admission, row acceptance, actual generation, latency, quality, or release readiness from v61fj alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

run_manifest = {
    "artifact": "v61fj_post_fi_real_manifest_external_review_send_return_bundle",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fj_post_fi_real_manifest_external_review_send_return_bundle_manifest.json").write_text(
    json.dumps(run_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fj_post_fi_real_manifest_external_review_send_return_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
