#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v60c_release_blocker_replay_entrypoint"
RUN_ID="${V60C_RUN_ID:-entrypoint_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V60C_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v60c_release_blocker_replay_entrypoint_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v60_architecture_challenge_release_contract.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shlex
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
entrypoint_dir = run_dir / "release_blocker_replay_entrypoint"
entrypoint_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def first_row(path):
    rows = read_csv(path)
    if len(rows) != 1:
        raise SystemExit(f"expected one row in {path}")
    return rows[0]


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


def as_int(row, key, default="0"):
    return int(float(row.get(key, default) or default))


v60_summary_path = results / "v60_architecture_challenge_release_contract_summary.csv"
v60_dir = results / "v60_architecture_challenge_release_contract" / "contract_001"
v60_summary = first_row(v60_summary_path)
if v60_summary.get("v60_release_contract_ready") != "1":
    raise SystemExit("v60c requires v60 release contract ready")

source_files = [
    (v60_summary_path, "source_v60/v60_architecture_challenge_release_contract_summary.csv"),
    (results / "v60_architecture_challenge_release_contract_decision.csv", "source_v60/v60_architecture_challenge_release_contract_decision.csv"),
    (v60_dir / "release_requirement_rows.csv", "source_v60/release_requirement_rows.csv"),
    (v60_dir / "release_decision_rows.csv", "source_v60/release_decision_rows.csv"),
    (v60_dir / "V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md", "source_v60/V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md"),
    (v60_dir / "v60_architecture_challenge_release_manifest.json", "source_v60/v60_architecture_challenge_release_manifest.json"),
    (v60_dir / "source_v59e" / "source_pm_pr_claim_slice_gate" / "pm_pr_acceptance_evidence_rows.csv", "source_pm/pm_pr_acceptance_evidence_rows.csv"),
    (v60_dir / "source_v59e" / "source_pm_pr_claim_slice_gate" / "v56_replay_acceptance_evidence_rows.csv", "source_pm/v56_replay_acceptance_evidence_rows.csv"),
    (v60_dir / "source_v59e" / "source_pm_pr_claim_slice_gate" / "de_30b70b_acceptance_evidence_rows.csv", "source_pm/de_30b70b_acceptance_evidence_rows.csv"),
    (v60_dir / "source_v59e" / "source_pm_pr_claim_slice_gate" / "v59_one_command_acceptance_evidence_rows.csv", "source_pm/v59_one_command_acceptance_evidence_rows.csv"),
    (v60_dir / "source_v59e" / "source_pm_pr_claim_slice_gate" / "pm_blocker_required_artifact_rows.csv", "source_pm/pm_blocker_required_artifact_rows.csv"),
    (v60_dir / "source_v59e" / "source_pm_pr_claim_slice_gate" / "pm_blocker_closure_queue_rows.csv", "source_pm/pm_blocker_closure_queue_rows.csv"),
    (v60_dir / "source_v59e" / "source_pm_pr_claim_slice_gate" / "pm_external_return_template_rows.csv", "source_pm/pm_external_return_template_rows.csv"),
]
for src, rel in source_files:
    if not src.is_file():
        raise SystemExit(f"missing v60c source: {src}")
    copy(src, rel)

release_requirements = read_csv(v60_dir / "release_requirement_rows.csv")
blocked_release_requirements = [row for row in release_requirements if row["status"] == "blocked"]
pm_acceptance_evidence_rows = read_csv(run_dir / "source_pm/pm_pr_acceptance_evidence_rows.csv")
pm_acceptance_evidence_ready_rows = sum(1 for row in pm_acceptance_evidence_rows if row["acceptance_ready"] == "1")
pm_acceptance_evidence_tests_only_rows = sum(1 for row in pm_acceptance_evidence_rows if row["tests_only_merge_condition"] == "1")
pm_v56_replay_acceptance_evidence_rows = read_csv(run_dir / "source_pm/v56_replay_acceptance_evidence_rows.csv")
pm_v56_replay_acceptance_ready_rows = sum(1 for row in pm_v56_replay_acceptance_evidence_rows if row["acceptance_ready"] == "1")
pm_v56_replay_acceptance_blocked_rows = len(pm_v56_replay_acceptance_evidence_rows) - pm_v56_replay_acceptance_ready_rows
pm_v56_replay_acceptance_tests_only_rows = sum(
    1 for row in pm_v56_replay_acceptance_evidence_rows if row["tests_only_merge_condition"] == "1"
)
pm_v56_replay_acceptance_fixture_allowed_rows = sum(
    1 for row in pm_v56_replay_acceptance_evidence_rows if row["fixture_allowed"] == "1"
)
pm_v56_replay_acceptance_approval_rows = sum(
    1 for row in pm_v56_replay_acceptance_evidence_rows if row["approval_required"] == "1"
)
pm_de_30b70b_acceptance_evidence_rows = read_csv(run_dir / "source_pm/de_30b70b_acceptance_evidence_rows.csv")
pm_de_30b70b_acceptance_ready_rows = sum(1 for row in pm_de_30b70b_acceptance_evidence_rows if row["acceptance_ready"] == "1")
pm_de_30b70b_acceptance_blocked_rows = len(pm_de_30b70b_acceptance_evidence_rows) - pm_de_30b70b_acceptance_ready_rows
pm_de_30b70b_acceptance_tests_only_rows = sum(
    1 for row in pm_de_30b70b_acceptance_evidence_rows if row["tests_only_merge_condition"] == "1"
)
pm_de_30b70b_acceptance_fixture_allowed_rows = sum(
    1 for row in pm_de_30b70b_acceptance_evidence_rows if row["fixture_allowed"] == "1"
)
pm_de_30b70b_acceptance_approval_rows = sum(
    1 for row in pm_de_30b70b_acceptance_evidence_rows if row["approval_required"] == "1"
)
pm_v59_one_command_acceptance_evidence_rows = read_csv(run_dir / "source_pm/v59_one_command_acceptance_evidence_rows.csv")
pm_v59_one_command_acceptance_ready_rows = sum(1 for row in pm_v59_one_command_acceptance_evidence_rows if row["acceptance_ready"] == "1")
pm_v59_one_command_acceptance_blocked_rows = len(pm_v59_one_command_acceptance_evidence_rows) - pm_v59_one_command_acceptance_ready_rows
pm_v59_one_command_acceptance_tests_only_rows = sum(
    1 for row in pm_v59_one_command_acceptance_evidence_rows if row["tests_only_merge_condition"] == "1"
)
pm_v59_one_command_acceptance_fixture_allowed_rows = sum(
    1 for row in pm_v59_one_command_acceptance_evidence_rows if row["fixture_allowed"] == "1"
)
pm_v59_one_command_acceptance_approval_rows = sum(
    1 for row in pm_v59_one_command_acceptance_evidence_rows if row["approval_required"] == "1"
)

required_env_rows = [
    {
        "env_var": "V60C_REAL_EVIDENCE_PROVENANCE",
        "required_value": "real-v60-release-blocker-evidence",
        "required_shape": "exact provenance string",
        "present_by_default": "0",
        "purpose": "reject fixture/candidate release blocker inputs",
    },
    {
        "env_var": "V60C_30B_EVIDENCE_DIR",
        "required_value": "repo-external directory",
        "required_shape": "D 30B model identity, answer, citation, resource, transcript, and sha256 evidence",
        "present_by_default": "0",
        "purpose": "D 30B symmetric baseline evidence",
    },
    {
        "env_var": "V60C_70B_EVIDENCE_DIR",
        "required_value": "repo-external directory",
        "required_shape": "E 70B model identity, answer, citation, resource, transcript, and sha256 evidence",
        "present_by_default": "0",
        "purpose": "E 70B symmetric baseline evidence",
    },
    {
        "env_var": "V60C_H10_REAL_LABEL_EVIDENCE_CSV",
        "required_value": "repo-external CSV file",
        "required_shape": "external/human h10 label rows with source provenance and acceptance hashes",
        "present_by_default": "0",
        "purpose": "h10 source-verified scorer promotion evidence",
    },
    {
        "env_var": "V60C_V56_REPLAY_ARTIFACT_DIR",
        "required_value": "repo-external directory",
        "required_shape": "hash-bound v56/v56b contract and scale replay artifacts",
        "present_by_default": "0",
        "purpose": "v56 expanded benchmark replay artifact",
    },
    {
        "env_var": "V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR",
        "required_value": "repo-external directory",
        "required_shape": "blind responses, run identities, human blind review, adjudication, and sha256 evidence",
        "present_by_default": "0",
        "purpose": "v58 real blind eval evidence",
    },
    {
        "env_var": "V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR",
        "required_value": "repo-external directory",
        "required_shape": "approved public-source refresh evidence with pinned repo URLs, commit SHAs, tree/content hashes, download transcript, and sha256 manifest",
        "present_by_default": "0",
        "purpose": "full v59 public-source replay/download refresh evidence",
    },
    {
        "env_var": "V60C_HUMAN_RELEASE_REVIEW_DIR",
        "required_value": "repo-external directory",
        "required_shape": "human release review decision, conflict disclosure, and release claim audit",
        "present_by_default": "0",
        "purpose": "human release review evidence",
    },
    {
        "env_var": "V60C_RELEASE_PACKAGE_DIR",
        "required_value": "repo-external directory",
        "required_shape": "final release package built from v52-v59 real evidence and release review",
        "present_by_default": "0",
        "purpose": "v60 release artifact package",
    },
]
write_csv(run_dir / "release_blocker_replay_required_env_rows.csv", list(required_env_rows[0].keys()), required_env_rows)

pm_required_artifact_rows = read_csv(run_dir / "source_pm/pm_blocker_required_artifact_rows.csv")
pm_return_template_rows = read_csv(run_dir / "source_pm/pm_external_return_template_rows.csv")
template_by_key = {(row["blocker_class"], row["artifact_id"]): row for row in pm_return_template_rows}


def replay_target_for(row):
    blocker = row["blocker_class"]
    artifact = row["artifact_id"]
    if blocker == "v56-replay-artifact-missing":
        return "V60C_V56_REPLAY_ARTIFACT_DIR", "06-v56-replay-artifact", "repo-external-dir"
    if blocker == "de-30b70b-baselines-missing":
        if artifact.startswith("d-"):
            return "V60C_30B_EVIDENCE_DIR", "04-d-e-30b70b-baselines", "repo-external-dir"
        return "V60C_70B_EVIDENCE_DIR", "04-d-e-30b70b-baselines", "repo-external-dir"
    if blocker == "external-human-label-evidence-missing":
        return "V60C_H10_REAL_LABEL_EVIDENCE_CSV", "05-h10-real-labels", "repo-external-file"
    if blocker == "v58c-intake-artifact-missing":
        return "V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR", "07-v58c-blind-response-intake", "repo-external-dir"
    if blocker == "v58-real-blind-eval-missing":
        return "V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR", "08-v58-real-blind-eval", "repo-external-dir"
    if artifact == "v59-public-source-download-refresh":
        return "V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR", "09-public-source-download-refresh", "repo-external-dir"
    if artifact == "v60-human-release-review":
        return "V60C_HUMAN_RELEASE_REVIEW_DIR", "11-human-release-review", "repo-external-dir"
    if artifact == "v60-release-sha256-manifest":
        return "V60C_RELEASE_PACKAGE_DIR", "12-release-package", "repo-external-dir"
    return "none-local-v60-source-copy", "02-pm-foundation-pass-surfaces", "metadata-only"


pm_artifact_map_rows = []
for row in pm_required_artifact_rows:
    key = (row["blocker_class"], row["artifact_id"])
    template = template_by_key.get(key)
    if template is None:
        raise SystemExit(f"missing return template row for PM required artifact: {key}")
    replay_env, replay_stage, evidence_root_kind = replay_target_for(row)
    pm_artifact_map_rows.append(
        {
            "blocker_class": row["blocker_class"],
            "artifact_id": row["artifact_id"],
            "artifact_path_or_env": row["artifact_path_or_env"],
            "artifact_kind": row["artifact_kind"],
            "validation_command": row["validation_command"],
            "acceptance_signal": row["acceptance_signal"],
            "source_fixture_allowed": row["fixture_allowed"],
            "source_approval_required": row["approval_required"],
            "return_template_path": template["template_path"],
            "return_template_ready": template["template_ready"],
            "return_template_sha256": template["template_sha256"],
            "replay_env_var": replay_env,
            "replay_stage_id": replay_stage,
            "evidence_root_kind": evidence_root_kind,
            "default_replay_admitted": "0",
            "status": "fail-closed",
        }
    )
write_csv(run_dir / "release_blocker_replay_artifact_map_rows.csv", list(pm_artifact_map_rows[0].keys()), pm_artifact_map_rows)

stage_rows = [
    {"stage_id": "01-v60-release-gate", "status": "ready", "evidence": "v60_release_contract_ready=1", "blocking_reason": ""},
    {"stage_id": "02-pm-foundation-pass-surfaces", "status": "ready", "evidence": "six PM-foundation requirements are ready", "blocking_reason": ""},
    {"stage_id": "03-real-evidence-provenance", "status": "blocked", "evidence": "V60C_REAL_EVIDENCE_PROVENANCE unset", "blocking_reason": "exact real-v60-release-blocker-evidence provenance is required"},
    {"stage_id": "04-d-e-30b70b-baselines", "status": "blocked", "evidence": "V60C_30B_EVIDENCE_DIR and V60C_70B_EVIDENCE_DIR unset", "blocking_reason": "real D/E baseline evidence required"},
    {"stage_id": "05-h10-real-labels", "status": "blocked", "evidence": "V60C_H10_REAL_LABEL_EVIDENCE_CSV unset", "blocking_reason": "external/human source-verified label evidence required"},
    {"stage_id": "06-v56-replay-artifact", "status": "blocked", "evidence": "V60C_V56_REPLAY_ARTIFACT_DIR unset", "blocking_reason": "v56 replay artifact required"},
    {"stage_id": "07-v58c-blind-response-intake", "status": "blocked", "evidence": "v58c_intake_artifact_available=0", "blocking_reason": "v58c response intake artifact or dependency closure required"},
    {"stage_id": "08-v58-real-blind-eval", "status": "blocked", "evidence": "V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR unset", "blocking_reason": "real blind responses and human blind review required"},
    {"stage_id": "09-public-source-download-refresh", "status": "blocked", "evidence": "V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR unset and full_public_source_download_ready=0", "blocking_reason": "approved public-source refresh/download evidence required"},
    {"stage_id": "10-full-v59-public-demo", "status": "blocked", "evidence": "full_v1_public_demo_ready=0", "blocking_reason": "full public replay over all real rows is missing"},
    {"stage_id": "11-human-release-review", "status": "blocked", "evidence": "V60C_HUMAN_RELEASE_REVIEW_DIR unset", "blocking_reason": "human release review required"},
    {"stage_id": "12-release-package", "status": "blocked", "evidence": "V60C_RELEASE_PACKAGE_DIR unset", "blocking_reason": "release package required"},
    {"stage_id": "13-v60-release-ready", "status": "blocked", "evidence": "v60_ready=0 and real_release_package_ready=0", "blocking_reason": "all release blockers must close first"},
]
write_csv(run_dir / "release_blocker_replay_stage_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {
        "command_id": "01-verify-entrypoint",
        "ready_to_run_now": "1",
        "command": "results/v60c_release_blocker_replay_entrypoint/entrypoint_001/release_blocker_replay_entrypoint/VERIFY_RELEASE_BLOCKER_REPLAY_ENTRYPOINT.sh",
        "purpose": "verify the metadata-only entrypoint package",
    },
    {
        "command_id": "02-print-ready-commands",
        "ready_to_run_now": "1",
        "command": "results/v60c_release_blocker_replay_entrypoint/entrypoint_001/release_blocker_replay_entrypoint/READY_NOW_COMMANDS.sh",
        "purpose": "print guarded replay command and required env contract",
    },
    {
        "command_id": "03-run-release-blocker-replay",
        "ready_to_run_now": "0",
        "command": "source results/v60c_release_blocker_replay_entrypoint/entrypoint_001/release_blocker_replay_entrypoint/V60C_RELEASE_BLOCKER_REPLAY_ENV_TEMPLATE.sh && results/v60c_release_blocker_replay_entrypoint/entrypoint_001/release_blocker_replay_entrypoint/RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh",
        "purpose": "admit local replay only after all real evidence roots are supplied outside the repo",
    },
]
write_csv(run_dir / "release_blocker_replay_command_rows.csv", list(command_rows[0].keys()), command_rows)

env_template = entrypoint_dir / "V60C_RELEASE_BLOCKER_REPLAY_ENV_TEMPLATE.sh"
env_template.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "export V60C_REAL_EVIDENCE_PROVENANCE=real-v60-release-blocker-evidence",
            "export V60C_30B_EVIDENCE_DIR=/path/outside/repo/d_30b_evidence",
            "export V60C_70B_EVIDENCE_DIR=/path/outside/repo/e_70b_evidence",
            "export V60C_H10_REAL_LABEL_EVIDENCE_CSV=/path/outside/repo/h10_real_label_evidence.csv",
            "export V60C_V56_REPLAY_ARTIFACT_DIR=/path/outside/repo/v56_replay_artifacts",
            "export V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR=/path/outside/repo/v58_blind_response_evidence",
            "export V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR=/path/outside/repo/public_source_refresh_evidence",
            "export V60C_HUMAN_RELEASE_REVIEW_DIR=/path/outside/repo/human_release_review",
            "export V60C_RELEASE_PACKAGE_DIR=/path/outside/repo/v60_release_package",
            "",
        ]
    ),
    encoding="utf-8",
)
env_template.chmod(0o755)

run_script = entrypoint_dir / "RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh"
run_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            f"ROOT_DIR={shlex.quote(str(root))}",
            ": \"${V60C_REAL_EVIDENCE_PROVENANCE:?set V60C_REAL_EVIDENCE_PROVENANCE=real-v60-release-blocker-evidence}\"",
            ": \"${V60C_30B_EVIDENCE_DIR:?set V60C_30B_EVIDENCE_DIR}\"",
            ": \"${V60C_70B_EVIDENCE_DIR:?set V60C_70B_EVIDENCE_DIR}\"",
            ": \"${V60C_H10_REAL_LABEL_EVIDENCE_CSV:?set V60C_H10_REAL_LABEL_EVIDENCE_CSV}\"",
            ": \"${V60C_V56_REPLAY_ARTIFACT_DIR:?set V60C_V56_REPLAY_ARTIFACT_DIR}\"",
            ": \"${V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR:?set V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR}\"",
            ": \"${V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR:?set V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR}\"",
            ": \"${V60C_HUMAN_RELEASE_REVIEW_DIR:?set V60C_HUMAN_RELEASE_REVIEW_DIR}\"",
            ": \"${V60C_RELEASE_PACKAGE_DIR:?set V60C_RELEASE_PACKAGE_DIR}\"",
            "if [[ \"$V60C_REAL_EVIDENCE_PROVENANCE\" != \"real-v60-release-blocker-evidence\" ]]; then",
            "  echo \"rejecting release blocker provenance: $V60C_REAL_EVIDENCE_PROVENANCE\" >&2",
            "  exit 3",
            "fi",
            "require_external_dir() {",
            "  local value=\"$1\"",
            "  local name=\"$2\"",
            "  if [[ ! -d \"$value\" ]]; then",
            "    echo \"missing directory for $name: $value\" >&2",
            "    exit 2",
            "  fi",
            "  local resolved",
            "  resolved=\"$(realpath -m \"$value\")\"",
            "  case \"$resolved\" in",
            "    \"$ROOT_DIR\"|\"$ROOT_DIR\"/*)",
            "      echo \"rejecting repo-internal evidence directory for $name: $resolved\" >&2",
            "      exit 4",
            "      ;;",
            "  esac",
            "}",
            "require_external_file() {",
            "  local value=\"$1\"",
            "  local name=\"$2\"",
            "  if [[ ! -f \"$value\" || ! -s \"$value\" ]]; then",
            "    echo \"missing non-empty file for $name: $value\" >&2",
            "    exit 2",
            "  fi",
            "  local resolved",
            "  resolved=\"$(realpath -m \"$value\")\"",
            "  case \"$resolved\" in",
            "    \"$ROOT_DIR\"|\"$ROOT_DIR\"/*)",
            "      echo \"rejecting repo-internal evidence file for $name: $resolved\" >&2",
            "      exit 4",
            "      ;;",
            "  esac",
            "}",
            "require_external_dir \"$V60C_30B_EVIDENCE_DIR\" V60C_30B_EVIDENCE_DIR",
            "require_external_dir \"$V60C_70B_EVIDENCE_DIR\" V60C_70B_EVIDENCE_DIR",
            "require_external_file \"$V60C_H10_REAL_LABEL_EVIDENCE_CSV\" V60C_H10_REAL_LABEL_EVIDENCE_CSV",
            "require_external_dir \"$V60C_V56_REPLAY_ARTIFACT_DIR\" V60C_V56_REPLAY_ARTIFACT_DIR",
            "require_external_dir \"$V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR\" V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR",
            "require_external_dir \"$V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR\" V60C_PUBLIC_SOURCE_REFRESH_EVIDENCE_DIR",
            "require_external_dir \"$V60C_HUMAN_RELEASE_REVIEW_DIR\" V60C_HUMAN_RELEASE_REVIEW_DIR",
            "require_external_dir \"$V60C_RELEASE_PACKAGE_DIR\" V60C_RELEASE_PACKAGE_DIR",
            "V52D_30B_LLM_RAG_EVIDENCE_DIR=\"$V60C_30B_EVIDENCE_DIR\" \\",
            "V52D_70B_LLM_RAG_EVIDENCE_DIR=\"$V60C_70B_EVIDENCE_DIR\" \\",
            "\"$ROOT_DIR/experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh\"",
            "V10_H10_REAL_LABEL_EVIDENCE_CSV=\"$V60C_H10_REAL_LABEL_EVIDENCE_CSV\" \\",
            "\"$ROOT_DIR/experiments/test_v10_h10_real_label_promotion_readiness_gate.sh\"",
            "V58C_BLIND_RESPONSE_EVIDENCE_DIR=\"$V60C_V58_BLIND_RESPONSE_EVIDENCE_DIR\" \\",
            "\"$ROOT_DIR/experiments/test_v58c_blind_response_evidence_intake.sh\"",
            "\"$ROOT_DIR/experiments/test_v60_architecture_challenge_release_contract.sh\"",
            "echo \"v60c replay admission checks completed; v56 and release package closure still require their dedicated acceptance gates.\"",
            "",
        ]
    ),
    encoding="utf-8",
)
run_script.chmod(0o755)

verify_script = entrypoint_dir / "VERIFY_RELEASE_BLOCKER_REPLAY_ENTRYPOINT.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"",
            "test -x \"$DIR/V60C_RELEASE_BLOCKER_REPLAY_ENV_TEMPLATE.sh\"",
            "test -x \"$DIR/RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh\"",
            "test -s \"$DIR/V60C_RELEASE_BLOCKER_REPLAY_MANIFEST.json\"",
            "test -s \"$DIR/V60C_RELEASE_BLOCKER_REPLAY_STAGE_ROWS.csv\"",
            "test -s \"$DIR/V60C_RELEASE_BLOCKER_REPLAY_COMMAND_ROWS.csv\"",
            "if grep -R -E '\\.(safetensors|gguf|bin|pt|pth)$' \"$DIR\" >/dev/null; then",
            "  echo 'payload-like file referenced in v60c entrypoint package' >&2",
            "  exit 1",
            "fi",
            "",
        ]
    ),
    encoding="utf-8",
)
verify_script.chmod(0o755)

ready_script = entrypoint_dir / "READY_NOW_COMMANDS.sh"
ready_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            "echo 'v60c ready-now commands are metadata verification only; real replay needs external roots and exact provenance.'",
            "echo 'results/v60c_release_blocker_replay_entrypoint/entrypoint_001/release_blocker_replay_entrypoint/VERIFY_RELEASE_BLOCKER_REPLAY_ENTRYPOINT.sh'",
            "echo 'source results/v60c_release_blocker_replay_entrypoint/entrypoint_001/release_blocker_replay_entrypoint/V60C_RELEASE_BLOCKER_REPLAY_ENV_TEMPLATE.sh'",
            "echo 'results/v60c_release_blocker_replay_entrypoint/entrypoint_001/release_blocker_replay_entrypoint/RUN_RELEASE_BLOCKER_REPLAY_IF_READY.sh'",
            "",
        ]
    ),
    encoding="utf-8",
)
ready_script.chmod(0o755)

shutil.copy2(run_dir / "release_blocker_replay_required_env_rows.csv", entrypoint_dir / "V60C_RELEASE_BLOCKER_REPLAY_REQUIRED_ENV_ROWS.csv")
shutil.copy2(run_dir / "release_blocker_replay_stage_rows.csv", entrypoint_dir / "V60C_RELEASE_BLOCKER_REPLAY_STAGE_ROWS.csv")
shutil.copy2(run_dir / "release_blocker_replay_command_rows.csv", entrypoint_dir / "V60C_RELEASE_BLOCKER_REPLAY_COMMAND_ROWS.csv")
shutil.copy2(run_dir / "release_blocker_replay_artifact_map_rows.csv", entrypoint_dir / "V60C_RELEASE_BLOCKER_REPLAY_ARTIFACT_MAP_ROWS.csv")
shutil.copy2(run_dir / "source_pm" / "pm_pr_acceptance_evidence_rows.csv", entrypoint_dir / "V60C_PM_PR_ACCEPTANCE_EVIDENCE_ROWS.csv")
shutil.copy2(run_dir / "source_pm" / "v56_replay_acceptance_evidence_rows.csv", entrypoint_dir / "V60C_PM_V56_REPLAY_ACCEPTANCE_EVIDENCE_ROWS.csv")
shutil.copy2(run_dir / "source_pm" / "de_30b70b_acceptance_evidence_rows.csv", entrypoint_dir / "V60C_PM_DE_30B70B_ACCEPTANCE_EVIDENCE_ROWS.csv")
shutil.copy2(run_dir / "source_pm" / "v59_one_command_acceptance_evidence_rows.csv", entrypoint_dir / "V60C_PM_V59_ONE_COMMAND_ACCEPTANCE_EVIDENCE_ROWS.csv")

entrypoint_manifest = {
    "artifact": "v60c_release_blocker_replay_entrypoint",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "entrypoint_admitted_by_default": 0,
    "required_env_rows": len(required_env_rows),
    "pm_acceptance_evidence_rows": len(pm_acceptance_evidence_rows),
    "pm_acceptance_evidence_ready_rows": pm_acceptance_evidence_ready_rows,
    "pm_acceptance_evidence_tests_only_rows": pm_acceptance_evidence_tests_only_rows,
    "pm_v56_replay_acceptance_evidence_rows": len(pm_v56_replay_acceptance_evidence_rows),
    "pm_v56_replay_acceptance_evidence_ready_rows": pm_v56_replay_acceptance_ready_rows,
    "pm_v56_replay_acceptance_evidence_blocked_rows": pm_v56_replay_acceptance_blocked_rows,
    "pm_v56_replay_acceptance_evidence_tests_only_rows": pm_v56_replay_acceptance_tests_only_rows,
    "pm_v56_replay_acceptance_evidence_fixture_allowed_rows": pm_v56_replay_acceptance_fixture_allowed_rows,
    "pm_v56_replay_acceptance_evidence_approval_rows": pm_v56_replay_acceptance_approval_rows,
    "pm_de_30b70b_acceptance_evidence_rows": len(pm_de_30b70b_acceptance_evidence_rows),
    "pm_de_30b70b_acceptance_evidence_ready_rows": pm_de_30b70b_acceptance_ready_rows,
    "pm_de_30b70b_acceptance_evidence_blocked_rows": pm_de_30b70b_acceptance_blocked_rows,
    "pm_de_30b70b_acceptance_evidence_tests_only_rows": pm_de_30b70b_acceptance_tests_only_rows,
    "pm_de_30b70b_acceptance_evidence_fixture_allowed_rows": pm_de_30b70b_acceptance_fixture_allowed_rows,
    "pm_de_30b70b_acceptance_evidence_approval_rows": pm_de_30b70b_acceptance_approval_rows,
    "pm_v59_one_command_acceptance_evidence_rows": len(pm_v59_one_command_acceptance_evidence_rows),
    "pm_v59_one_command_acceptance_evidence_ready_rows": pm_v59_one_command_acceptance_ready_rows,
    "pm_v59_one_command_acceptance_evidence_blocked_rows": pm_v59_one_command_acceptance_blocked_rows,
    "pm_v59_one_command_acceptance_evidence_tests_only_rows": pm_v59_one_command_acceptance_tests_only_rows,
    "pm_v59_one_command_acceptance_evidence_fixture_allowed_rows": pm_v59_one_command_acceptance_fixture_allowed_rows,
    "pm_v59_one_command_acceptance_evidence_approval_rows": pm_v59_one_command_acceptance_approval_rows,
    "pm_required_artifact_map_rows": len(pm_artifact_map_rows),
    "stage_rows": len(stage_rows),
    "ready_stage_rows": sum(1 for row in stage_rows if row["status"] == "ready"),
    "blocked_stage_rows": sum(1 for row in stage_rows if row["status"] == "blocked"),
    "blocked_release_requirement_rows": len(blocked_release_requirements),
    "real_release_package_ready": 0,
    "remote_mutation_approved": 0,
    "network_required_by_default": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(entrypoint_dir / "V60C_RELEASE_BLOCKER_REPLAY_MANIFEST.json").write_text(
    json.dumps(entrypoint_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

entrypoint_readme = entrypoint_dir / "README.md"
entrypoint_readme.write_text(
    "# v60c Release Blocker Replay Entrypoint\n\n"
    "This package is metadata-only. It does not run external evidence intake by default.\n\n"
    "The guarded replay script requires repo-external evidence paths and the exact "
    "`real-v60-release-blocker-evidence` provenance string. Fixture or repo-internal "
    "inputs are rejected before replay commands run.\n\n"
    "Current ready commands are verification-only. Release remains blocked until "
    "D/E 30B/70B evidence, h10 real labels, v56 replay artifact, v58c intake artifact, v58 blind eval, "
    "approved public-source refresh evidence, human release review, and a real release package are accepted. "
    "The bundled PM PR acceptance evidence rows show which review slices are already local-reviewable and which remain held.\n",
    encoding="utf-8",
)

entrypoint_files = []
for path in sorted(entrypoint_dir.rglob("*")):
    if path.is_file():
        rel = path.relative_to(run_dir).as_posix()
        entrypoint_files.append(
            {
                "path": rel,
                "bytes": path.stat().st_size,
                "sha256": sha256(path),
                "executable": "1" if path.stat().st_mode & 0o111 else "0",
                "metadata_only": "1",
                "payload_like": "1" if path.suffix in {".safetensors", ".gguf", ".bin", ".pt", ".pth"} else "0",
            }
        )
write_csv(run_dir / "release_blocker_replay_entrypoint_file_rows.csv", list(entrypoint_files[0].keys()), entrypoint_files)

decision_rows = [
    ("v60-release-contract-input", "pass", "v60 release contract is ready and copied"),
    ("entrypoint-files", "pass", "metadata-only entrypoint, verifier, env template, and command rows are emitted"),
    ("zero-remote-mutation-default", "pass", "no network, remote mutation, push, PR, release, or publish is performed by default"),
    ("zero-repo-payload", "pass", "entrypoint package contains no checkpoint/model payload"),
    ("default-admission", "blocked", "required env vars are unset by default"),
    ("real-evidence-provenance", "blocked", "real-v60-release-blocker-evidence provenance is required"),
    ("release-ready", "blocked", "v60_ready=0 and real_release_package_ready=0"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

summary = {
    "v60c_release_blocker_replay_entrypoint_ready": "1",
    "v60_release_contract_ready": v60_summary["v60_release_contract_ready"],
    "entrypoint_admitted_by_default": "0",
    "required_env_rows": str(len(required_env_rows)),
    "present_required_env_rows_by_default": str(sum(1 for row in required_env_rows if row["present_by_default"] == "1")),
    "stage_rows": str(len(stage_rows)),
    "ready_stage_rows": str(sum(1 for row in stage_rows if row["status"] == "ready")),
    "blocked_stage_rows": str(sum(1 for row in stage_rows if row["status"] == "blocked")),
    "command_rows": str(len(command_rows)),
    "ready_command_rows": str(sum(1 for row in command_rows if row["ready_to_run_now"] == "1")),
    "blocked_command_rows": str(sum(1 for row in command_rows if row["ready_to_run_now"] == "0")),
    "release_requirement_rows": v60_summary["release_requirement_rows"],
    "release_requirement_ready_rows": v60_summary["release_requirement_ready_rows"],
    "release_requirement_blocked_rows": v60_summary["release_requirement_blocked_rows"],
    "blocked_release_requirement_rows": str(len(blocked_release_requirements)),
    "pm_acceptance_evidence_rows": str(len(pm_acceptance_evidence_rows)),
    "pm_acceptance_evidence_ready_rows": str(pm_acceptance_evidence_ready_rows),
    "pm_acceptance_evidence_tests_only_rows": str(pm_acceptance_evidence_tests_only_rows),
    "pm_v56_replay_acceptance_evidence_rows": str(len(pm_v56_replay_acceptance_evidence_rows)),
    "pm_v56_replay_acceptance_evidence_ready_rows": str(pm_v56_replay_acceptance_ready_rows),
    "pm_v56_replay_acceptance_evidence_blocked_rows": str(pm_v56_replay_acceptance_blocked_rows),
    "pm_v56_replay_acceptance_evidence_tests_only_rows": str(pm_v56_replay_acceptance_tests_only_rows),
    "pm_v56_replay_acceptance_evidence_fixture_allowed_rows": str(pm_v56_replay_acceptance_fixture_allowed_rows),
    "pm_v56_replay_acceptance_evidence_approval_rows": str(pm_v56_replay_acceptance_approval_rows),
    "pm_de_30b70b_acceptance_evidence_rows": str(len(pm_de_30b70b_acceptance_evidence_rows)),
    "pm_de_30b70b_acceptance_evidence_ready_rows": str(pm_de_30b70b_acceptance_ready_rows),
    "pm_de_30b70b_acceptance_evidence_blocked_rows": str(pm_de_30b70b_acceptance_blocked_rows),
    "pm_de_30b70b_acceptance_evidence_tests_only_rows": str(pm_de_30b70b_acceptance_tests_only_rows),
    "pm_de_30b70b_acceptance_evidence_fixture_allowed_rows": str(pm_de_30b70b_acceptance_fixture_allowed_rows),
    "pm_de_30b70b_acceptance_evidence_approval_rows": str(pm_de_30b70b_acceptance_approval_rows),
    "pm_v59_one_command_acceptance_evidence_rows": str(len(pm_v59_one_command_acceptance_evidence_rows)),
    "pm_v59_one_command_acceptance_evidence_ready_rows": str(pm_v59_one_command_acceptance_ready_rows),
    "pm_v59_one_command_acceptance_evidence_blocked_rows": str(pm_v59_one_command_acceptance_blocked_rows),
    "pm_v59_one_command_acceptance_evidence_tests_only_rows": str(pm_v59_one_command_acceptance_tests_only_rows),
    "pm_v59_one_command_acceptance_evidence_fixture_allowed_rows": str(pm_v59_one_command_acceptance_fixture_allowed_rows),
    "pm_v59_one_command_acceptance_evidence_approval_rows": str(pm_v59_one_command_acceptance_approval_rows),
    "pm_required_artifact_map_rows": str(len(pm_artifact_map_rows)),
    "pm_required_artifact_map_fixture_allowed_rows": str(sum(1 for row in pm_artifact_map_rows if row["source_fixture_allowed"] == "1")),
    "pm_required_artifact_map_approval_rows": str(sum(1 for row in pm_artifact_map_rows if row["source_approval_required"] == "1")),
    "pm_required_artifact_map_template_bound_rows": str(sum(1 for row in pm_artifact_map_rows if row["return_template_ready"] == "1")),
    "pm_required_artifact_map_default_admitted_rows": str(sum(1 for row in pm_artifact_map_rows if row["default_replay_admitted"] == "1")),
    "entrypoint_file_rows": str(len(entrypoint_files)),
    "metadata_only_entrypoint_file_rows": str(sum(1 for row in entrypoint_files if row["metadata_only"] == "1")),
    "payload_like_entrypoint_file_rows": str(sum(1 for row in entrypoint_files if row["payload_like"] == "1")),
    "remote_mutation_approved": "0",
    "network_required_by_default": "0",
    "downloads_required_by_default": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "real_30b_70b_rows_ready": v60_summary["real_30b_70b_rows_ready"],
    "h10_real_label_promotion_ready": v60_summary["h10_real_label_promotion_ready"],
    "expanded_benchmark_ready": v60_summary["expanded_benchmark_ready"],
    "v58c_blind_response_intake_ready": v60_summary["v58c_blind_response_intake_ready"],
    "v58c_intake_artifact_available": v60_summary["v58c_intake_artifact_available"],
    "v58c_dependency_blocker_ready": v60_summary["v58c_dependency_blocker_ready"],
    "blind_eval_ready": v60_summary["blind_eval_ready"],
    "one_command_real_replay_ready": v60_summary["one_command_real_replay_ready"],
    "human_release_review_ready": v60_summary["human_release_review_ready"],
    "v60_ready": v60_summary["v60_ready"],
    "real_release_package_ready": v60_summary["real_release_package_ready"],
}
write_csv(summary_csv, list(summary.keys()), [summary])

(run_dir / "V60C_RELEASE_BLOCKER_REPLAY_ENTRYPOINT_BOUNDARY.md").write_text(
    "# v60c Release Blocker Replay Entrypoint Boundary\n\n"
    "This is a metadata-only, fail-closed operator entrypoint for remaining v60 release blockers.\n\n"
    f"- v60c_release_blocker_replay_entrypoint_ready={summary['v60c_release_blocker_replay_entrypoint_ready']}\n"
    f"- entrypoint_admitted_by_default={summary['entrypoint_admitted_by_default']}\n"
    f"- required_env_rows={summary['required_env_rows']}\n"
    f"- ready_stage_rows={summary['ready_stage_rows']}\n"
    f"- blocked_stage_rows={summary['blocked_stage_rows']}\n"
    f"- blocked_release_requirement_rows={summary['blocked_release_requirement_rows']}\n"
    f"- pm_acceptance_evidence_rows={summary['pm_acceptance_evidence_rows']}\n"
    f"- pm_acceptance_evidence_ready_rows={summary['pm_acceptance_evidence_ready_rows']}\n"
    f"- pm_acceptance_evidence_tests_only_rows={summary['pm_acceptance_evidence_tests_only_rows']}\n"
    f"- pm_v56_replay_acceptance_evidence_rows={summary['pm_v56_replay_acceptance_evidence_rows']}\n"
    f"- pm_v56_replay_acceptance_evidence_ready_rows={summary['pm_v56_replay_acceptance_evidence_ready_rows']}\n"
    f"- pm_v56_replay_acceptance_evidence_blocked_rows={summary['pm_v56_replay_acceptance_evidence_blocked_rows']}\n"
    f"- pm_v56_replay_acceptance_evidence_tests_only_rows={summary['pm_v56_replay_acceptance_evidence_tests_only_rows']}\n"
    f"- pm_de_30b70b_acceptance_evidence_rows={summary['pm_de_30b70b_acceptance_evidence_rows']}\n"
    f"- pm_de_30b70b_acceptance_evidence_ready_rows={summary['pm_de_30b70b_acceptance_evidence_ready_rows']}\n"
    f"- pm_de_30b70b_acceptance_evidence_blocked_rows={summary['pm_de_30b70b_acceptance_evidence_blocked_rows']}\n"
    f"- pm_de_30b70b_acceptance_evidence_tests_only_rows={summary['pm_de_30b70b_acceptance_evidence_tests_only_rows']}\n"
    f"- pm_v59_one_command_acceptance_evidence_rows={summary['pm_v59_one_command_acceptance_evidence_rows']}\n"
    f"- pm_v59_one_command_acceptance_evidence_ready_rows={summary['pm_v59_one_command_acceptance_evidence_ready_rows']}\n"
    f"- pm_v59_one_command_acceptance_evidence_blocked_rows={summary['pm_v59_one_command_acceptance_evidence_blocked_rows']}\n"
    f"- pm_v59_one_command_acceptance_evidence_tests_only_rows={summary['pm_v59_one_command_acceptance_evidence_tests_only_rows']}\n"
    f"- pm_required_artifact_map_rows={summary['pm_required_artifact_map_rows']}\n"
    f"- pm_required_artifact_map_fixture_allowed_rows={summary['pm_required_artifact_map_fixture_allowed_rows']}\n"
    f"- pm_required_artifact_map_approval_rows={summary['pm_required_artifact_map_approval_rows']}\n"
    f"- pm_required_artifact_map_template_bound_rows={summary['pm_required_artifact_map_template_bound_rows']}\n"
    f"- real_30b_70b_rows_ready={summary['real_30b_70b_rows_ready']}\n"
    f"- h10_real_label_promotion_ready={summary['h10_real_label_promotion_ready']}\n"
    f"- v58c_blind_response_intake_ready={summary['v58c_blind_response_intake_ready']}\n"
    f"- v58c_intake_artifact_available={summary['v58c_intake_artifact_available']}\n"
    f"- v58c_dependency_blocker_ready={summary['v58c_dependency_blocker_ready']}\n"
    f"- blind_eval_ready={summary['blind_eval_ready']}\n"
    f"- v60_ready={summary['v60_ready']}\n"
    f"- real_release_package_ready={summary['real_release_package_ready']}\n"
    f"- checkpoint_payload_bytes_committed_to_repo={summary['checkpoint_payload_bytes_committed_to_repo']}\n\n"
    "Allowed wording: local fail-closed entrypoint for supplying real v60 release-blocker evidence.\n\n"
    "Blocked wording: release-ready, public comparison win, h10 scientific contribution, blind-eval complete, or external evidence accepted by default.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v60c-release-blocker-replay-entrypoint",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v60c_release_blocker_replay_entrypoint_ready": 1,
    "entrypoint_admitted_by_default": 0,
    "required_env_rows": len(required_env_rows),
    "pm_acceptance_evidence_rows": len(pm_acceptance_evidence_rows),
    "pm_acceptance_evidence_ready_rows": pm_acceptance_evidence_ready_rows,
    "pm_acceptance_evidence_tests_only_rows": pm_acceptance_evidence_tests_only_rows,
    "pm_v56_replay_acceptance_evidence_rows": len(pm_v56_replay_acceptance_evidence_rows),
    "pm_v56_replay_acceptance_evidence_ready_rows": pm_v56_replay_acceptance_ready_rows,
    "pm_v56_replay_acceptance_evidence_blocked_rows": pm_v56_replay_acceptance_blocked_rows,
    "pm_v56_replay_acceptance_evidence_tests_only_rows": pm_v56_replay_acceptance_tests_only_rows,
    "pm_v56_replay_acceptance_evidence_fixture_allowed_rows": pm_v56_replay_acceptance_fixture_allowed_rows,
    "pm_v56_replay_acceptance_evidence_approval_rows": pm_v56_replay_acceptance_approval_rows,
    "pm_de_30b70b_acceptance_evidence_rows": len(pm_de_30b70b_acceptance_evidence_rows),
    "pm_de_30b70b_acceptance_evidence_ready_rows": pm_de_30b70b_acceptance_ready_rows,
    "pm_de_30b70b_acceptance_evidence_blocked_rows": pm_de_30b70b_acceptance_blocked_rows,
    "pm_de_30b70b_acceptance_evidence_tests_only_rows": pm_de_30b70b_acceptance_tests_only_rows,
    "pm_de_30b70b_acceptance_evidence_fixture_allowed_rows": pm_de_30b70b_acceptance_fixture_allowed_rows,
    "pm_de_30b70b_acceptance_evidence_approval_rows": pm_de_30b70b_acceptance_approval_rows,
    "pm_v59_one_command_acceptance_evidence_rows": len(pm_v59_one_command_acceptance_evidence_rows),
    "pm_v59_one_command_acceptance_evidence_ready_rows": pm_v59_one_command_acceptance_ready_rows,
    "pm_v59_one_command_acceptance_evidence_blocked_rows": pm_v59_one_command_acceptance_blocked_rows,
    "pm_v59_one_command_acceptance_evidence_tests_only_rows": pm_v59_one_command_acceptance_tests_only_rows,
    "pm_v59_one_command_acceptance_evidence_fixture_allowed_rows": pm_v59_one_command_acceptance_fixture_allowed_rows,
    "pm_v59_one_command_acceptance_evidence_approval_rows": pm_v59_one_command_acceptance_approval_rows,
    "pm_required_artifact_map_rows": len(pm_artifact_map_rows),
    "stage_rows": len(stage_rows),
    "blocked_release_requirement_rows": len(blocked_release_requirements),
    "real_release_package_ready": 0,
    "v60_summary_sha256": sha256(v60_summary_path),
    "v60_manifest_sha256": sha256(v60_dir / "v60_architecture_challenge_release_manifest.json"),
    "pm_v56_replay_acceptance_evidence_rows_sha256": sha256(run_dir / "source_pm/v56_replay_acceptance_evidence_rows.csv"),
    "pm_de_30b70b_acceptance_evidence_rows_sha256": sha256(run_dir / "source_pm/de_30b70b_acceptance_evidence_rows.csv"),
    "pm_v59_one_command_acceptance_evidence_rows_sha256": sha256(run_dir / "source_pm/v59_one_command_acceptance_evidence_rows.csv"),
}
(run_dir / "v60c_release_blocker_replay_entrypoint_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        artifact_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v60c_release_blocker_replay_entrypoint_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
