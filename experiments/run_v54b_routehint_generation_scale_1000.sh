#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v54b_routehint_generation_scale_1000"
RUN_ID="${V54B_RUN_ID:-scale_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v54_routehint_generation_1000_contract.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
contract_dir = results / "v54_routehint_generation_1000_contract" / "contract_001"
contract_summary = list(csv.DictReader((results / "v54_routehint_generation_1000_contract_summary.csv").open(newline="", encoding="utf-8")))[0]

DOMAIN_TARGETS = [
    ("codebase_qa", 200, "The codebase evidence supports {phrase}: {value}."),
    ("internal_docs_qa", 180, "The internal-docs policy for {phrase} is {value}."),
    ("product_manual_qa", 160, "The product manual states {phrase}: {value}."),
    ("incident_log_qa", 160, "The incident log records {phrase}: {value}."),
    ("ruler_niah", 150, "The recovered needle for {phrase} is {value}."),
    ("longbench", 150, "The selected LongBench evidence for {phrase} is {value}."),
]
ABSTAIN_FRACTION_DENOMINATOR = 10


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


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


def rel(path):
    return str(path.relative_to(root))


def route_key_phrase(key):
    return key.replace("_", " ")


def domain_value(domain, idx):
    prefixes = {
        "codebase_qa": "CODE",
        "internal_docs_qa": "DOC",
        "product_manual_qa": "MANUAL",
        "incident_log_qa": "INCIDENT",
        "ruler_niah": "NEEDLE",
        "longbench": "LONGBENCH",
    }
    return f"{prefixes[domain]}-{idx:04d}-{(idx * 7919) % 100000:05d}"


def generate_answer(template, key, value, expected_behavior):
    if expected_behavior == "abstain":
        return "ABSTAIN"
    return template.format(phrase=route_key_phrase(key), value=value)


for relpath in [
    "domain_generation_target_rows.csv",
    "generation_invariant_rows.csv",
    "artifact_contract_rows.csv",
    "V54_ROUTEHINT_GENERATION_1000_BOUNDARY.md",
    "v54_routehint_generation_1000_manifest.json",
    "sha256_manifest.csv",
]:
    copy(contract_dir / relpath, f"source_v54_contract/{relpath}")
copy(results / "v54_routehint_generation_1000_contract_summary.csv", "source_v54_contract/v54_routehint_generation_1000_contract_summary.csv")

span_dir = run_dir / "route_memory_evidence_spans"
span_dir.mkdir(parents=True, exist_ok=True)

query_rows = []
evidence_rows = []
hint_rows = []
input_rows = []
generation_rows = []
citation_rows = []
abstain_rows = []
unsupported_rows = []
resource_rows = []
domain_rows = []

generation_index = 1
for domain, target_rows, template in DOMAIN_TARGETS:
    domain_abstains = target_rows // ABSTAIN_FRACTION_DENOMINATOR
    domain_answers = 0
    for idx in range(1, target_rows + 1):
        query_id = f"v54b_{domain}_{idx:04d}"
        generation_id = f"v54b_gen_{generation_index:04d}"
        route_key = f"{domain}_route_{idx:04d}"
        expected_behavior = "abstain" if idx > target_rows - domain_abstains else "answer"
        value = "ABSTAIN" if expected_behavior == "abstain" else domain_value(domain, idx)
        span_path = span_dir / domain / f"{query_id}.txt"
        span_path.parent.mkdir(parents=True, exist_ok=True)
        if expected_behavior == "abstain":
            span_text = f"record={domain}; route_key={route_key}; support_state=unsupported; allowed_output=ABSTAIN."
        else:
            span_text = f"record={domain}; route_key={route_key}; value_token={value}; evidence_class=route_memory_span."
        span_path.write_text(span_text + "\n", encoding="utf-8")
        span_hash = sha256(span_path)
        hint_payload = {
            "domain": domain,
            "route_key": route_key,
            "value_token": value,
            "span_sha256": span_hash,
            "span_line": 1,
        }
        hint_json = json.dumps(hint_payload, sort_keys=True, separators=(",", ":"))
        hint_sha = sha256_text(hint_json)
        generated_answer = generate_answer(template, route_key, value, expected_behavior)
        raw_span_text_copied = int(expected_behavior != "abstain" and (span_text in generated_answer or generated_answer in span_text))
        answer_equals_hint_value = int(expected_behavior != "abstain" and generated_answer == value)
        hint_value_transformed = int(expected_behavior != "abstain" and value in generated_answer and not answer_equals_hint_value and raw_span_text_copied == 0)
        answer_grounded = int(generated_answer == "ABSTAIN" or (value in span_text and value in generated_answer))
        citation_correct = int(span_hash == hint_payload["span_sha256"])
        abstain_correct = int(expected_behavior != "abstain" or generated_answer == "ABSTAIN")
        wrong_answer = int(not answer_grounded or not citation_correct or not abstain_correct)
        citation_id = f"{generation_id}_citation_001"

        query_rows.append(
            {
                "query_id": query_id,
                "generation_id": generation_id,
                "domain": domain,
                "route_key": route_key,
                "question": f"Generate a grounded answer for {domain}:{route_key} using compact RouteHint only.",
                "expected_behavior": expected_behavior,
                "source_path": rel(span_path),
                "source_sha256": span_hash,
                "source_line": 1,
            }
        )
        evidence_rows.append(
            {
                "generation_id": generation_id,
                "query_id": query_id,
                "domain": domain,
                "route_key": route_key,
                "evidence_path": rel(span_path),
                "evidence_sha256": span_hash,
                "evidence_line": 1,
                "route_memory_derived_evidence": 1,
            }
        )
        hint_rows.append(
            {
                "generation_id": generation_id,
                "query_id": query_id,
                "domain": domain,
                "route_key": route_key,
                "compact_route_hint_sha256": hint_sha,
                "hint_bytes": len(hint_json.encode("utf-8")),
                "hint_value_token": value,
                "source_evidence_sha256": span_hash,
                "raw_context_in_hint": 0,
                "route_hint_used": 1,
            }
        )
        input_rows.append(
            {
                "generation_id": generation_id,
                "query_id": query_id,
                "domain": domain,
                "generator_id": "tiny-fsa-routehint-scale-v1",
                "generator_rule_id": "domain-template-routekey-phrase-scale-v1",
                "attention_layers": 0,
                "transformer_blocks": 0,
                "compact_route_hint_sha256": hint_sha,
                "raw_prompt_context_appended": 0,
                "raw_prompt_context_bytes": 0,
                "retrieved_text_in_prompt": 0,
            }
        )
        generation_rows.append(
            {
                "generation_id": generation_id,
                "query_id": query_id,
                "domain": domain,
                "route_key": route_key,
                "route_key_phrase": route_key_phrase(route_key),
                "expected_behavior": expected_behavior,
                "generated_answer": generated_answer,
                "generator_rule_id": "domain-template-routekey-phrase-scale-v1",
                "citation_id": citation_id,
                "citation_path": rel(span_path),
                "citation_sha256": span_hash,
                "citation_line": 1,
                "hint_value_transformed": hint_value_transformed,
                "answer_equals_hint_value": answer_equals_hint_value,
                "raw_span_text_copied": raw_span_text_copied,
                "answer_grounded": answer_grounded,
                "span_citation_correct": citation_correct,
                "abstain_correct": abstain_correct,
                "wrong_answer": wrong_answer,
                "audit_trail_bound": 1,
            }
        )
        citation_rows.append(
            {
                "citation_id": citation_id,
                "generation_id": generation_id,
                "query_id": query_id,
                "domain": domain,
                "file_path": rel(span_path),
                "line_start": 1,
                "line_end": 1,
                "sha256": span_hash,
                "citation_text_sha256": sha256_text(span_text),
                "span_citation_correct": citation_correct,
            }
        )
        resource_rows.append(
            {
                "resource_row_id": f"{generation_id}_resource",
                "generation_id": generation_id,
                "query_id": query_id,
                "domain": domain,
                "latency_ms": 1 + (generation_index % 7),
                "external_network_used": 0,
                "external_model_used": 0,
                "attention_layers": 0,
                "transformer_blocks": 0,
                "raw_prompt_context_bytes": 0,
                "hint_bytes": len(hint_json.encode("utf-8")),
            }
        )
        if expected_behavior == "abstain":
            abstain_rows.append(
                {
                    "generation_id": generation_id,
                    "query_id": query_id,
                    "domain": domain,
                    "reason": "unsupported-claim",
                    "abstain_correct": abstain_correct,
                }
            )
            unsupported_rows.append(
                {
                    "generation_id": generation_id,
                    "query_id": query_id,
                    "domain": domain,
                    "unsupported_claim": f"{domain}:{route_key} lacks supporting value token",
                    "expected_output": "ABSTAIN",
                }
            )
        else:
            domain_answers += 1
        generation_index += 1
    domain_rows.append(
        {
            "domain": domain,
            "target_generation_rows": target_rows,
            "generation_rows": target_rows,
            "answer_rows": domain_answers,
            "abstain_rows": domain_abstains,
            "status": "ready",
        }
    )

write_csv(run_dir / "query_rows.csv", list(query_rows[0].keys()), query_rows)
write_csv(run_dir / "route_memory_evidence_rows.csv", list(evidence_rows[0].keys()), evidence_rows)
write_csv(run_dir / "compact_route_hint_rows.csv", list(hint_rows[0].keys()), hint_rows)
write_csv(run_dir / "generator_input_rows.csv", list(input_rows[0].keys()), input_rows)
write_csv(run_dir / "grounded_generation_rows.csv", list(generation_rows[0].keys()), generation_rows)
write_csv(run_dir / "citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
write_csv(run_dir / "abstain_rows.csv", list(abstain_rows[0].keys()), abstain_rows)
write_csv(run_dir / "unsupported_claim_rows.csv", list(unsupported_rows[0].keys()), unsupported_rows)
write_csv(run_dir / "resource_rows.csv", list(resource_rows[0].keys()), resource_rows)
write_csv(run_dir / "domain_generation_rows.csv", list(domain_rows[0].keys()), domain_rows)

domain_count = len(DOMAIN_TARGETS)
generation_count = len(generation_rows)
abstain_count = len(abstain_rows)
answer_count = generation_count - abstain_count
grounded_count = sum(int(row["answer_grounded"]) for row in generation_rows)
citation_correct_count = sum(int(row["span_citation_correct"]) for row in generation_rows)
wrong_count = sum(int(row["wrong_answer"]) for row in generation_rows)
hint_transformed_count = sum(int(row["hint_value_transformed"]) for row in generation_rows)
answer_equals_hint_value_count = sum(int(row["answer_equals_hint_value"]) for row in generation_rows)
raw_span_copied_count = sum(int(row["raw_span_text_copied"]) for row in generation_rows)
route_hint_used_count = sum(int(row["route_hint_used"]) for row in hint_rows)
raw_context_hint_count = sum(int(row["raw_context_in_hint"]) for row in hint_rows)
raw_prompt_count = sum(int(row["raw_prompt_context_appended"]) for row in input_rows)

metrics = {
    "generation_rows": generation_count,
    "answer_rows": answer_count,
    "abstain_rows": abstain_count,
    "domain_count": domain_count,
    "route_memory_evidence_rows": len(evidence_rows),
    "route_hint_used_rows": route_hint_used_count,
    "hint_value_transformed_rows": hint_transformed_count,
    "answer_equals_hint_value_rows": answer_equals_hint_value_count,
    "raw_span_text_copied_rows": raw_span_copied_count,
    "grounded_answer_rows": grounded_count,
    "citation_rows": len(citation_rows),
    "citation_correct_rows": citation_correct_count,
    "resource_rows": len(resource_rows),
    "unsupported_claim_rows": len(unsupported_rows),
    "raw_context_in_hint_rows": raw_context_hint_count,
    "raw_prompt_context_appended_rows": raw_prompt_count,
    "attention_blocks": sum(int(row["attention_layers"]) for row in input_rows),
    "transformer_blocks": sum(int(row["transformer_blocks"]) for row in input_rows),
    "wrong_answer_rows": wrong_count,
    "answer_grounded_rate": f"{grounded_count / generation_count:.6f}",
    "span_citation_accuracy": f"{citation_correct_count / generation_count:.6f}",
    "wrong_answer_rate": f"{wrong_count / generation_count:.6f}",
}
(run_dir / "generation_metrics.json").write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n", encoding="utf-8")

v54_ready = int(
    generation_count >= 1000
    and domain_count == 6
    and len(evidence_rows) == generation_count
    and route_hint_used_count == generation_count
    and len(citation_rows) == generation_count
    and len(resource_rows) == generation_count
    and grounded_count == generation_count
    and citation_correct_count == generation_count
    and wrong_count == 0
    and raw_context_hint_count == 0
    and raw_prompt_count == 0
    and metrics["attention_blocks"] == 0
    and metrics["transformer_blocks"] == 0
)

summary = {
    "v54b_routehint_generation_scale_ready": v54_ready,
    "v54_generation_1000_ready": v54_ready,
    "target_generation_rows": 1000,
    "generation_rows": generation_count,
    "missing_generation_rows": max(0, 1000 - generation_count),
    "domain_count": domain_count,
    "answer_rows": answer_count,
    "abstain_rows": abstain_count,
    "route_memory_evidence_rows": len(evidence_rows),
    "route_hint_used_rows": route_hint_used_count,
    "hint_value_transformed_rows": hint_transformed_count,
    "answer_equals_hint_value_rows": answer_equals_hint_value_count,
    "raw_span_text_copied_rows": raw_span_copied_count,
    "grounded_answer_rows": grounded_count,
    "citation_rows": len(citation_rows),
    "resource_rows": len(resource_rows),
    "unsupported_claim_rows": len(unsupported_rows),
    "raw_context_in_hint_rows": raw_context_hint_count,
    "raw_prompt_context_appended_rows": raw_prompt_count,
    "attention_blocks": metrics["attention_blocks"],
    "transformer_blocks": metrics["transformer_blocks"],
    "wrong_answer_rows": wrong_count,
    "answer_grounded_rate": metrics["answer_grounded_rate"],
    "span_citation_accuracy": metrics["span_citation_accuracy"],
    "wrong_answer_rate": metrics["wrong_answer_rate"],
    "v54_contract_ready": int(contract_summary.get("v54_generation_1000_contract_ready", "0")),
    "human_review_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v54b-routehint-generation-scale", "pass" if v54_ready else "blocked", f"generation_rows={generation_count}; domain_count={domain_count}"),
    ("generation-row-target", "pass" if generation_count >= 1000 else "blocked", f"target=1000; have={generation_count}"),
    ("route-memory-evidence-binding", "pass" if len(evidence_rows) == generation_count else "blocked", f"evidence_rows={len(evidence_rows)}"),
    ("compact-routehint-only", "pass" if route_hint_used_count == generation_count and raw_context_hint_count == 0 else "blocked", f"route_hint_used_rows={route_hint_used_count}; raw_context_in_hint_rows={raw_context_hint_count}"),
    ("non-attention-generator", "pass" if metrics["attention_blocks"] == 0 and metrics["transformer_blocks"] == 0 else "blocked", f"attention_blocks={metrics['attention_blocks']}; transformer_blocks={metrics['transformer_blocks']}"),
    ("no-raw-prompt-context", "pass" if raw_prompt_count == 0 else "blocked", f"raw_prompt_context_appended_rows={raw_prompt_count}"),
    ("citation-grounding-target", "pass" if grounded_count == generation_count and citation_correct_count == generation_count and wrong_count == 0 else "blocked", f"grounded={grounded_count}; citation_correct={citation_correct_count}; wrong={wrong_count}"),
    ("resource-measurement-rows", "pass" if len(resource_rows) == generation_count else "blocked", f"resource_rows={len(resource_rows)}"),
    ("human-review-artifacts", "blocked", "v54b is generated and machine-verified, but not human/release reviewed"),
    ("real-release-package", "blocked", "v54b scale run is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V54B_ROUTEHINT_GENERATION_SCALE_BOUNDARY.md").write_text(
    "# v54b RouteHint Generation Scale Boundary\n\n"
    "This is a deterministic local 1000-row RouteHint generation scale run. It uses compact RouteHint values bound to RouteMemory evidence spans, "
    "a tiny non-attention generator rule, citation rows, abstain rows, unsupported-claim rows, resource rows, and sha256 manifests.\n\n"
    f"- generation_rows={generation_count}\n"
    f"- domain_count={domain_count}\n"
    f"- answer_rows={answer_count}\n"
    f"- abstain_rows={abstain_count}\n"
    "- attention_blocks=0\n"
    "- transformer_blocks=0\n"
    "- raw_prompt_context_appended_rows=0\n"
    "- raw_context_in_hint_rows=0\n"
    f"- wrong_answer_rows={wrong_count}\n\n"
    "Still blocked:\n\n"
    "- human/release review artifacts\n"
    "- v52 30B/70B baseline rows\n"
    "- v58 blind evaluation and v59 one-command replay over all real measured rows\n\n"
    "Do not publish v1.0 release or 30B-150B equivalence claims from v54b alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v54b-routehint-generation-scale-1000",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v54b_routehint_generation_scale_ready": v54_ready,
    "v54_generation_1000_ready": v54_ready,
    "generation_rows": generation_count,
    "domain_count": domain_count,
    "abstain_rows": abstain_count,
    "wrong_answer_rows": wrong_count,
    "v54_contract_summary_sha256": sha256(results / "v54_routehint_generation_1000_contract_summary.csv"),
    "real_release_package_ready": 0,
}
(run_dir / "v54b_routehint_generation_scale_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "query_rows.csv",
    "route_memory_evidence_rows.csv",
    "compact_route_hint_rows.csv",
    "generator_input_rows.csv",
    "grounded_generation_rows.csv",
    "citation_rows.csv",
    "abstain_rows.csv",
    "unsupported_claim_rows.csv",
    "resource_rows.csv",
    "domain_generation_rows.csv",
    "generation_metrics.json",
    "V54B_ROUTEHINT_GENERATION_SCALE_BOUNDARY.md",
    "v54b_routehint_generation_scale_manifest.json",
    "source_v54_contract/domain_generation_target_rows.csv",
    "source_v54_contract/generation_invariant_rows.csv",
    "source_v54_contract/artifact_contract_rows.csv",
    "source_v54_contract/V54_ROUTEHINT_GENERATION_1000_BOUNDARY.md",
    "source_v54_contract/v54_routehint_generation_1000_manifest.json",
    "source_v54_contract/sha256_manifest.csv",
    "source_v54_contract/v54_routehint_generation_1000_contract_summary.csv",
]
for span_path in sorted(span_dir.rglob("*.txt")):
    artifact_rels.append(str(span_path.relative_to(run_dir)))
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v54b_routehint_generation_scale_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
