#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/audit-my-repo-product.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

make_repo() {
  local repo="$1"
  local title="$2"
  local package="$3"
  local variant="$4"
  mkdir -p "$repo"
  cat >"$repo/README.md" <<EOF
# $title

This repository is a local audit target. It is not production ready without evidence.
EOF
  case "$variant" in
    python)
      cat >"$repo/pyproject.toml" <<EOF
[project]
name = "$package"
requires-python = ">=3.10"
EOF
      cat >"$repo/module.py" <<'EOF'
def answer():
    return "ok"
EOF
      mkdir -p "$repo/docs"
      cat >"$repo/docs/evidence.md" <<'EOF'
# Evidence Notes

This local evidence note is a citation target, not release proof.
EOF
      ;;
    javascript)
      cat >"$repo/package.json" <<EOF
{"name":"$package","version":"0.0.0","type":"module"}
EOF
      mkdir -p "$repo/src"
      cat >"$repo/src/index.js" <<'EOF'
export function answer() {
  return "ok";
}
EOF
      ;;
    cpp)
      cat >"$repo/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.16)
project(${package//-/_} LANGUAGES CXX)
add_executable(${package//-/_} src/main.cpp)
EOF
      mkdir -p "$repo/src"
      cat >"$repo/src/main.cpp" <<'EOF'
#include <iostream>

int main() {
  std::cout << "ok\n";
  return 0;
}
EOF
      ;;
    *)
      echo "unknown test repo variant: $variant" >&2
      exit 2
      ;;
  esac
  git -C "$repo" init -q
  git -C "$repo" add .
  git -C "$repo" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m init
}

make_repo "$TMP_DIR/repo_1" "Audit Target Python" "audit-target-python" python
make_repo "$TMP_DIR/repo_2" "Audit Target JavaScript" "audit-target-js" javascript
make_repo "$TMP_DIR/repo_3" "Audit Target Cpp" "audit-target-cpp" cpp

FIRST_REPORT_OUT="$TMP_DIR/first_report_smoke"
"$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" \
  --out "$FIRST_REPORT_OUT" \
  --max-wall-ms 600000 >/dev/null
"$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --verify-existing "$FIRST_REPORT_OUT" >/dev/null
FIRST_REPORT_NONEMPTY_OUT="$TMP_DIR/first_report_nonempty_out"
mkdir -p "$FIRST_REPORT_NONEMPTY_OUT"
printf 'keep' >"$FIRST_REPORT_NONEMPTY_OUT/sentinel.txt"
set +e
"$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" \
  --out "$FIRST_REPORT_NONEMPTY_OUT" \
  --max-wall-ms 600000 >/dev/null 2>&1
first_report_nonempty_rc="$?"
set -e
if [[ "$first_report_nonempty_rc" -ne 2 ]]; then
  echo "first-report smoke must refuse non-empty --out before writing" >&2
  exit 4
fi
if [[ "$(cat "$FIRST_REPORT_NONEMPTY_OUT/sentinel.txt")" != "keep" ]] || [[ -e "$FIRST_REPORT_NONEMPTY_OUT/first_report_smoke.json" ]] || [[ -e "$FIRST_REPORT_NONEMPTY_OUT/audit_out" ]] || [[ -e "$FIRST_REPORT_NONEMPTY_OUT/fixture_repo" ]]; then
  echo "first-report smoke non-empty --out refusal must preserve existing files and avoid managed writes" >&2
  exit 4
fi
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_first_report_smoke.schema.json" "$FIRST_REPORT_OUT/first_report_smoke.json" >/dev/null
python3 - "$FIRST_REPORT_OUT/first_report_smoke.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

receipt = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if receipt["schema_version"] != "local_repo_audit_first_report_smoke.v1":
    raise SystemExit("first report smoke schema version mismatch")
for key in ["install_exit_code", "audit_exit_code", "verify_exit_code"]:
    if receipt[key] != 0:
        raise SystemExit(f"first report smoke must record {key}=0")
if receipt["first_report_success"] != 1 or receipt["within_time_budget"] != 1:
    raise SystemExit("first report smoke must prove a verified report inside the time budget")
if receipt["total_wall_ms"] <= 0 or receipt["total_wall_ms"] > receipt["max_wall_ms"]:
    raise SystemExit("first report smoke wall time must be positive and within budget")
if not Path(receipt["report_path"]).is_file():
    raise SystemExit("first report smoke must leave a report artifact")
audit_out = Path(receipt["audit_output"])
if not audit_out.is_dir():
    raise SystemExit("first report smoke must leave a verified audit output directory")
expected_shas = {
    "audit_manifest_sha256": audit_out / "audit_manifest.json",
    "audit_summary_sha256": audit_out / "audit_summary.json",
    "audit_report_sha256": Path(receipt["report_path"]),
}
for key, path in expected_shas.items():
    if receipt[key] != "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest():
        raise SystemExit(f"first report smoke must bind {key}")
if not receipt["cache_key"] or not receipt["run_id"].startswith("run-"):
    raise SystemExit("first report smoke must bind cache key and run id")
for key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready", "design_partner_beta_candidate_ready", "external_network_used"]:
    if receipt[key] != 0:
        raise SystemExit(f"first report smoke must keep {key}=0")
if receipt["fixture_only"] != 1:
    raise SystemExit("first report smoke must stay fixture-only evidence")
PY
cp "$FIRST_REPORT_OUT/first_report_smoke.json" "$TMP_DIR/first_report_smoke.original.json"
python3 - "$FIRST_REPORT_OUT/first_report_smoke.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
receipt = json.loads(path.read_text(encoding="utf-8"))
receipt["audit_report_sha256"] = "sha256:" + ("0" * 64)
path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --verify-existing "$FIRST_REPORT_OUT" >/dev/null 2>&1; then
  echo "first-report smoke verifier must reject receipt artifact sha drift" >&2
  exit 4
fi
cp "$TMP_DIR/first_report_smoke.original.json" "$FIRST_REPORT_OUT/first_report_smoke.json"
"$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --verify-existing "$FIRST_REPORT_OUT" >/dev/null
python3 - "$FIRST_REPORT_OUT/first_report_smoke.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
receipt = json.loads(path.read_text(encoding="utf-8"))
receipt["external_network_used"] = 1
path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --verify-existing "$FIRST_REPORT_OUT" >/dev/null 2>&1; then
  echo "first-report smoke verifier must reject receipt offline boundary drift" >&2
  exit 4
fi
cp "$TMP_DIR/first_report_smoke.original.json" "$FIRST_REPORT_OUT/first_report_smoke.json"
"$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --verify-existing "$FIRST_REPORT_OUT" >/dev/null

python3 - "$FIRST_REPORT_OUT/first_report_smoke.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
receipt = json.loads(path.read_text(encoding="utf-8"))
receipt["max_wall_ms"] = 1
receipt["within_time_budget"] = 0
path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --verify-existing "$FIRST_REPORT_OUT" >/dev/null 2>&1; then
  echo "first-report smoke verifier must require the time budget to be met" >&2
  exit 4
fi
cp "$TMP_DIR/first_report_smoke.original.json" "$FIRST_REPORT_OUT/first_report_smoke.json"
"$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --verify-existing "$FIRST_REPORT_OUT" >/dev/null

set +e
AUDIT_MY_REPO_FIRST_REPORT_TAMPER_BEFORE_VERIFY=1 "$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" \
  --out "$TMP_DIR/first_report_self_verify_tamper" \
  --max-wall-ms 600000 >/dev/null 2>&1
first_report_self_verify_tamper_rc="$?"
set -e
if [[ "$first_report_self_verify_tamper_rc" -ne 1 ]]; then
  echo "first-report smoke must fail when its self-verification detects receipt drift" >&2
  exit 4
fi
if [[ -e "$TMP_DIR/first_report_self_verify_tamper/first_report_smoke.json" ]] || [[ -e "$TMP_DIR/first_report_self_verify_tamper/audit_out" ]] || [[ -e "$TMP_DIR/first_report_self_verify_tamper/fixture_repo" ]]; then
  echo "first-report smoke self-verification failure must not expose managed smoke artifacts" >&2
  exit 4
fi

python3 - "$FIRST_REPORT_OUT/first_report_smoke.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
receipt = json.loads(path.read_text(encoding="utf-8"))
receipt["schema_only_tamper"] = "unexpected"
path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
if "$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --verify-existing "$FIRST_REPORT_OUT" >/dev/null 2>&1; then
  echo "first-report smoke verifier must reject schema-invalid receipt JSON" >&2
  exit 4
fi
cp "$TMP_DIR/first_report_smoke.original.json" "$FIRST_REPORT_OUT/first_report_smoke.json"
"$ROOT_DIR/scripts/audit_my_repo_first_report_smoke.py" --verify-existing "$FIRST_REPORT_OUT" >/dev/null

for idx in 1 2 3; do
  out="$TMP_DIR/out_$idx"
  mkdir -p "$out"
  printf 'keep' >"$out/sentinel.txt"
  "$ROOT_DIR/scripts/audit_my_repo.sh" "$TMP_DIR/repo_$idx" \
    --mode quick \
    --max-queries 12 \
    --out "$out" \
    --namespace synthetic \
    --question "Does this repo prove production readiness?" \
    --generator routehint-tiny >/dev/null

  test "$(cat "$out/sentinel.txt")" = "keep"
  for file in \
    AUDIT_DASHBOARD.html \
    AUDIT_REPORT.md \
    ARCHITECTURE_TRACE.md \
    abstain_rows.csv \
    accuracy_rows.csv \
    accuracy_rows.json \
    artifact_contract_rows.csv \
    audit_dashboard.json \
    audit_findings.csv \
    audit_findings.json \
    audit_findings.jsonl \
    audit_findings.sarif.json \
    audit_invocation.json \
    audit_manifest.json \
    audit_summary.csv \
    audit_summary.json \
    baseline_diff_rows.csv \
    baseline_diff_summary.json \
    BASELINE_DIFF.md \
    citation_spans.csv \
    citation_spans.jsonl \
    citation_correctness_rows.csv \
    citation_correctness_rows.json \
    claim_boundary.md \
    compact_route_hint_rows.csv \
    diagnostics.json \
    exit_code_contract.json \
    grounded_generation_rows.csv \
    mmap_read_trace.jsonl \
    prediction_lineage.jsonl \
    plugin_registry.json \
    plugin_rule_rows.csv \
    resource_envelope.json \
    reproduce.sh \
    sha256sums.txt \
    source_manifest.csv \
    source_snapshot.json \
    suppressed_findings.csv \
    unsupported_claim_rows.csv \
    false_positive_candidate_rows.csv \
    latency_rows.csv \
    manual_review_queue.csv \
    manual_review_queue.json \
    verify.sh \
    phase_timing_rows.csv \
    wrong_answer_guard_rows.csv
  do
    if [[ ! -s "$out/$file" ]]; then
      echo "missing audit product artifact for repo_$idx: $file" >&2
      exit 10
    fi
  done
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_output.schema.json" "$out/audit_manifest.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_diagnostics.schema.json" "$out/diagnostics.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_dashboard.schema.json" "$out/audit_dashboard.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_exit_code_contract.schema.json" "$out/exit_code_contract.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_accuracy_rows.schema.json" "$out/accuracy_rows.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_citation_correctness_rows.schema.json" "$out/citation_correctness_rows.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_invocation.schema.json" "$out/audit_invocation.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_manual_review_queue.schema.json" "$out/manual_review_queue.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_semantic_summary.schema.json" "$out/audit_semantic_summary.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_summary.schema.json" "$out/audit_summary.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_findings.schema.json" "$out/audit_findings.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_sarif.schema.json" "$out/audit_findings.sarif.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_baseline_diff.schema.json" "$out/baseline_diff_summary.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_plugin_registry.schema.json" "$out/plugin_registry.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_resource_envelope.schema.json" "$out/resource_envelope.json" >/dev/null
  "$ROOT_DIR/tools/validate_json_schemas.py" \
    --schema-instance "$ROOT_DIR/schemas/local_repo_audit_source_snapshot.schema.json" "$out/source_snapshot.json" >/dev/null
  "$ROOT_DIR/tools/verify_local_audit.py" "$out" >/dev/null
  "$ROOT_DIR/scripts/audit_my_repo.sh" --verify-existing "$out" >/dev/null
  if [[ -e "$out/.staging" ]]; then
    echo "successful atomic publish must not leave a public .staging directory" >&2
    exit 5
  fi

  cp "$out/sha256sums.txt" "$out/sha256sums.first"
  "$ROOT_DIR/scripts/audit_my_repo.sh" "$TMP_DIR/repo_$idx" \
    --mode quick \
    --max-queries 12 \
    --out "$out" \
    --namespace synthetic \
    --question "Does this repo prove production readiness?" \
    --generator routehint-tiny >/dev/null
  cmp "$out/sha256sums.first" "$out/sha256sums.txt" >/dev/null
  (cd "$TMP_DIR" && "$out/reproduce.sh") >/dev/null
  cmp "$out/sha256sums.first" "$out/sha256sums.txt" >/dev/null
  (cd "$TMP_DIR" && "$out/verify.sh") >/dev/null
  cmp "$out/sha256sums.first" "$out/sha256sums.txt" >/dev/null
  "$ROOT_DIR/tools/verify_local_audit.py" "$out" >/dev/null
  "$ROOT_DIR/scripts/audit_my_repo.sh" --verify-existing "$out" >/dev/null
  if [[ "$idx" == "1" ]]; then
    label_template_out="$TMP_DIR/label_template_$idx"
    "$ROOT_DIR/scripts/audit_my_repo_label_template.py" \
      --audit-output "$out" \
      --out "$label_template_out" \
      --case-id "product_case_$idx" >/dev/null
    "$ROOT_DIR/scripts/audit_my_repo_label_template.py" --verify-existing "$label_template_out" >/dev/null
    "$ROOT_DIR/tools/validate_json_schemas.py" \
      --schema-instance "$ROOT_DIR/schemas/local_repo_audit_label_template.schema.json" "$label_template_out/label_template.json" >/dev/null
    "$ROOT_DIR/tools/validate_json_schemas.py" \
      --schema-instance "$ROOT_DIR/schemas/local_repo_audit_label_template_manifest.schema.json" "$label_template_out/label_template_manifest.json" >/dev/null
    python3 - "$label_template_out" "$out" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

template_out = Path(sys.argv[1])
audit_out = Path(sys.argv[2])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


payload = json.loads((template_out / "label_template.json").read_text(encoding="utf-8"))
manifest = json.loads((template_out / "label_template_manifest.json").read_text(encoding="utf-8"))
with (template_out / "label_template.csv").open(newline="", encoding="utf-8") as handle:
    csv_rows = list(csv.DictReader(handle))
jsonl_rows = [json.loads(line) for line in (template_out / "label_template.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
with (audit_out / "audit_findings.csv").open(newline="", encoding="utf-8") as handle:
    unsuppressed_findings = [row for row in csv.DictReader(handle) if row["suppressed"] == "0"]
with (audit_out / "citation_spans.csv").open(newline="", encoding="utf-8") as handle:
    spans = list(csv.DictReader(handle))
spans_by_finding = {}
for span in spans:
    spans_by_finding.setdefault(span["finding_id"], []).append(span)

if payload["candidate_label_rows"] != len(unsuppressed_findings) or manifest["candidate_label_rows"] != len(unsuppressed_findings):
    raise SystemExit("label template must emit one candidate per unsuppressed finding")
if payload["human_label_rows"] != 0 or manifest["human_label_rows"] != 0:
    raise SystemExit("label template must not count human labels")
if payload["rows"] != jsonl_rows:
    raise SystemExit("label template json/jsonl rows must match")
if len(csv_rows) != len(payload["rows"]):
    raise SystemExit("label template csv row count must match JSON")
for key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready", "design_partner_beta_candidate_ready"]:
    if payload[key] != 0 or manifest[key] != 0:
        raise SystemExit(f"label template must keep {key}=0")
for row in csv_rows:
    if row["template_only"] != "1" or row["human_labeled"] != "0":
        raise SystemExit("label template rows must stay template-only and unlabeled")
    if row["synthetic"] != "1":
        raise SystemExit("synthetic audit output must stamp synthetic=1 on template rows")
    if not row["candidate_label_id"].startswith("product_case_1_"):
        raise SystemExit("label template candidate ids must be case scoped")
    if row["human_expected"] or row["human_expected_abstain"] or row["human_priority"] or row["reviewer_notes"]:
        raise SystemExit("label template human fields must start blank")
    source_spans = spans_by_finding.get(row["source_finding_id"], [])
    if source_spans:
        first = source_spans[0]
        if row["file_path"] != first["file_path"] or row["expected_line_start"] != first["line_start"] or row["expected_span_sha256"] != first["span_sha256"]:
            raise SystemExit("label template must bind the primary citation span")
if manifest["input_audit_manifest_sha256"] != sha256(audit_out / "audit_manifest.json"):
    raise SystemExit("label template manifest must bind input audit manifest sha")
if manifest["artifact_sha256s"]["label_template.json"] != sha256(template_out / "label_template.json"):
    raise SystemExit("label template manifest must bind template JSON sha")
PY
    label_decisions="$TMP_DIR/label_decisions_$idx.jsonl"
    label_intake_out="$TMP_DIR/label_intake_$idx"
    python3 - "$label_template_out" "$label_decisions" <<'PY'
import csv
import json
import sys
from pathlib import Path

template_out = Path(sys.argv[1])
decisions = Path(sys.argv[2])
with (template_out / "label_template.csv").open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
selected = None
for row in rows:
    if row["plugin_id"] != "user_question" and row["expected_line_start"] and row["expected_span_sha256"] and row["suggested_expected_abstain"] == "0":
        selected = row
        break
if selected is None:
    raise SystemExit("expected at least one cited non-abstain candidate label")
decisions.write_text(
    json.dumps(
        {
            "candidate_label_id": selected["candidate_label_id"],
            "human_labeled": True,
            "expected": "present",
            "expected_abstain": selected["suggested_expected_abstain"],
            "priority": "P1",
            "reviewer_id": "product-reviewer-one",
        },
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
PY
    "$ROOT_DIR/scripts/audit_my_repo_label_intake.py" \
      --template "$label_template_out" \
      --decisions "$label_decisions" \
      --out "$label_intake_out" >/dev/null
    "$ROOT_DIR/scripts/audit_my_repo_label_intake.py" --verify-existing "$label_intake_out" >/dev/null
    "$ROOT_DIR/tools/validate_json_schemas.py" \
      --schema-instance "$ROOT_DIR/schemas/local_repo_audit_label_intake_manifest.schema.json" "$label_intake_out/label_intake_manifest.json" >/dev/null
    python3 - "$label_intake_out" "$label_decisions" "$label_template_out" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

intake_out = Path(sys.argv[1])
decisions = Path(sys.argv[2])
template_out = Path(sys.argv[3])
rows = [json.loads(line) for line in (intake_out / "benchmark_labels.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
manifest = json.loads((intake_out / "label_intake_manifest.json").read_text(encoding="utf-8"))
if len(rows) != 1:
    raise SystemExit("compiled benchmark labels must contain exactly one row")
row = rows[0]
if row.get("human_labeled") is not True or row.get("synthetic") is not True:
    raise SystemExit("compiled benchmark label must preserve human_labeled/synthetic evidence boundary")
if row.get("expected") != "present" or row.get("priority") != "P1":
    raise SystemExit("compiled benchmark label must carry human expected/priority fields")
if not row.get("repo_path") or not row.get("plugin_id") or not row.get("rule_id"):
    raise SystemExit("compiled benchmark label must bind repo/plugin/rule")
if not row.get("expected_line_start") or not row.get("expected_span_sha256"):
    raise SystemExit("compiled benchmark label must carry citation expectation")
if manifest["human_label_rows"] != 1 or manifest["label_rows"] != 1:
    raise SystemExit("label intake manifest must count compiled human labels")
if manifest["decisions_input_sha256"] != "sha256:" + hashlib.sha256(decisions.read_bytes()).hexdigest():
    raise SystemExit("label intake manifest must bind decisions input sha")
if manifest["template_manifest_sha256"] != "sha256:" + hashlib.sha256((template_out / "label_template_manifest.json").read_bytes()).hexdigest():
    raise SystemExit("label intake manifest must bind template manifest sha")
for key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready", "design_partner_beta_candidate_ready"]:
    if manifest[key] != 0:
        raise SystemExit(f"label intake manifest must keep {key}=0")
PY
    label_benchmark_out="$TMP_DIR/label_benchmark_$idx"
    "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" \
      --label-intake "$label_intake_out" \
      --out "$label_benchmark_out" \
      --mode quick \
      --namespace synthetic \
      --max-files 20 \
      --max-total-bytes 200000 \
      --max-file-bytes 50000 \
      --max-findings 40 \
      --no-rerun-check >/dev/null
    "$ROOT_DIR/scripts/audit_my_repo_benchmark.py" --verify-existing "$label_benchmark_out" >/dev/null
    python3 - "$label_benchmark_out" "$label_intake_out" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
label_intake_out = Path(sys.argv[2]).resolve()
summary = json.loads((out / "benchmark_summary.json").read_text(encoding="utf-8"))
evaluation = json.loads((out / "benchmark_evaluation.json").read_text(encoding="utf-8"))
manifest = json.loads((out / "benchmark_manifest.json").read_text(encoding="utf-8"))
if summary["human_label_rows"] != 1 or evaluation["metrics"]["human_label_rows"] != 1:
    raise SystemExit("compiled benchmark labels must count as human label rows")
if manifest["label_source_kind"] != "label_intake":
    raise SystemExit("compiled benchmark must bind label_source_kind=label_intake")
if manifest["label_intake_output"] != str(label_intake_out):
    raise SystemExit("compiled benchmark must bind label intake output path")
if manifest["labels_input"] != str(label_intake_out / "benchmark_labels.jsonl"):
    raise SystemExit("compiled benchmark must bind intake benchmark_labels.jsonl")
if manifest["label_intake_manifest_sha256"] != "sha256:" + hashlib.sha256((label_intake_out / "label_intake_manifest.json").read_bytes()).hexdigest():
    raise SystemExit("compiled benchmark must bind label intake manifest sha")
if manifest["label_intake_sha256sums_sha256"] != "sha256:" + hashlib.sha256((label_intake_out / "label_intake_sha256sums.txt").read_bytes()).hexdigest():
    raise SystemExit("compiled benchmark must bind label intake sha manifest sha")
for key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready", "design_partner_beta_candidate_ready"]:
    if summary[key] != 0:
        raise SystemExit(f"synthetic compiled-label benchmark must keep {key}=0")
if summary["product_readiness_calculated_from_real_labels"] != 0:
    raise SystemExit("synthetic compiled-label benchmark must not drive product readiness")
PY
    if "$ROOT_DIR/scripts/audit_my_repo_label_intake.py" \
      --template "$label_template_out" \
      --decisions "$label_decisions" \
      --out "$label_intake_out" >/dev/null 2>&1; then
      echo "label intake must not overwrite existing output without --overwrite" >&2
      exit 5
    fi
    cp "$label_template_out/label_template_manifest.json" "$TMP_DIR/label_template_manifest.original.json"
    cp "$label_template_out/label_template_sha256sums.txt" "$TMP_DIR/label_template_sha256sums.original.txt"
    cp "$label_template_out/label_template.csv" "$TMP_DIR/label_template.original.csv"
    cp "$label_template_out/label_template.json" "$TMP_DIR/label_template.original.json"
    cp "$label_template_out/label_template.jsonl" "$TMP_DIR/label_template.original.jsonl"
    python3 - "$label_template_out" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
manifest_path = out / "label_template_manifest.json"
sha_path = out / "label_template_sha256sums.txt"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["input_audit_cache_key"] = "0" * 64
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest_sha = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{manifest_sha if rel == 'label_template_manifest.json' else digest}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
    if "$ROOT_DIR/scripts/audit_my_repo_label_template.py" --verify-existing "$label_template_out" >/dev/null 2>&1; then
      echo "label-template verifier must reject coordinated input cache-key tamper" >&2
      exit 5
    fi
    cp "$TMP_DIR/label_template_manifest.original.json" "$label_template_out/label_template_manifest.json"
    cp "$TMP_DIR/label_template_sha256sums.original.txt" "$label_template_out/label_template_sha256sums.txt"
    "$ROOT_DIR/scripts/audit_my_repo_label_template.py" --verify-existing "$label_template_out" >/dev/null
    python3 - "$label_template_out" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
manifest_path = out / "label_template_manifest.json"
sha_path = out / "label_template_sha256sums.txt"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["label_template_source_sha256"] = "sha256:" + ("0" * 64)
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
manifest_sha = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{manifest_sha if rel == 'label_template_manifest.json' else digest}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
    if "$ROOT_DIR/scripts/audit_my_repo_label_template.py" --verify-existing "$label_template_out" >/dev/null 2>&1; then
      echo "label-template verifier must reject coordinated tool source sha tamper" >&2
      exit 5
    fi
    cp "$TMP_DIR/label_template_manifest.original.json" "$label_template_out/label_template_manifest.json"
    cp "$TMP_DIR/label_template_sha256sums.original.txt" "$label_template_out/label_template_sha256sums.txt"
    "$ROOT_DIR/scripts/audit_my_repo_label_template.py" --verify-existing "$label_template_out" >/dev/null
    python3 - "$label_template_out" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
csv_path = out / "label_template.csv"
json_path = out / "label_template.json"
jsonl_path = out / "label_template.jsonl"
manifest_path = out / "label_template_manifest.json"
sha_path = out / "label_template_sha256sums.txt"
with csv_path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
fieldnames = list(rows[0].keys())
rows[0]["finding_answer"] = rows[0]["finding_answer"] + " tampered"
rows[0]["finding_answer_sha256"] = "sha256:" + hashlib.sha256(rows[0]["finding_answer"].encode("utf-8")).hexdigest()
with csv_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
payload = json.loads(json_path.read_text(encoding="utf-8"))
payload["rows"] = rows
json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
jsonl_path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
for rel in ["label_template.csv", "label_template.json", "label_template.jsonl"]:
    manifest["artifact_sha256s"][rel] = "sha256:" + hashlib.sha256((out / rel).read_bytes()).hexdigest()
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
updates = {
    "label_template_manifest.json": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
    "label_template.csv": hashlib.sha256(csv_path.read_bytes()).hexdigest(),
    "label_template.json": hashlib.sha256(json_path.read_bytes()).hexdigest(),
    "label_template.jsonl": hashlib.sha256(jsonl_path.read_bytes()).hexdigest(),
}
lines = []
for line in sha_path.read_text(encoding="utf-8").splitlines():
    digest, rel = line.split(None, 1)
    rel = rel.strip()
    lines.append(f"{updates.get(rel, digest)}  {rel}")
sha_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
    if "$ROOT_DIR/scripts/audit_my_repo_label_template.py" --verify-existing "$label_template_out" >/dev/null 2>&1; then
      echo "label-template verifier must reject coordinated row replay tamper" >&2
      exit 5
    fi
    cp "$TMP_DIR/label_template_manifest.original.json" "$label_template_out/label_template_manifest.json"
    cp "$TMP_DIR/label_template_sha256sums.original.txt" "$label_template_out/label_template_sha256sums.txt"
    cp "$TMP_DIR/label_template.original.csv" "$label_template_out/label_template.csv"
    cp "$TMP_DIR/label_template.original.json" "$label_template_out/label_template.json"
    cp "$TMP_DIR/label_template.original.jsonl" "$label_template_out/label_template.jsonl"
    "$ROOT_DIR/scripts/audit_my_repo_label_template.py" --verify-existing "$label_template_out" >/dev/null
    printf 'stale label template artifact\n' >"$label_template_out/stale_label_template.txt"
    if "$ROOT_DIR/scripts/audit_my_repo_label_template.py" --verify-existing "$label_template_out" >/dev/null 2>&1; then
      echo "label-template verifier must reject unmanifested output artifacts" >&2
      exit 5
    fi
    rm "$label_template_out/stale_label_template.txt"
    "$ROOT_DIR/scripts/audit_my_repo_label_template.py" --verify-existing "$label_template_out" >/dev/null
    mkdir "$out/.staging"
    if "$ROOT_DIR/tools/verify_local_audit.py" "$out" >/dev/null 2>&1; then
      echo "local-audit verifier must reject stale public .staging directories" >&2
      exit 5
    fi
    rmdir "$out/.staging"
    "$ROOT_DIR/tools/verify_local_audit.py" "$out" >/dev/null
  fi
done

python3 - "$TMP_DIR" "$ROOT_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
project_root = Path(sys.argv[2]).resolve()


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_text(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_contract(out):
    with (out / "artifact_contract_rows.csv").open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise SystemExit("artifact contract rows must be non-empty")
    for row in rows:
        if row["schema_version"] != "local_repo_audit_artifacts.v1":
            raise SystemExit("artifact contract schema version mismatch")
        artifact = out / row["artifact_path"]
        if not artifact.is_file():
            raise SystemExit(f"contract artifact missing: {row['artifact_path']}")
        if row["artifact_kind"] == "csv":
            with artifact.open(newline="", encoding="utf-8") as handle:
                reader = csv.DictReader(handle)
                actual_columns = list(reader.fieldnames or [])
                actual_rows = list(reader)
            expected_columns = row["required_columns"].split("|") if row["required_columns"] else []
            if actual_columns != expected_columns or row["actual_columns"].split("|") != expected_columns:
                raise SystemExit(f"csv contract columns mismatch: {row['artifact_path']}")
            if int(row["actual_rows"]) != len(actual_rows):
                raise SystemExit(f"csv contract row count mismatch: {row['artifact_path']}")
        elif row["artifact_kind"] == "jsonl":
            actual_rows = [json.loads(line) for line in artifact.read_text(encoding="utf-8").splitlines() if line.strip()]
            actual_keys = sorted({key for payload in actual_rows for key in payload})
            required_keys = sorted(row["required_keys"].split("|")) if row["required_keys"] else []
            if not set(required_keys).issubset(actual_keys):
                raise SystemExit(f"jsonl contract keys mismatch: {row['artifact_path']}")
            if int(row["actual_rows"]) != len(actual_rows):
                raise SystemExit(f"jsonl contract row count mismatch: {row['artifact_path']}")
        elif row["artifact_kind"] == "json":
            payload = json.loads(artifact.read_text(encoding="utf-8"))
            required_keys = row["required_keys"].split("|") if row["required_keys"] else []
            if not set(required_keys).issubset(payload):
                raise SystemExit(f"json contract keys mismatch: {row['artifact_path']}")
        if row["sha256_manifest_required"] != "1" or row["deterministic_required"] != "1":
            raise SystemExit("artifact contract must require sha manifest and deterministic output")
    required_artifacts = {
        "audit_dashboard.json",
        "audit_findings.csv",
        "audit_findings.json",
        "audit_findings.jsonl",
        "audit_findings.sarif.json",
        "audit_semantic_summary.json",
        "citation_spans.csv",
        "citation_spans.jsonl",
        "prediction_lineage.jsonl",
        "baseline_diff_rows.csv",
        "baseline_diff_summary.json",
        "phase_timing_rows.csv",
        "plugin_registry.json",
        "plugin_rule_rows.csv",
        "source_snapshot.json",
        "suppressed_findings.csv",
        "audit_invocation.json",
        "audit_dashboard.json",
        "exit_code_contract.json",
        "audit_manifest.json",
        "audit_summary.json",
        "AUDIT_DASHBOARD.html",
        "AUDIT_REPORT.md",
        "BASELINE_DIFF.md",
        "reproduce.sh",
        "verify.sh",
    }
    seen = {row["artifact_path"] for row in rows}
    if not required_artifacts.issubset(seen):
        raise SystemExit(f"artifact contract missing required artifacts: {sorted(required_artifacts - seen)}")
    return rows


expected_sources = {
    1: "module.py",
    2: "src/index.js",
    3: "src/main.cpp",
}
source_sets = []

for idx in range(1, 4):
    out = root / f"out_{idx}"
    repo = root / f"repo_{idx}"
    manifest = json.loads((out / "audit_manifest.json").read_text(encoding="utf-8"))
    invocation = json.loads((out / "audit_invocation.json").read_text(encoding="utf-8"))
    exit_contract = json.loads((out / "exit_code_contract.json").read_text(encoding="utf-8"))
    if manifest["namespace"] != "synthetic":
        raise SystemExit("generated fixture repos must stay in the synthetic namespace")
    if manifest["real_benchmark_namespace_confirmed"] != 0:
        raise SystemExit("synthetic product smoke must not confirm the real_benchmark namespace")
    if manifest["fixture_result_promoted"] != 0 or manifest["real_evidence_claimed"] != 0:
        raise SystemExit("synthetic product smoke must not promote fixture results or claim real evidence")
    if manifest["tool_version"] != "audit_my_repo_alpha.v1":
        raise SystemExit("audit manifest must expose the tool version")
    if manifest["tool_source_sha256"] != "sha256:" + sha256(project_root / "scripts/audit_my_repo.py"):
        raise SystemExit("audit manifest must bind the audit entrypoint source sha")
    if manifest["schema_sha256s"].get("schemas/local_repo_audit_suppressions.schema.json") != "sha256:" + sha256(project_root / "schemas/local_repo_audit_suppressions.schema.json"):
        raise SystemExit("audit manifest must bind the suppression/allowlist input schema sha")
    if invocation["tool_version"] != manifest["tool_version"]:
        raise SystemExit("audit invocation must expose the tool version")
    if invocation["target_repo"] != str(repo.resolve()) or invocation["out_dir"] != str(out.resolve()):
        raise SystemExit("audit invocation must bind target repo and output directory")
    if invocation["mode"] != "quick" or invocation["max_queries"] != 12 or invocation["generator"] != "routehint-tiny":
        raise SystemExit("audit invocation must bind resolved execution options")
    if invocation["namespace"] != "synthetic" or invocation["real_benchmark_namespace_confirmed"] != 0:
        raise SystemExit("audit invocation must bind namespace confirmation")
    if invocation["source_scope"] != "tracked" or invocation["changed_files_from"] != "" or invocation["changed_files_from_sha256"] != "sha256:" + sha256_text("") or invocation["changed_file_rows"] != 0:
        raise SystemExit("audit invocation must bind empty changed-files defaults")
    if invocation["baseline_output"] != "" or invocation["baseline_output_sha256"] != "sha256:" + sha256_text(""):
        raise SystemExit("audit invocation must bind an empty baseline by default")
    if invocation["verify_output_requested"] != 1:
        raise SystemExit("audit invocation must record default verify-output")
    if invocation.get("emit_diagnostics_requested") != 0:
        raise SystemExit("default opt-out product smoke must not request diagnostics")
    if manifest.get("emit_diagnostics_requested") != 0:
        raise SystemExit("default opt-out product smoke must not bind diagnostics request in manifest")
    diagnostics = json.loads((out / "diagnostics.json").read_text(encoding="utf-8"))
    if diagnostics.get("diagnostics_opt_in") != 0:
        raise SystemExit("default opt-out diagnostics must have diagnostics_opt_in=0")
    if diagnostics.get("diagnostics_collected") != 0:
        raise SystemExit("default opt-out diagnostics must have diagnostics_collected=0")
    if diagnostics.get("external_network_used") != 0:
        raise SystemExit("default opt-out diagnostics must keep external_network_used=0")
    if diagnostics.get("scope") != "none":
        raise SystemExit("default opt-out diagnostics must have scope=none")
    diagnostics_text = json.dumps(diagnostics, sort_keys=True)
    for forbidden in [
        str(repo.resolve()),
        "module.py",
        "src/index.js",
        "src/main.cpp",
        "Does this repo prove production readiness?",
    ]:
        if forbidden in diagnostics_text:
            raise SystemExit(f"default opt-out diagnostics must not contain {forbidden!r}")
    if exit_contract["success_exit_code"] != 0 or exit_contract["artifact_verify_failure_exit_code"] != 1:
        raise SystemExit("exit code contract must bind success and verify failure codes")
    if exit_contract["input_or_publish_error_exit_code"] != 2:
        raise SystemExit("exit code contract must bind input/publish error code")
    if manifest["generated_at_utc"] != "1970-01-01T00:00:00+00:00":
        raise SystemExit("audit manifest timestamp must be deterministic")
    if manifest["atomic_publish"] != 1 or manifest["output_dir_destroyed"] != 0:
        raise SystemExit("audit manifest must prove atomic non-destructive publish")
    if manifest["output_dir_overwritten"] != 0:
        raise SystemExit("audit manifest must prove output artifacts were not overwritten")
    if manifest["publish_mode"] != "versioned-run-dir-with-latest-pointer":
        raise SystemExit("audit manifest publish mode must expose bundle-level latest pointer publishing")
    if manifest["bundle_run_dir"] != str((out / "runs" / manifest["run_id"]).resolve()):
        raise SystemExit("audit manifest must bind the versioned run directory")
    if manifest["latest_pointer"] != str(out / "latest"):
        raise SystemExit("audit manifest must bind the latest pointer")
    if manifest["baseline_output"] != "" or manifest["baseline_output_sha256"] != "sha256:" + sha256_text(""):
        raise SystemExit("audit manifest must bind an empty baseline by default")
    if manifest["source_scope"] != "tracked" or manifest["changed_files_from"] != "" or manifest["changed_files_from_sha256"] != "sha256:" + sha256_text("") or manifest["changed_file_rows"] != 0:
        raise SystemExit("audit manifest must bind empty changed-files defaults")
    summary = json.loads((out / "audit_summary.json").read_text(encoding="utf-8"))
    with (out / "audit_summary.csv").open(newline="", encoding="utf-8") as handle:
        summary_rows = list(csv.DictReader(handle))
    if len(summary_rows) != 1:
        raise SystemExit("audit summary CSV must contain exactly one row")
    if set(summary_rows[0]) != set(summary):
        raise SystemExit("audit summary CSV columns must match audit_summary.json keys")
    for key, value in summary.items():
        if summary_rows[0][key] != str(value):
            raise SystemExit(f"audit summary CSV/JSON mismatch: {key}")
    resource = json.loads((out / "resource_envelope.json").read_text(encoding="utf-8"))
    expected_resource = {
        "tool_version": manifest["tool_version"],
        "source_files_scanned": manifest["source_file_count"],
        "source_scope": summary["source_scope"],
        "changed_file_rows": summary["changed_file_rows"],
        "max_files": summary["max_files"],
        "max_total_bytes": summary["max_total_bytes"],
        "max_file_bytes": summary["max_file_bytes"],
        "max_findings": summary["max_findings"],
        "active_plugin_ids": summary["active_plugin_ids"],
        "suppression_rows": summary["suppression_rows"],
        "mode": summary["mode"],
        "namespace": manifest["namespace"],
        "external_network_used": 0,
        "raw_prompt_context_bytes": summary["raw_prompt_context_bytes"],
        "scan_latency_ms": summary["scan_latency_ms"],
        "plugin_latency_ms": summary["plugin_latency_ms"],
        "serialize_latency_ms": summary["serialize_latency_ms"],
        "verify_latency_ms": summary["verify_latency_ms"],
        "latency_ms": summary["latency_ms"],
        "wrong_answer_guard_rows": summary["wrong_answer_guard_rows"],
        "claim_boundary_ready": summary["claim_boundary_ready"],
    }
    for key, value in expected_resource.items():
        if resource[key] != value:
            raise SystemExit(f"resource envelope mismatch: {key}")
    plugin_registry = json.loads((out / "plugin_registry.json").read_text(encoding="utf-8"))
    plugin_ids = {row["plugin_id"] for row in plugin_registry["plugins"]}
    if plugin_registry["schema_version"] != "local_repo_audit.v1":
        raise SystemExit("plugin registry schema version mismatch")
    if plugin_registry["tool_version"] != "audit_my_repo_alpha.v1":
        raise SystemExit("plugin registry tool version mismatch")
    if plugin_ids != {"doc_code_identity", "deprecated_api", "config_consistency", "unsupported_claim", "missing_evidence", "user_question"}:
        raise SystemExit("plugin registry must bind the deterministic plugin set")
    expected_plugin_modules = {
        "doc_code_identity": "auditor_plugin_doc_code_identity",
        "deprecated_api": "auditor_plugin_deprecated_api",
        "config_consistency": "auditor_plugin_config_consistency",
        "unsupported_claim": "auditor_plugin_unsupported_claim",
        "missing_evidence": "auditor_plugin_missing_evidence",
        "user_question": "auditor_plugin_user_question",
    }
    if {row["plugin_id"]: row.get("module") for row in plugin_registry["plugins"]} != expected_plugin_modules:
        raise SystemExit("plugin registry must bind each deterministic plugin to its module")
    expected_plugin_source_paths = {
        plugin_id: f"scripts/{module}.py"
        for plugin_id, module in expected_plugin_modules.items()
    }
    if {row["plugin_id"]: row.get("source_path") for row in plugin_registry["plugins"]} != expected_plugin_source_paths:
        raise SystemExit("plugin registry must bind each deterministic plugin to its source path")
    for row in plugin_registry["plugins"]:
        source_path = project_root / row["source_path"]
        if row.get("source_sha256") != "sha256:" + sha256(source_path):
            raise SystemExit(f"plugin registry source sha mismatch: {row['plugin_id']}")
    plugin_registry_sha256 = "sha256:" + sha256(out / "plugin_registry.json")
    if manifest["plugin_registry_sha256"] != plugin_registry_sha256:
        raise SystemExit("audit manifest must bind plugin_registry.json sha256")
    with (out / "plugin_rule_rows.csv").open(newline="", encoding="utf-8") as handle:
        plugin_rule_rows = list(csv.DictReader(handle))
    if not plugin_rule_rows:
        raise SystemExit("plugin rule rows must be emitted")
    rule_plugin_ids = {row["plugin_id"] for row in plugin_rule_rows}
    if rule_plugin_ids != plugin_ids:
        raise SystemExit("plugin rule rows must cover every registered plugin")
    deprecated_rule_languages = {
        row["language"]
        for row in plugin_rule_rows
        if row["plugin_id"] == "deprecated_api"
    }
    if not {"python", "cpp", "javascript"}.issubset(deprecated_rule_languages):
        raise SystemExit("deprecated_api rules must expose python/cpp/javascript coverage")
    deprecated_parser_ids = {
        row["parser_id"]
        for row in plugin_rule_rows
        if row["plugin_id"] == "deprecated_api"
    }
    if not {
        "python_ast",
        "cpp_lexical_code_candidate_parser",
        "javascript_typescript_lexical_code_candidate_parser",
    }.issubset(deprecated_parser_ids):
        raise SystemExit("deprecated_api rules must bind parser provenance for python/js-ts/cpp")
    unsupported_parser_ids = {
        row["parser_id"]
        for row in plugin_rule_rows
        if row["plugin_id"] == "unsupported_claim"
    }
    if "claim_boundary_negation_code_literal_filter" not in unsupported_parser_ids:
        raise SystemExit("unsupported_claim rules must bind claim-boundary/code-literal parser provenance")
    if any(row["evidence_policy"] not in {"source-bound-span", "abstain-when-missing-source-bound-span"} for row in plugin_rule_rows):
        raise SystemExit("plugin rule rows must bind a replayable evidence policy")
    if any(not row.get("parser_id") for row in plugin_rule_rows):
        raise SystemExit("plugin rule rows must bind parser provenance")
    plugin_rule_ids = {}
    for row in plugin_rule_rows:
        plugin_rule_ids.setdefault(row["plugin_id"], set()).add(row["rule_id"])
    if summary["real_release_package_ready"] != 0 or summary["release_ready"] != 0 or summary["public_comparison_claim_ready"] != 0 or summary["real_model_execution_ready"] != 0:
        raise SystemExit("audit product smoke must keep release/comparison/model claims blocked")
    phase_sum = summary["scan_latency_ms"] + summary["plugin_latency_ms"] + summary["serialize_latency_ms"] + summary["verify_latency_ms"]
    if summary["latency_ms"] != phase_sum or phase_sum <= 0:
        raise SystemExit("summary latency must equal positive measured phase timings")
    with (out / "phase_timing_rows.csv").open(newline="", encoding="utf-8") as handle:
        phase_rows = list(csv.DictReader(handle))
    if [row["phase"] for row in phase_rows] != ["scan", "plugin", "serialize", "verify"]:
        raise SystemExit("phase timing rows must expose scan/plugin/serialize/verify")
    if any(int(row["wall_ms"]) <= 0 or row["measured"] != "1" for row in phase_rows):
        raise SystemExit("phase timing rows must be measured positive wall-clock values")
    if summary["question_supplied"] != 1:
        raise SystemExit("audit product smoke should record user question support")
    if summary["accuracy_rows"] <= 0 or summary["citation_correctness_rows"] <= 0:
        raise SystemExit("accuracy and citation correctness rows must be recorded separately")
    findings = [json.loads(line) for line in (out / "audit_findings.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    findings_json = json.loads((out / "audit_findings.json").read_text(encoding="utf-8"))
    citations = [json.loads(line) for line in (out / "citation_spans.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    lineage = [json.loads(line) for line in (out / "prediction_lineage.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    mmap_rows = [json.loads(line) for line in (out / "mmap_read_trace.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    sarif = json.loads((out / "audit_findings.sarif.json").read_text(encoding="utf-8"))
    if sarif.get("$schema") != "https://json.schemastore.org/sarif-2.1.0.json" or sarif.get("version") != "2.1.0":
        raise SystemExit("SARIF output must use SARIF 2.1.0")
    if len(sarif.get("runs", [])) != 1:
        raise SystemExit("SARIF output must contain exactly one run")
    sarif_run = sarif["runs"][0]
    sarif_driver = sarif_run.get("tool", {}).get("driver", {})
    if sarif_driver.get("name") != "audit-my-repo" or sarif_driver.get("semanticVersion") != "audit_my_repo_alpha.v1":
        raise SystemExit("SARIF output must bind the audit-my-repo tool version")
    if sarif_run.get("properties", {}).get("release_ready") != 0 or sarif_run.get("properties", {}).get("public_comparison_claim_ready") != 0 or sarif_run.get("properties", {}).get("real_model_execution_ready") != 0:
        raise SystemExit("SARIF output must keep readiness claims blocked")
    sarif_rule_ids = [row.get("id") for row in sarif_driver.get("rules", [])]
    if sarif_rule_ids != [row["rule_id"] for row in plugin_rule_rows]:
        raise SystemExit("SARIF rules must match plugin_rule_rows.csv")
    sarif_results = sarif_run.get("results", [])
    sarif_by_finding = {
        row.get("properties", {}).get("finding_id"): row
        for row in sarif_results
    }
    if list(sarif_by_finding) != [row["finding_id"] for row in findings]:
        raise SystemExit("SARIF results must preserve one result per finding in order")
    citations_by_finding = {}
    for row in citations:
        citations_by_finding.setdefault(row["finding_id"], []).append(row)
    expected_sarif_levels = {"high": "error", "medium": "warning", "low": "note", "info": "note"}
    for finding in findings:
        result = sarif_by_finding.get(finding["finding_id"])
        if result is None:
            raise SystemExit(f"SARIF missing finding: {finding['finding_id']}")
        rule_ids = [cell for cell in finding["plugin_rule_ids"].split("|") if cell]
        if result.get("ruleId") != rule_ids[0]:
            raise SystemExit(f"SARIF ruleId drift: {finding['finding_id']}")
        if result.get("level") != expected_sarif_levels.get(finding["severity"], "note"):
            raise SystemExit(f"SARIF severity drift: {finding['finding_id']}")
        if result.get("message", {}).get("text") != finding["answer"]:
            raise SystemExit(f"SARIF message drift: {finding['finding_id']}")
        properties = result.get("properties", {})
        for key in ["plugin_id", "audit_type", "confidence", "language", "severity"]:
            if properties.get(key) != finding[key]:
                raise SystemExit(f"SARIF property drift: {finding['finding_id']} {key}")
        if properties.get("plugin_rule_ids") != rule_ids:
            raise SystemExit(f"SARIF rule list drift: {finding['finding_id']}")
        if properties.get("citation_sha256s") != [cell for cell in finding["citation_sha256s"].split(";") if cell]:
            raise SystemExit(f"SARIF citation sha drift: {finding['finding_id']}")
        expected_citations = citations_by_finding[finding["finding_id"]]
        if len(result.get("locations", [])) != len(expected_citations):
            raise SystemExit(f"SARIF location count drift: {finding['finding_id']}")
        for location, citation in zip(result.get("locations", []), expected_citations):
            physical = location.get("physicalLocation", {})
            artifact = physical.get("artifactLocation", {})
            region = physical.get("region", {})
            props = physical.get("properties", {})
            if artifact.get("uri") != citation["file_path"]:
                raise SystemExit(f"SARIF location URI drift: {finding['finding_id']}")
            if str(region.get("startLine")) != str(citation["line_start"]) or str(region.get("endLine")) != str(citation["line_end"]):
                raise SystemExit(f"SARIF line span drift: {finding['finding_id']}")
            if props.get("sha256") != citation["sha256"] or props.get("span_sha256") != citation["span_sha256"]:
                raise SystemExit(f"SARIF source hash drift: {finding['finding_id']}")
    for csv_name, jsonl_rows in [
        ("audit_findings.csv", findings),
        ("citation_spans.csv", citations),
    ]:
        with (out / csv_name).open(newline="", encoding="utf-8") as handle:
            csv_rows = list(csv.DictReader(handle))
        if len(csv_rows) != len(jsonl_rows):
            raise SystemExit(f"{csv_name} row count must match jsonl")
        for csv_row, jsonl_row in zip(csv_rows, jsonl_rows):
            if set(csv_row) != set(jsonl_row):
                raise SystemExit(f"{csv_name} columns must match jsonl keys")
            for key, value in jsonl_row.items():
                if csv_row[key] != str(value):
                    raise SystemExit(f"{csv_name} drift: {key}")
    with (out / "source_manifest.csv").open(newline="", encoding="utf-8") as handle:
        source_rows = list(csv.DictReader(handle))
    source_snapshot = json.loads((out / "source_snapshot.json").read_text(encoding="utf-8"))
    source_files = {row["file_path"] for row in source_rows}
    if not findings or not citations or not lineage:
        raise SystemExit("findings, citations, and lineage must be non-empty")
    if not any(row["audit_type"] == "user_question" and row["abstain"] == 1 and row["grounded"] == 0 and row["citations"] for row in findings):
        raise SystemExit("unsupported user question must abstain without a grounded answer while keeping source context")
    if findings_json.get("schema_version") != "local_repo_audit_findings.v1":
        raise SystemExit("standard JSON findings schema version mismatch")
    if findings_json.get("tool_version") != "audit_my_repo_alpha.v1":
        raise SystemExit("standard JSON findings must bind the tool version")
    if findings_json.get("claim_boundary") != "alpha-local-code-doc-audit-only":
        raise SystemExit("standard JSON findings must bind the alpha claim boundary")
    if findings_json.get("release_ready") != 0 or findings_json.get("public_comparison_claim_ready") != 0 or findings_json.get("real_model_execution_ready") != 0:
        raise SystemExit("standard JSON findings must keep readiness claims blocked")
    if findings_json.get("findings") != findings:
        raise SystemExit("standard JSON findings array must match audit_findings.jsonl")
    dashboard = (out / "AUDIT_DASHBOARD.html").read_text(encoding="utf-8")
    dashboard_json = json.loads((out / "audit_dashboard.json").read_text(encoding="utf-8"))
    for snippet in [
        'data-schema-version="local_repo_audit_dashboard.v1"',
        f'data-run-id="{manifest["run_id"]}"',
        f'data-cache-key="{manifest["cache_key"]}"',
        f'data-finding-rows="{summary["finding_rows"]}"',
        'data-release-ready="0"',
        'data-public-comparison-claim-ready="0"',
        'data-real-model-execution-ready="0"',
        "release_ready=0",
        "public_comparison_claim_ready=0",
        "real_model_execution_ready=0",
    ]:
        if snippet not in dashboard:
            raise SystemExit(f"AUDIT_DASHBOARD.html must bind run/readiness metadata: {snippet}")
    if not all(f'data-finding-id="{row["finding_id"]}"' in dashboard for row in findings[:20]):
        raise SystemExit("AUDIT_DASHBOARD.html must include each top finding id")
    if dashboard_json["cache_key"] != manifest["cache_key"] or dashboard_json["run_id"] != manifest["run_id"]:
        raise SystemExit("audit_dashboard.json must bind manifest run/cache identity")
    if dashboard_json["review_counts"]["finding_rows"] != summary["finding_rows"]:
        raise SystemExit("audit_dashboard.json must bind finding row count")
    if dashboard_json["readiness"] != {
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "automatic_accuracy_claimed": 0,
    }:
        raise SystemExit("audit_dashboard.json must keep readiness claims blocked")
    for row in findings:
        rule_ids = [cell for cell in str(row.get("plugin_rule_ids", "")).split("|") if cell]
        if not rule_ids:
            raise SystemExit(f"finding must bind plugin rule provenance: {row['finding_id']}")
        if set(rule_ids) - plugin_rule_ids.get(row["plugin_id"], set()):
            raise SystemExit(f"finding references plugin rules outside its plugin: {row['finding_id']}")
    if any(row["grounded"] == 1 and not row["citations"] for row in findings):
        raise SystemExit("grounded findings must have citations")
    if any(int(row["line_start"]) <= 0 or not row["sha256"].startswith("sha256:") or not row["span_sha256"].startswith("sha256:") for row in citations):
        raise SystemExit("citation rows must bind line numbers, file sha256, and span sha256")
    citation_trace_keys = {
        (row["finding_id"], row["file_path"], str(row["line_start"]), row["sha256"], row["span_sha256"])
        for row in citations
    }
    mmap_trace_keys = {
        (row["finding_id"], row["file_path"], str(row["line_start"]), row["sha256"], row["span_sha256"])
        for row in mmap_rows
    }
    if mmap_trace_keys != citation_trace_keys or len(mmap_rows) != len(citations):
        raise SystemExit("mmap trace rows must exactly bind every citation span hash")
    citation_by_finding_cell = {
        (row["finding_id"], f"{row['file_path']}:{row['line_start']}"): row
        for row in citations
    }
    for row in findings:
        finding_cells = [cell for cell in str(row.get("citations", "")).split(";") if cell]
        finding_sha256s = [cell for cell in str(row.get("citation_sha256s", "")).split(";") if cell]
        if len(finding_cells) != len(finding_sha256s):
            raise SystemExit(f"finding citation sha count drift: {row['finding_id']}")
        for cell, digest in zip(finding_cells, finding_sha256s):
            citation = citation_by_finding_cell.get((row["finding_id"], cell))
            if citation is None:
                raise SystemExit(f"finding citation has no span row: {row['finding_id']} {cell}")
            if digest != citation["sha256"]:
                raise SystemExit(f"finding citation sha drift: {row['finding_id']} {cell}")
    for row in citations:
        cited = repo / row["file_path"]
        if row["file_path"] not in source_files:
            raise SystemExit(f"citation is not listed in source manifest: {row['file_path']}")
        if not cited.is_file():
            raise SystemExit(f"citation target missing: {row['file_path']}")
        if row["sha256"] != "sha256:" + sha256(cited):
            raise SystemExit(f"citation sha does not match file content: {row['file_path']}")
        source_lines = cited.read_text(encoding="utf-8", errors="replace").splitlines()
        line_start = int(row["line_start"])
        if line_start > len(source_lines):
            raise SystemExit(f"citation line is out of range: {row['file_path']}:{line_start}")
        if row["span_text_preview"] != source_lines[line_start - 1].strip()[:280]:
            raise SystemExit(f"citation preview does not match source line: {row['file_path']}:{line_start}")
        span_text = "\n".join(line.strip() for line in source_lines[line_start - 1:int(row["line_end"])])
        if row["span_sha256"] != "sha256:" + sha256_text(span_text):
            raise SystemExit(f"citation span sha does not match source line: {row['file_path']}:{line_start}")
    with (out / "wrong_answer_guard_rows.csv").open(newline="", encoding="utf-8") as handle:
        guards = list(csv.DictReader(handle))
    if not guards or any(row["wrong_answer_guard_pass"] != "1" for row in guards):
        raise SystemExit("wrong-answer guard rows must pass")
    with (out / "accuracy_rows.csv").open(newline="", encoding="utf-8") as handle:
        accuracy_rows = list(csv.DictReader(handle))
    if not accuracy_rows or any(row["automatic_accuracy_claimed"] != "0" for row in accuracy_rows):
        raise SystemExit("automatic accuracy must not be claimed by the alpha smoke")
    accuracy_payload = json.loads((out / "accuracy_rows.json").read_text(encoding="utf-8"))
    if accuracy_payload["accuracy_rows"] != len(accuracy_rows):
        raise SystemExit("accuracy rows JSON row count must match the CSV")
    if accuracy_payload["automatic_accuracy_claimed"] != 0 or accuracy_payload["manual_accuracy_review_required"] != 1:
        raise SystemExit("accuracy rows JSON must preserve manual unreviewed boundary")
    if [{key: str(value) for key, value in row.items()} for row in accuracy_payload["rows"]] != accuracy_rows:
        raise SystemExit("accuracy rows JSON must match accuracy_rows.csv")
    with (out / "citation_correctness_rows.csv").open(newline="", encoding="utf-8") as handle:
        citation_rows = list(csv.DictReader(handle))
    if not citation_rows or any(row["manual_citation_review_required"] != "1" for row in citation_rows):
        raise SystemExit("citation correctness rows must require manual review")
    citation_payload = json.loads((out / "citation_correctness_rows.json").read_text(encoding="utf-8"))
    if citation_payload["citation_correctness_rows"] != len(citation_rows):
        raise SystemExit("citation correctness JSON row count must match the CSV")
    if citation_payload["manual_citation_review_required"] != 1:
        raise SystemExit("citation correctness JSON must require manual citation review")
    if [{key: str(value) for key, value in row.items()} for row in citation_payload["rows"]] != citation_rows:
        raise SystemExit("citation correctness JSON must match citation_correctness_rows.csv")
    with (out / "manual_review_queue.csv").open(newline="", encoding="utf-8") as handle:
        manual_review_rows = list(csv.DictReader(handle))
    manual_review_payload = json.loads((out / "manual_review_queue.json").read_text(encoding="utf-8"))
    if {row["finding_id"] for row in manual_review_rows} != {row["finding_id"] for row in findings}:
        raise SystemExit("manual review queue must contain exactly one row per finding")
    if summary["manual_review_queue_rows"] != len(manual_review_rows):
        raise SystemExit("manual review queue summary row count must match the CSV")
    if any(row["manual_review_required"] != "1" or row["auto_promoted"] != "0" for row in manual_review_rows):
        raise SystemExit("manual review queue must require review and forbid auto-promotion")
    if manual_review_payload["manual_review_queue_rows"] != len(manual_review_rows):
        raise SystemExit("manual review queue JSON row count must match the CSV")
    if [{key: str(value) for key, value in row.items()} for row in manual_review_payload["rows"]] != manual_review_rows:
        raise SystemExit("manual review queue JSON must match manual_review_queue.csv")
    if manual_review_payload["release_ready"] != 0 or manual_review_payload["public_comparison_claim_ready"] != 0 or manual_review_payload["real_model_execution_ready"] != 0:
        raise SystemExit("manual review queue JSON must keep readiness claims blocked")
    baseline_diff_summary = json.loads((out / "baseline_diff_summary.json").read_text(encoding="utf-8"))
    with (out / "baseline_diff_rows.csv").open(newline="", encoding="utf-8") as handle:
        baseline_diff_rows = list(csv.DictReader(handle))
    if baseline_diff_summary["baseline_supplied"] != 0:
        raise SystemExit("product smoke must record missing baseline by default")
    if baseline_diff_summary["baseline_output"] != "" or baseline_diff_summary["baseline_output_sha256"] != "sha256:" + sha256_text(""):
        raise SystemExit("baseline diff summary must bind an empty baseline by default")
    if baseline_diff_summary["current_finding_rows"] != len(findings) or baseline_diff_summary["diff_rows"] != len(baseline_diff_rows):
        raise SystemExit("baseline diff summary counts must match findings and rows")
    if baseline_diff_summary["not_compared_findings"] != len(findings):
        raise SystemExit("no-baseline product smoke must mark every finding not_compared")
    if any(row["diff_status"] != "not_compared" or row["manual_review_required"] != "1" for row in baseline_diff_rows):
        raise SystemExit("no-baseline diff rows must require review and use not_compared status")
    if "release readiness" not in (out / "BASELINE_DIFF.md").read_text(encoding="utf-8"):
        raise SystemExit("BASELINE_DIFF.md must preserve readiness boundary")
    dashboard = json.loads((out / "audit_dashboard.json").read_text(encoding="utf-8"))
    expected_dashboard_diff = {
        key: baseline_diff_summary[key]
        for key in [
            "not_compared_findings",
            "new_findings",
            "changed_findings",
            "resolved_findings",
            "unchanged_findings",
            "manual_review_required_rows",
        ]
    }
    expected_dashboard_review = {
        "finding_rows": summary["finding_rows"],
        "source_files": summary["source_files"],
        "citation_span_rows": summary["citation_span_rows"],
        "abstain_rows": summary["abstain_rows"],
        "unsupported_claim_rows": summary["unsupported_claim_rows"],
        "manual_review_queue_rows": summary["manual_review_queue_rows"],
        "suppression_rows": summary["suppression_rows"],
    }
    if dashboard["schema_version"] != "local_repo_audit_dashboard.v1":
        raise SystemExit("dashboard schema version mismatch")
    if dashboard["tool_version"] != manifest["tool_version"] or dashboard["cache_key"] != manifest["cache_key"] or dashboard["run_id"] != manifest["run_id"]:
        raise SystemExit("dashboard must bind tool version, cache key, and run id")
    if dashboard["target_repo"] != manifest["target_repo"] or dashboard["mode"] != summary["mode"] or dashboard["namespace"] != summary["namespace"] or dashboard["source_scope"] != summary["source_scope"]:
        raise SystemExit("dashboard run metadata drift")
    if dashboard["baseline"]["supplied"] != baseline_diff_summary["baseline_supplied"]:
        raise SystemExit("dashboard baseline supplied drift")
    if dashboard["baseline"]["baseline_output_sha256"] != baseline_diff_summary["baseline_output_sha256"]:
        raise SystemExit("dashboard baseline output sha drift")
    if dashboard["diff_counts"] != expected_dashboard_diff:
        raise SystemExit("dashboard diff counts must mirror baseline_diff_summary.json")
    if dashboard["review_counts"] != expected_dashboard_review:
        raise SystemExit("dashboard review counts must mirror audit_summary.json")
    expected_readiness = {
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "automatic_accuracy_claimed": 0,
    }
    if dashboard["readiness"] != expected_readiness:
        raise SystemExit("dashboard must keep readiness and automatic accuracy blocked")
    expected_links = {
        "audit_report": "AUDIT_REPORT.md",
        "baseline_diff": "BASELINE_DIFF.md",
        "findings_json": "audit_findings.json",
        "findings_sarif": "audit_findings.sarif.json",
        "manual_review_queue": "manual_review_queue.csv",
        "reproduce": "reproduce.sh",
        "verify": "verify.sh",
    }
    if dashboard["links"] != expected_links:
        raise SystemExit("dashboard artifact links drift")
    for linked in expected_links.values():
        if not (out / linked).is_file():
            raise SystemExit(f"dashboard link target missing: {linked}")
    expected_top_findings = []
    for row in findings[:20]:
        finding_citations = [cell for cell in row["citations"].split(";") if cell]
        expected_top_findings.append({
            "finding_id": row["finding_id"],
            "plugin_id": row["plugin_id"],
            "rule_ids": [cell for cell in row["plugin_rule_ids"].split("|") if cell],
            "severity": row["severity"],
            "confidence": row["confidence"],
            "language": row["language"],
            "grounded": int(row["grounded"]),
            "abstain": int(row["abstain"]),
            "unsupported_claim": int(row["unsupported_claim"]),
            "suppressed": int(row["suppressed"]),
            "citation_count": len(finding_citations),
            "primary_citation": finding_citations[0] if finding_citations else "",
            "citation_sha256s": [cell for cell in row["citation_sha256s"].split(";") if cell],
            "answer_preview": row["answer"][:220],
        })
    if dashboard["top_findings"] != expected_top_findings:
        raise SystemExit("dashboard top findings must mirror audit_findings.jsonl")
    dashboard_html = (out / "AUDIT_DASHBOARD.html").read_text(encoding="utf-8")
    for snippet in [
        "audit-my-repo dashboard",
        f"Cache key <code>{manifest['cache_key']}</code>",
        "release_ready=0",
        "public_comparison_claim_ready=0",
        "real_model_execution_ready=0",
        "automatic_accuracy_claimed=0",
        "audit_dashboard.json",
        "manual_review_queue.csv",
        "local source-bound change triage only",
    ]:
        if snippet not in dashboard_html:
            raise SystemExit(f"dashboard HTML missing required snippet: {snippet}")
    source_sets.append(tuple(sorted(source_files)))
    if expected_sources[idx] not in source_files:
        raise SystemExit(f"repo_{idx} source manifest missing expected source: {expected_sources[idx]}")
    if len(source_files) != len(source_rows):
        raise SystemExit("source manifest file paths must be unique")
    for row in source_rows:
        source_path = repo / row["file_path"]
        if not source_path.is_file():
            raise SystemExit(f"source manifest target missing: {row['file_path']}")
        if row["sha256"] != "sha256:" + sha256(source_path):
            raise SystemExit(f"source manifest sha mismatch: {row['file_path']}")
        if int(row["bytes"]) != source_path.stat().st_size:
            raise SystemExit(f"source manifest byte count mismatch: {row['file_path']}")
        if row["route_memory_source"] != "1":
            raise SystemExit(f"source manifest route_memory_source mismatch: {row['file_path']}")
    if source_snapshot["schema_version"] != "local_repo_audit_source_snapshot.v1":
        raise SystemExit("source snapshot schema_version mismatch")
    if source_snapshot["tool_version"] != manifest["tool_version"]:
        raise SystemExit("source snapshot tool_version mismatch")
    if source_snapshot["target_repo"] != str(repo.resolve()):
        raise SystemExit("source snapshot target repo mismatch")
    if source_snapshot["source_manifest_sha256"] != "sha256:" + sha256(out / "source_manifest.csv"):
        raise SystemExit("source snapshot must bind source_manifest.csv sha256")
    if source_snapshot["source_file_count"] != len(source_rows):
        raise SystemExit("source snapshot source_file_count mismatch")
    if source_snapshot["git_available"] != 1:
        raise SystemExit("source snapshot must record git availability for product smoke repos")
    if source_snapshot["git_dirty"] != 0:
        raise SystemExit("source snapshot must record clean product smoke repos")
    if len(source_snapshot["git_head"]) != 40:
        raise SystemExit("source snapshot must record the git HEAD sha")
    expected_cache_key = hashlib.sha256(json.dumps({
        "tool_version": "audit_my_repo_alpha.v1",
        "tool_source_sha256": "sha256:" + sha256(project_root / "scripts/audit_my_repo.py"),
        "verifier_source_sha256": "sha256:" + sha256(project_root / "tools/verify_local_audit.py"),
        "schema_sha256s": {
            rel: "sha256:" + sha256(project_root / rel)
            for rel in [
                "schemas/local_repo_audit_output.schema.json",
                "schemas/local_repo_audit_diagnostics.schema.json",
                "schemas/local_repo_audit_dashboard.schema.json",
                "schemas/local_repo_audit_exit_code_contract.schema.json",
                "schemas/local_repo_audit_accuracy_rows.schema.json",
                "schemas/local_repo_audit_citation_correctness_rows.schema.json",
                "schemas/local_repo_audit_findings.schema.json",
                "schemas/local_repo_audit_invocation.schema.json",
                "schemas/local_repo_audit_manual_review_queue.schema.json",
                "schemas/local_repo_audit_semantic_summary.schema.json",
                "schemas/local_repo_audit_summary.schema.json",
                "schemas/local_repo_audit_sarif.schema.json",
                "schemas/local_repo_audit_baseline_diff.schema.json",
                "schemas/local_repo_audit_plugin_registry.schema.json",
                "schemas/local_repo_audit_plugin_rules.schema.json",
                "schemas/local_repo_audit_resource_envelope.schema.json",
                "schemas/local_repo_audit_source_snapshot.schema.json",
                "schemas/local_repo_audit_suppressions.schema.json",
            ]
        },
        "target": str((root / f"repo_{idx}").resolve()),
        "source": [(row["file_path"], row["sha256"]) for row in source_rows],
        "source_snapshot": source_snapshot,
        "source_scope": "tracked",
        "changed_files_from": "",
        "changed_files_from_sha256": "sha256:" + sha256_text(""),
        "changed_file_rows": 0,
        "mode": "quick",
        "max_queries": 12,
        "max_files": 64,
        "max_total_bytes": 2000000,
        "max_file_bytes": 300000,
        "max_findings": 12,
        "active_plugin_ids": ["doc_code_identity", "deprecated_api", "unsupported_claim"],
        "suppression_file_sha256": "sha256:" + sha256_text(""),
        "baseline_output": "",
        "baseline_output_sha256": "sha256:" + sha256_text(""),
        "namespace": "synthetic",
        "real_benchmark_namespace_confirmed": 0,
        "question": "Does this repo prove production readiness?",
        "verify_output_requested": 1,
        "emit_report_requested": 1,
        "emit_lineage_requested": 1,
        "emit_reproduce_requested": 1,
        "emit_diagnostics_requested": 0,
        "plugin_registry_sha256": plugin_registry_sha256,
    }, sort_keys=True).encode("utf-8")).hexdigest()
    if manifest["cache_key"] != expected_cache_key:
        raise SystemExit("audit manifest cache key does not match source/query/plugin inputs")
    contract_rows = read_contract(out)
    manifest_rows = {}
    for line in (out / "sha256sums.txt").read_text(encoding="utf-8").splitlines():
        digest, rel = line.split(None, 1)
        manifest_rows[rel] = digest
    for rel in [
        "AUDIT_DASHBOARD.html",
        "AUDIT_REPORT.md",
        "ARCHITECTURE_TRACE.md",
        "accuracy_rows.csv",
        "artifact_contract_rows.csv",
        "audit_dashboard.json",
        "audit_invocation.json",
        "audit_manifest.json",
        "audit_summary.json",
        "audit_findings.json",
        "audit_findings.jsonl",
        "audit_findings.sarif.json",
        "baseline_diff_rows.csv",
        "baseline_diff_summary.json",
        "BASELINE_DIFF.md",
        "citation_spans.jsonl",
        "citation_correctness_rows.csv",
        "diagnostics.json",
        "exit_code_contract.json",
        "manual_review_queue.csv",
        "prediction_lineage.jsonl",
        "phase_timing_rows.csv",
        "plugin_registry.json",
        "plugin_rule_rows.csv",
        "source_snapshot.json",
        "suppressed_findings.csv",
        "reproduce.sh",
        "verify.sh",
    ]:
        if manifest_rows.get(rel) != sha256(out / rel):
            raise SystemExit(f"sha256 mismatch: {rel}")
    for row in contract_rows:
        if row["sha256_manifest_required"] == "1" and row["artifact_path"] not in manifest_rows:
            raise SystemExit(f"contract artifact missing from sha256 manifest: {row['artifact_path']}")
    reproduce_text = (out / "reproduce.sh").read_text(encoding="utf-8")
    if "--question 'Does this repo prove production readiness?'" not in reproduce_text:
        raise SystemExit("reproduce.sh must preserve the user question")
    verify_text = (out / "verify.sh").read_text(encoding="utf-8")
    if f"--verify-existing {out}" not in verify_text:
        raise SystemExit("verify.sh must preserve the output directory verification command")
if len(set(source_sets)) != 3:
    raise SystemExit("product smoke must exercise three distinct unseen local repository shapes")
PY

# Changed-file scoped runs must audit only the caller-provided relative
# paths, bind the file-list sha into the artifact contract, and reproduce
# the same scoped command.
CHANGED_LIST="$TMP_DIR/changed_files_repo_2.txt"
printf 'src/index.js\n' >"$CHANGED_LIST"
CHANGED_OUT="$TMP_DIR/out_changed_scope"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$TMP_DIR/repo_2" \
  --mode quick \
  --max-queries 12 \
  --changed-files-from "$CHANGED_LIST" \
  --out "$CHANGED_OUT" \
  --namespace synthetic \
  --question "Changed-file scoped smoke question?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$CHANGED_OUT" >/dev/null
python3 - "$CHANGED_OUT" "$TMP_DIR/repo_2" "$CHANGED_LIST" "$TMP_DIR/out_2" <<'PY'
import csv
import hashlib
import json
import shlex
import sys
from pathlib import Path

out = Path(sys.argv[1])
repo = Path(sys.argv[2]).resolve()
changed_list = Path(sys.argv[3]).resolve()
tracked_out = Path(sys.argv[4])

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

manifest = json.loads((out / "audit_manifest.json").read_text(encoding="utf-8"))
invocation = json.loads((out / "audit_invocation.json").read_text(encoding="utf-8"))
summary = json.loads((out / "audit_summary.json").read_text(encoding="utf-8"))
resource = json.loads((out / "resource_envelope.json").read_text(encoding="utf-8"))
source_rows = list(csv.DictReader(open(out / "source_manifest.csv", newline="", encoding="utf-8")))
tracked_manifest = json.loads((tracked_out / "audit_manifest.json").read_text(encoding="utf-8"))

expected_changed_sha = "sha256:" + sha256(changed_list)
for payload_name, payload in [("manifest", manifest), ("invocation", invocation)]:
    if payload.get("source_scope") != "changed-files":
        raise SystemExit(f"{payload_name} must record changed-files source_scope")
    if payload.get("changed_files_from") != str(changed_list):
        raise SystemExit(f"{payload_name} must bind changed_files_from path")
    if payload.get("changed_files_from_sha256") != expected_changed_sha:
        raise SystemExit(f"{payload_name} must bind changed_files_from sha")
    if payload.get("changed_file_rows") != 1:
        raise SystemExit(f"{payload_name} must record one changed file row")
if summary.get("source_scope") != "changed-files" or summary.get("changed_file_rows") != 1:
    raise SystemExit("summary must record changed-file scope")
if resource.get("source_scope") != "changed-files" or resource.get("changed_file_rows") != 1:
    raise SystemExit("resource envelope must record changed-file scope")
if [row["file_path"] for row in source_rows] != ["src/index.js"]:
    raise SystemExit("changed-file scope must only audit the requested source file")
if summary.get("source_files") != 1 or manifest.get("source_file_count") != 1:
    raise SystemExit("changed-file scope must report one scanned source file")
if manifest.get("cache_key") == tracked_manifest.get("cache_key"):
    raise SystemExit("changed-file scope must produce a distinct cache key from tracked scope")
findings = list(csv.DictReader(open(out / "audit_findings.csv", newline="", encoding="utf-8")))
deprecated = [row for row in findings if row["plugin_id"] == "deprecated_api"]
if not deprecated or "src/index.js" not in deprecated[0].get("citations", ""):
    raise SystemExit("changed-file deprecated finding must cite the scoped JS file")
if "module.py" in json.dumps(findings) or "src/main.cpp" in json.dumps(findings):
    raise SystemExit("changed-file findings must not cite files outside the scoped source manifest")
reproduce_parts = shlex.split((out / "reproduce.sh").read_text(encoding="utf-8").splitlines()[-1])
if reproduce_parts[reproduce_parts.index("--changed-files-from") + 1] != str(changed_list):
    raise SystemExit("reproduce.sh must preserve --changed-files-from")
if manifest.get("target_repo") != str(repo):
    raise SystemExit("manifest target_repo mismatch for changed-file run")
PY

BAD_CHANGED_LIST="$TMP_DIR/bad_changed_files.txt"
printf '../outside.py\n' >"$BAD_CHANGED_LIST"
if "$ROOT_DIR/scripts/audit_my_repo.sh" "$TMP_DIR/repo_2" \
  --mode quick \
  --max-queries 12 \
  --changed-files-from "$BAD_CHANGED_LIST" \
  --out "$TMP_DIR/out_bad_changed_scope" \
  --namespace synthetic >/dev/null 2>&1; then
  echo "changed-files input escaping the target repo must fail" >&2
  exit 1
fi

# PR wrapper runs must derive a stable changed-files input from local git refs,
# keep that input available for reproduce.sh, and reject caller-supplied
# changed-files lists.
PR_REPO="$TMP_DIR/repo_pr"
make_repo "$PR_REPO" "Audit Target PR" "audit-target-pr" python
PR_BASE="$(git -C "$PR_REPO" rev-parse HEAD)"
cat >>"$PR_REPO/module.py" <<'EOF'

import distutils

def changed_api_name():
    return distutils.__name__
EOF
git -C "$PR_REPO" add module.py
git -C "$PR_REPO" -c user.email=audit@example.invalid -c user.name=Audit commit -q -m "pr change"
PR_HEAD="$(git -C "$PR_REPO" rev-parse HEAD)"
PR_OUT="$TMP_DIR/out_pr_scope"
"$ROOT_DIR/scripts/audit_my_repo_pr.sh" "$PR_REPO" \
  --base-ref "$PR_BASE" \
  --head-ref "$PR_HEAD" \
  --mode quick \
  --max-queries 12 \
  --out "$PR_OUT" \
  --namespace synthetic \
  --question "PR scoped smoke question?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$PR_OUT" >/dev/null
python3 - "$PR_OUT" "$PR_REPO" <<'PY'
import csv
import hashlib
import json
import shlex
import sys
from pathlib import Path

out = Path(sys.argv[1]).resolve()
repo = Path(sys.argv[2]).resolve()

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

manifest = json.loads((out / "audit_manifest.json").read_text(encoding="utf-8"))
invocation = json.loads((out / "audit_invocation.json").read_text(encoding="utf-8"))
summary = json.loads((out / "audit_summary.json").read_text(encoding="utf-8"))
resource = json.loads((out / "resource_envelope.json").read_text(encoding="utf-8"))
source_rows = list(csv.DictReader(open(out / "source_manifest.csv", newline="", encoding="utf-8")))
findings = list(csv.DictReader(open(out / "audit_findings.csv", newline="", encoding="utf-8")))

changed_from = Path(manifest.get("changed_files_from", "")).resolve()
if changed_from.parent != out or not changed_from.name.startswith("pr_changed_files_"):
    raise SystemExit("PR wrapper must preserve changed-files input next to --out")
if changed_from.read_text(encoding="utf-8") != "module.py\n":
    raise SystemExit("PR wrapper changed-files input must contain the local PR diff")
expected_changed_sha = "sha256:" + sha256(changed_from)

for payload_name, payload in [("manifest", manifest), ("invocation", invocation)]:
    if payload.get("source_scope") != "changed-files":
        raise SystemExit(f"{payload_name} must record changed-files source_scope for PR wrapper")
    if payload.get("changed_files_from") != str(changed_from):
        raise SystemExit(f"{payload_name} must bind the preserved PR changed-files path")
    if payload.get("changed_files_from_sha256") != expected_changed_sha:
        raise SystemExit(f"{payload_name} must bind the PR changed-files sha")
    if payload.get("changed_file_rows") != 1:
        raise SystemExit(f"{payload_name} must record one changed file row for PR wrapper")
if summary.get("source_scope") != "changed-files" or summary.get("changed_file_rows") != 1:
    raise SystemExit("PR wrapper summary must record changed-file scope")
if resource.get("source_scope") != "changed-files" or resource.get("changed_file_rows") != 1:
    raise SystemExit("PR wrapper resource envelope must record changed-file scope")
if [row["file_path"] for row in source_rows] != ["module.py"]:
    raise SystemExit("PR wrapper must only scan changed auditable files")
if manifest.get("target_repo") != str(repo):
    raise SystemExit("PR wrapper manifest target_repo mismatch")
deprecated = [row for row in findings if row["plugin_id"] == "deprecated_api"]
if not deprecated or "module.py" not in deprecated[0].get("citations", ""):
    raise SystemExit("PR wrapper deprecated finding must cite changed module.py")
reproduce_parts = shlex.split((out / "reproduce.sh").read_text(encoding="utf-8").splitlines()[-1])
if reproduce_parts[reproduce_parts.index("--changed-files-from") + 1] != str(changed_from):
    raise SystemExit("PR wrapper reproduce.sh must preserve the stable changed-files input")
PY

if "$ROOT_DIR/scripts/audit_my_repo_pr.sh" "$PR_REPO" \
  --base-ref "$PR_BASE" \
  --head-ref "$PR_HEAD" \
  --changed-files-from "$CHANGED_LIST" \
  --out "$TMP_DIR/out_pr_conflicting_changed_files" >/dev/null 2>&1; then
  echo "PR wrapper must reject explicit --changed-files-from" >&2
  exit 1
fi

if "$ROOT_DIR/scripts/audit_my_repo_pr.sh" "$PR_REPO" \
  --base-ref "$PR_BASE" \
  --head-ref "$PR_HEAD" \
  --out "$TMP_DIR/out_pr_changed_files_after_dashdash" \
  -- --changed-files-from "$CHANGED_LIST" >/dev/null 2>&1; then
  echo "PR wrapper must reject --changed-files-from after --" >&2
  exit 1
fi

if env -u AUDIT_MY_REPO_PR_BASE_REF "$ROOT_DIR/scripts/audit_my_repo_pr.sh" "$PR_REPO" \
  --head-ref "$PR_HEAD" \
  --out "$TMP_DIR/out_pr_missing_base" >/dev/null 2>&1; then
  echo "PR wrapper must reject missing base refs" >&2
  exit 1
fi

if "$ROOT_DIR/scripts/audit_my_repo_pr.sh" "$PR_REPO" \
  --base-ref does-not-exist \
  --head-ref "$PR_HEAD" \
  --out "$TMP_DIR/out_pr_bad_base" >/dev/null 2>&1; then
  echo "PR wrapper must reject missing local base refs" >&2
  exit 1
fi

if "$ROOT_DIR/scripts/audit_my_repo_pr.sh" "$PR_REPO" \
  --base-ref "$PR_BASE" \
  --head-ref does-not-exist \
  --out "$TMP_DIR/out_pr_bad_head" >/dev/null 2>&1; then
  echo "PR wrapper must reject missing local head refs" >&2
  exit 1
fi

PR_INSIDE_OUT="$PR_REPO/.audit-pr-out"
if "$ROOT_DIR/scripts/audit_my_repo_pr.sh" "$PR_REPO" \
  --base-ref "$PR_BASE" \
  --head-ref "$PR_HEAD" \
  --out "$PR_INSIDE_OUT" >/dev/null 2>&1; then
  echo "PR wrapper must reject --out inside the audited repo" >&2
  exit 1
fi
if [ -e "$PR_INSIDE_OUT" ]; then
  echo "PR wrapper must reject in-repo --out before writing wrapper artifacts" >&2
  exit 1
fi

PR_EMPTY_OUT="$TMP_DIR/out_pr_empty_diff"
if "$ROOT_DIR/scripts/audit_my_repo_pr.sh" "$PR_REPO" \
  --base-ref "$PR_HEAD" \
  --head-ref "$PR_HEAD" \
  --out "$PR_EMPTY_OUT" >/dev/null 2>&1; then
  echo "PR wrapper must reject empty local diffs" >&2
  exit 1
fi
if [ -d "$PR_EMPTY_OUT" ] && find "$PR_EMPTY_OUT" -maxdepth 1 -name 'pr_changed_files_*.txt' | grep -q .; then
  echo "PR wrapper must not preserve changed-files input for empty diff failures" >&2
  exit 1
fi

PR_BAD_ARG_OUT="$TMP_DIR/out_pr_bad_forwarded_arg"
if "$ROOT_DIR/scripts/audit_my_repo_pr.sh" "$PR_REPO" \
  --base-ref "$PR_BASE" \
  --head-ref "$PR_HEAD" \
  --out "$PR_BAD_ARG_OUT" \
  --generator unsupported-generator >/dev/null 2>&1; then
  echo "PR wrapper must fail when forwarded audit args are invalid" >&2
  exit 1
fi
if [ -d "$PR_BAD_ARG_OUT" ] && find "$PR_BAD_ARG_OUT" -maxdepth 1 -name 'pr_changed_files_*.txt' | grep -q .; then
  echo "PR wrapper must remove generated changed-files input after core input failures" >&2
  exit 1
fi

# Explicit opt-in run must emit coarse-run-metrics diagnostics and bind the
# flag into the invocation, manifest, cache key, and reproduce command.
DIAG_OUT="$TMP_DIR/out_diagnostics"
mkdir -p "$DIAG_OUT"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$TMP_DIR/repo_1" \
  --mode quick \
  --max-queries 12 \
  --out "$DIAG_OUT" \
  --namespace synthetic \
  --question "Diagnostics opt-in smoke question?" \
  --generator routehint-tiny \
  --emit-diagnostics >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$DIAG_OUT" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_diagnostics.schema.json" "$DIAG_OUT/diagnostics.json" >/dev/null
python3 - "$DIAG_OUT" "$TMP_DIR/repo_1" <<'PY'
import csv
import json
import shlex
import sys
from pathlib import Path

out = Path(sys.argv[1])
repo = Path(sys.argv[2]).resolve()

manifest = json.loads((out / "audit_manifest.json").read_text(encoding="utf-8"))
invocation = json.loads((out / "audit_invocation.json").read_text(encoding="utf-8"))
diagnostics = json.loads((out / "diagnostics.json").read_text(encoding="utf-8"))
summary = json.loads((out / "audit_summary.json").read_text(encoding="utf-8"))

if manifest.get("emit_diagnostics_requested") != 1:
    raise SystemExit("opt-in run must bind emit_diagnostics_requested=1 in manifest")
if invocation.get("emit_diagnostics_requested") != 1:
    raise SystemExit("opt-in run must bind emit_diagnostics_requested=1 in invocation")
if diagnostics.get("diagnostics_opt_in") != 1:
    raise SystemExit("opt-in diagnostics must have diagnostics_opt_in=1")
if diagnostics.get("diagnostics_collected") != 1:
    raise SystemExit("opt-in diagnostics must have diagnostics_collected=1")
if diagnostics.get("external_network_used") != 0:
    raise SystemExit("opt-in diagnostics must keep external_network_used=0")
if diagnostics.get("scope") != "coarse-run-metrics":
    raise SystemExit("opt-in diagnostics must use scope=coarse-run-metrics")
for key in ["mode", "namespace", "max_files", "max_total_bytes", "max_file_bytes", "max_findings", "finding_rows", "suppression_rows", "scan_latency_ms", "plugin_latency_ms", "serialize_latency_ms", "verify_latency_ms", "latency_ms"]:
    if str(diagnostics.get(key)) != str(summary.get(key)):
        raise SystemExit(f"opt-in diagnostics {key} must mirror summary")
if str(diagnostics.get("source_file_count")) != str(summary.get("source_files")):
    raise SystemExit("opt-in diagnostics source_file_count must mirror summary source_files")
if diagnostics.get("max_queries") != 12:
    raise SystemExit("opt-in diagnostics max_queries must bind the run budget")
if diagnostics.get("active_plugin_ids") != summary.get("active_plugin_ids", "").split("|"):
    raise SystemExit("opt-in diagnostics active_plugin_ids must match summary")
if int(diagnostics.get("latency_ms", 0)) != int(diagnostics.get("scan_latency_ms", 0)) + int(diagnostics.get("plugin_latency_ms", 0)) + int(diagnostics.get("serialize_latency_ms", 0)) + int(diagnostics.get("verify_latency_ms", 0)):
    raise SystemExit("opt-in diagnostics latency_ms must equal measured phase sum")
for blocked in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready", "real_release_package_ready", "gpu_speedup_claim"]:
    if blocked in diagnostics:
        raise SystemExit(f"opt-in diagnostics must not contain readiness claim {blocked}")
diagnostics_text = json.dumps(diagnostics, sort_keys=True)
for forbidden in [str(repo), "module.py", "Does this repo prove production readiness?", "Diagnostics opt-in smoke question?"]:
    if forbidden in diagnostics_text:
        raise SystemExit(f"opt-in diagnostics must not contain {forbidden!r}")
reproduce_parts = shlex.split((out / "reproduce.sh").read_text(encoding="utf-8").splitlines()[-1])
if "--emit-diagnostics" not in reproduce_parts:
    raise SystemExit("reproduce.sh must include --emit-diagnostics in opt-in mode")
PY

# Default run must keep diagnostics in opt-out mode with only the minimal
# disabled proof and no leakage of source, citation, or question text.
DIAG_DEFAULT_OUT="$TMP_DIR/out_diagnostics_default"
mkdir -p "$DIAG_DEFAULT_OUT"
"$ROOT_DIR/scripts/audit_my_repo.sh" "$TMP_DIR/repo_1" \
  --mode quick \
  --max-queries 12 \
  --out "$DIAG_DEFAULT_OUT" \
  --namespace synthetic \
  --question "Default diagnostics opt-out smoke question?" \
  --generator routehint-tiny >/dev/null
"$ROOT_DIR/tools/verify_local_audit.py" "$DIAG_DEFAULT_OUT" >/dev/null
"$ROOT_DIR/tools/validate_json_schemas.py" \
  --schema-instance "$ROOT_DIR/schemas/local_repo_audit_diagnostics.schema.json" "$DIAG_DEFAULT_OUT/diagnostics.json" >/dev/null
python3 - "$DIAG_DEFAULT_OUT" <<'PY'
import csv
import json
import shlex
import sys
from pathlib import Path

out = Path(sys.argv[1])

manifest = json.loads((out / "audit_manifest.json").read_text(encoding="utf-8"))
invocation = json.loads((out / "audit_invocation.json").read_text(encoding="utf-8"))
diagnostics = json.loads((out / "diagnostics.json").read_text(encoding="utf-8"))

if manifest.get("emit_diagnostics_requested") != 0:
    raise SystemExit("default run must keep emit_diagnostics_requested=0 in manifest")
if invocation.get("emit_diagnostics_requested") != 0:
    raise SystemExit("default run must keep emit_diagnostics_requested=0 in invocation")
if diagnostics.get("diagnostics_opt_in") != 0:
    raise SystemExit("default diagnostics must keep diagnostics_opt_in=0")
if diagnostics.get("diagnostics_collected") != 0:
    raise SystemExit("default diagnostics must keep diagnostics_collected=0")
if diagnostics.get("scope") != "none":
    raise SystemExit("default diagnostics scope must be 'none'")
if diagnostics.get("reason") != "default-opt-out":
    raise SystemExit("default diagnostics reason must be 'default-opt-out'")
if diagnostics.get("external_network_used") != 0:
    raise SystemExit("default diagnostics must keep external_network_used=0")
expected_keys = {
    "schema_version", "tool_version", "diagnostics_opt_in",
    "diagnostics_collected", "external_network_used", "scope", "reason",
}
if set(diagnostics) != expected_keys:
    raise SystemExit(f"default diagnostics must contain exactly the minimal opt-out keys: {set(diagnostics) ^ expected_keys}")
diagnostics_text = json.dumps(diagnostics, sort_keys=True)
for source_rel in [row["file_path"] for row in csv.DictReader(open(out / "source_manifest.csv", encoding="utf-8"))]:
    if source_rel in diagnostics_text:
        raise SystemExit(f"default diagnostics must not include source path: {source_rel}")
for row in csv.DictReader(open(out / "audit_findings.csv", encoding="utf-8")):
    if row.get("question") and row["question"] in diagnostics_text:
        raise SystemExit("default diagnostics must not include question text")
if str(manifest.get("target_repo", "")) in diagnostics_text:
    raise SystemExit("default diagnostics must not include target repo path")
forbidden_substrings = [".env", "secret", "question_text"]
for snippet in forbidden_substrings:
    if snippet in diagnostics_text:
        raise SystemExit(f"default diagnostics must not contain forbidden substring: {snippet}")
reproduce_parts = shlex.split((out / "reproduce.sh").read_text(encoding="utf-8").splitlines()[-1])
if "--emit-diagnostics" in reproduce_parts:
    raise SystemExit("reproduce.sh must not include --emit-diagnostics in default opt-out mode")
PY

echo "audit_my_repo product entrypoint smoke passed"
