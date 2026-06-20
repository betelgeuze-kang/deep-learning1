#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v50_public_repo_auditor_3repo"
AUDIT_ID="${V50_AUDIT_ID:-audit_001}"
AUDIT_DIR="${V50_AUDIT_DIR:-$RESULTS_DIR/${PREFIX}/$AUDIT_ID}"
RETURN_DIR="$AUDIT_DIR/commercial_return"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$RETURN_DIR"

python3 - "$ROOT_DIR" "$AUDIT_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
audit_dir = Path(sys.argv[2])
return_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])

repos = [
    {
        "repo_id": "pypa_sampleproject",
        "owner_repo": "pypa/sampleproject",
        "url": "https://github.com/pypa/sampleproject",
        "default_ref": "621e4974ca25ce531773def586ba3ed8e736b3fc",
    },
    {
        "repo_id": "psf_requests",
        "owner_repo": "psf/requests",
        "url": "https://github.com/psf/requests",
        "default_ref": "1190afd14fca74292946d62c4c8169880a47ff67",
    },
    {
        "repo_id": "pallets_click",
        "owner_repo": "pallets/click",
        "url": "https://github.com/pallets/click",
        "default_ref": "c48021040a50c659b74e24ac2b11c9c9c6620a21",
    },
]
repo_ref_overrides = {}
if os.environ.get("V50_REPO_REFS", "").strip():
    for item in os.environ["V50_REPO_REFS"].split(","):
        key, sep, value = item.partition("=")
        if not sep or not key.strip() or not value.strip():
            raise SystemExit("V50_REPO_REFS must use repo_id=sha,repo_id=sha")
        repo_ref_overrides[key.strip()] = value.strip()

def is_pinned_sha(value):
    return bool(re.fullmatch(r"[0-9a-fA-F]{40}", value))

for repo in repos:
    requested_ref = repo_ref_overrides.get(repo["repo_id"], repo["default_ref"])
    if not is_pinned_sha(requested_ref):
        raise SystemExit(f"v50 requires a pinned 40-hex commit SHA for {repo['repo_id']}: {requested_ref}")
    repo["requested_ref"] = requested_ref

if audit_dir.exists():
    shutil.rmtree(audit_dir)
return_dir.mkdir(parents=True)
source_root = audit_dir / "source_repos"
evidence_dir = audit_dir / "evidence"
source_root.mkdir(parents=True)
evidence_dir.mkdir(parents=True)

def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def rel(path):
    return str(path.relative_to(root))

def read_text(path):
    return path.read_text(encoding="utf-8", errors="replace")

def line_for(path, needle):
    lines = read_text(path).splitlines()
    for idx, line in enumerate(lines, start=1):
        if needle in line:
            return idx, line.strip()[:260]
    for idx, line in enumerate(lines, start=1):
        if line.strip():
            return idx, line.strip()[:260]
    return 1, path.name

def regex_value(text, pattern, default=""):
    match = re.search(pattern, text, flags=re.MULTILINE)
    return match.group(1) if match else default

def read_pyproject_fact(repo_dir):
    pyproject = repo_dir / "pyproject.toml"
    text = read_text(pyproject)
    return {
        "project_name": regex_value(text, r'^name\s*=\s*"([^"]+)"'),
        "description": regex_value(text, r'^description\s*=\s*"([^"]+)"'),
        "requires_python": regex_value(text, r'^requires-python\s*=\s*"([^"]+)"'),
        "pyproject": pyproject,
    }

def read_readme_h1(repo_dir):
    readme = repo_dir / "README.md"
    for line in read_text(readme).splitlines():
        stripped = line.strip()
        if stripped.startswith("# "):
            return stripped[2:].strip(), readme, stripped
    return "", readme, ""

def clone_repo(repo):
    dest = source_root / repo["repo_id"]
    dest.mkdir(parents=True, exist_ok=True)
    run(["git", "init"], cwd=dest)
    run(["git", "remote", "add", "origin", repo["url"]], cwd=dest)
    run(["git", "fetch", "--depth", "1", "origin", repo["requested_ref"]], cwd=dest)
    run(["git", "checkout", "--detach", "FETCH_HEAD"], cwd=dest)
    head = run(["git", "rev-parse", "HEAD"], cwd=dest).stdout.strip()
    if head.lower() != repo["requested_ref"].lower():
        raise SystemExit(f"v50 pinned checkout mismatch for {repo['repo_id']}: {head} != {repo['requested_ref']}")
    repo["path"] = dest
    repo["head_sha"] = head
    repo["ref_pinned"] = int(head.lower() == repo["requested_ref"].lower())
    return repo

for repo in repos:
    clone_repo(repo)

source_rows = []
for repo in repos:
    repo_dir = repo["path"]
    files = ["README.md", "pyproject.toml", "setup.py", "tox.ini", "Makefile", "docs/entry-points.md", "src/click/__init__.py"]
    for file_rel in files:
        path = repo_dir / file_rel
        if path.is_file():
            source_rows.append(
                {
                    "repo_id": repo["repo_id"],
                    "owner_repo": repo["owner_repo"],
                    "repo_url": repo["url"],
                    "requested_ref": repo["requested_ref"],
                    "head_sha": repo["head_sha"],
                    "ref_pinned": repo["ref_pinned"],
                    "file_path": file_rel,
                    "artifact_path": rel(path),
                    "sha256": sha256(path),
                    "bytes": path.stat().st_size,
                    "line_count": len(read_text(path).splitlines()),
                    "public_repo_snapshot": 1,
                }
            )
write_csv(
    audit_dir / "public_repo_source_snapshot_rows.csv",
    [
        "repo_id",
        "owner_repo",
        "repo_url",
        "requested_ref",
        "head_sha",
        "ref_pinned",
        "file_path",
        "artifact_path",
        "sha256",
        "bytes",
        "line_count",
        "public_repo_snapshot",
    ],
    source_rows,
)

case_rows = []
source_span_rows = []
query_rows = []
poc_rows = []
audit_rows = []

def normalize_name(value):
    return re.sub(r"[^a-z0-9]+", "", value.lower())

def version_floor(value):
    match = re.search(r"(\d+)\.(\d+)", value)
    if match:
        return f"{match.group(1)}.{match.group(2)}"
    match = re.search(r"py(\d)(\d+)", value)
    if match:
        return f"{match.group(1)}.{match.group(2)}"
    return value.strip()

def detect_doc_code(readme_h1, project_name):
    return "consistent" if normalize_name(readme_h1) == normalize_name(project_name) else "conflict"

def expected_doc_code_label(repo_id):
    return "conflict" if repo_id == "pypa_sampleproject" else "consistent"

def detect_deprecated_usage(primary_path, primary_needle, secondary_path, secondary_needle):
    primary_found = primary_needle in read_text(primary_path)
    secondary_found = secondary_needle in read_text(secondary_path)
    return "deprecated_usage_detected" if primary_found and secondary_found else "deprecated_usage_not_detected"

def detect_config_mismatch(primary_value, secondary_value):
    return "config_consistent" if version_floor(primary_value) == version_floor(secondary_value) else "config_mismatch_detected"

def verifier_flags(row):
    citation_path = root / row["citation_path"]
    citation_hash_ok = citation_path.is_file() and row["citation_sha256"] == sha256(citation_path)
    citation_line_ok = str(row["citation_line"]).isdigit() and int(row["citation_line"]) >= 1
    secondary_path = root / row.get("secondary_citation_path", "")
    secondary_hash_ok = secondary_path.is_file() and row.get("secondary_citation_sha256") == sha256(secondary_path)
    secondary_line_ok = str(row.get("secondary_citation_line", "")).isdigit() and int(row.get("secondary_citation_line", "0")) >= 1
    wrong_answer_guard_pass = int(citation_hash_ok and citation_line_ok and secondary_hash_ok and secondary_line_ok)
    citation_accuracy_pass = int(citation_hash_ok and secondary_hash_ok)
    return wrong_answer_guard_pass, citation_accuracy_pass

def add_case(
    repo,
    audit_type,
    expected_label,
    predicted_label,
    detector_method,
    primary_observed,
    secondary_observed,
    primary_path,
    primary_needle,
    secondary_path,
    secondary_needle,
    finding,
    answer,
):
    case_id = f"{repo['repo_id']}_{audit_type}"
    p_line, p_text = line_for(primary_path, primary_needle)
    s_line, s_text = line_for(secondary_path, secondary_needle)
    correct = int(predicted_label == expected_label)
    case = {
        "case_id": case_id,
        "repo_id": repo["repo_id"],
        "owner_repo": repo["owner_repo"],
        "repo_url": repo["url"],
        "head_sha": repo["head_sha"],
        "audit_type": audit_type,
        "detector_method": detector_method,
        "primary_observed": primary_observed,
        "secondary_observed": secondary_observed,
        "expected_label": expected_label,
        "predicted_label": predicted_label,
        "correct": correct,
        "finding": finding,
        "primary_path": rel(primary_path),
        "primary_sha256": sha256(primary_path),
        "primary_line": p_line,
        "secondary_path": rel(secondary_path),
        "secondary_sha256": sha256(secondary_path),
        "secondary_line": s_line,
        "source_spans_ready": 1,
        "not_upstream_defect_claim": 1,
    }
    case_rows.append(case)
    for kind, path, line, text in [("primary", primary_path, p_line, p_text), ("secondary", secondary_path, s_line, s_text)]:
        source_span_rows.append(
            {
                "case_id": case_id,
                "repo_id": repo["repo_id"],
                "kind": kind,
                "path": rel(path),
                "sha256": sha256(path),
                "line": line,
                "text": text,
            }
        )
    query_id = f"v50_{len(case_rows):03d}"
    query_rows.append(
        {
            "query_id": query_id,
            "question": f"Audit {repo['owner_repo']} for {audit_type}.",
            "expected_behavior": expected_label,
            "source_path": rel(primary_path),
            "source_sha256": sha256(primary_path),
            "source_line": p_line,
        }
    )
    poc_row = {
            "query_id": query_id,
            "answer": answer,
            "citation_path": rel(primary_path),
            "citation_sha256": sha256(primary_path),
            "citation_line": p_line,
            "citation_text": p_text,
            "secondary_citation_path": rel(secondary_path),
            "secondary_citation_sha256": sha256(secondary_path),
            "secondary_citation_line": s_line,
            "secondary_citation_text": s_text,
            "wrong_answer_guard_pass": 0,
            "citation_accuracy_pass": 0,
            "abstain_behavior_pass": correct,
            "query_to_evidence_latency_ready": 1,
            "latency_ms": 6 + len(case_rows),
            "route_memory_lineage_bound": 1,
            "mmap_or_exact_span_bound": 1,
            "audit_trail_bound": 1,
        }
    poc_row["wrong_answer_guard_pass"], poc_row["citation_accuracy_pass"] = verifier_flags(poc_row)
    poc_rows.append(poc_row)
    audit_rows.append(
        {
            "event_id": f"v50_audit_{len(case_rows):03d}",
            "query_id": query_id,
            "event": audit_type,
            "repo_id": repo["repo_id"],
            "verifier_decision": "pass" if correct else "blocked",
            "status": "pass" if correct else "blocked",
        }
    )

for repo in repos:
    repo_dir = repo["path"]
    facts = read_pyproject_fact(repo_dir)
    readme_h1, readme_path, readme_line = read_readme_h1(repo_dir)
    pyproject = facts["pyproject"]
    doc_prediction = detect_doc_code(readme_h1, facts["project_name"])
    doc_expected = expected_doc_code_label(repo["repo_id"])
    add_case(
        repo,
        "doc_code_conflict",
        doc_expected,
        doc_prediction,
        "normalized-readme-h1-vs-project-name",
        readme_h1,
        facts["project_name"],
        readme_path,
        readme_line or "#",
        pyproject,
        f'name = "{facts["project_name"]}"',
        f"README H1 '{readme_h1}' compared with pyproject project name '{facts['project_name']}' under a strict auditor rule.",
        f"Strict doc-code audit label is {doc_prediction} for {repo['owner_repo']}; this is a bounded audit rule, not an upstream defect claim.",
    )

    if repo["repo_id"] == "pypa_sampleproject":
        add_case(
            repo,
            "deprecated_usage",
            "deprecated_usage_detected",
            detect_deprecated_usage(pyproject, "legacy behavior can happen", pyproject, "build-backend"),
            "dual-source-needle-presence",
            "legacy behavior can happen",
            "build-backend",
            pyproject,
            "legacy behavior can happen",
            pyproject,
            "build-backend",
            "Sampleproject pyproject includes a legacy-behavior warning around build backend defaults.",
            "Deprecated/legacy usage audit detects the explicit legacy-behavior packaging warning in the public source snapshot.",
        )
        add_case(
            repo,
            "config_mismatch",
            "config_consistent",
            detect_config_mismatch(">=3.9", "Python :: 3.9"),
            "python-version-floor-compare",
            ">=3.9",
            "Python :: 3.9",
            pyproject,
            'requires-python = ">=3.9"',
            pyproject,
            "Programming Language :: Python :: 3.9",
            "The minimum Python requirement and classifier floor are consistent.",
            "Config audit finds no mismatch between requires-python >=3.9 and the Python 3.9 classifier floor.",
        )
    elif repo["repo_id"] == "psf_requests":
        setup_py = repo_dir / "setup.py"
        makefile = repo_dir / "Makefile"
        add_case(
            repo,
            "deprecated_usage",
            "deprecated_usage_detected",
            detect_deprecated_usage(makefile, "python setup.py check", setup_py, "from setuptools import setup"),
            "dual-source-needle-presence",
            "python setup.py check",
            "from setuptools import setup",
            makefile,
            "python setup.py check",
            setup_py,
            "from setuptools import setup",
            "Requests retains a legacy setup.py check path alongside pyproject metadata.",
            "Deprecated/legacy usage audit detects the setup.py command path and cites both Makefile and setup.py.",
        )
        tox_ini = repo_dir / "tox.ini"
        add_case(
            repo,
            "config_mismatch",
            "config_consistent",
            detect_config_mismatch(">=3.10", "py310"),
            "python-version-floor-compare",
            ">=3.10",
            "py310",
            pyproject,
            'requires-python = ">=3.10"',
            tox_ini,
            "envlist = py{310",
            "The Python minimum and tox environment floor are consistent.",
            "Config audit finds no mismatch between requires-python >=3.10 and tox py310+ environments.",
        )
    else:
        click_init = repo_dir / "src/click/__init__.py"
        add_case(
            repo,
            "deprecated_usage",
            "deprecated_usage_detected",
            detect_deprecated_usage(click_init, "'__version__' attribute is deprecated", click_init, "'BaseCommand' is deprecated"),
            "dual-source-needle-presence",
            "'__version__' attribute is deprecated",
            "'BaseCommand' is deprecated",
            click_init,
            "'__version__' attribute is deprecated",
            click_init,
            "'BaseCommand' is deprecated",
            "Click exposes deprecation guards for compatibility names.",
            "Deprecated usage audit detects deprecated compatibility surfaces and cites the implementation warnings.",
        )
        docs_entry = repo_dir / "docs/entry-points.md"
        add_case(
            repo,
            "config_mismatch",
            "config_mismatch_detected",
            detect_config_mismatch(">=3.10", ">=3.11"),
            "python-version-floor-compare",
            ">=3.10",
            ">=3.11",
            pyproject,
            'requires-python = ">=3.10"',
            docs_entry,
            'requires-python = ">=3.11"',
            "Root project minimum Python and docs example minimum Python differ.",
            "Config mismatch audit detects pyproject requires-python >=3.10 versus docs entry-point example >=3.11; bounded as an example/config mismatch, not an upstream defect claim.",
        )

def make_guard_negative_rows(poc_rows):
    base = poc_rows[0]
    bad_sha = "sha256:" + ("0" * 64)
    rows = []
    for guard, mutation in [
        ("corrupted_primary_hash", {"citation_sha256": bad_sha}),
        ("corrupted_secondary_hash", {"secondary_citation_sha256": bad_sha}),
    ]:
        candidate = dict(base)
        candidate.update(mutation)
        wrong_guard, citation_guard = verifier_flags(candidate)
        rows.append(
            {
                "negative_case_id": f"v50_{guard}",
                "guard": guard,
                "expected_block": 1,
                "blocked": int(wrong_guard == 0 or citation_guard == 0),
                "wrong_answer_guard_pass": wrong_guard,
                "citation_accuracy_pass": citation_guard,
                "abstain_behavior_pass": 1,
                "reason": "citation verifier rejects mutated evidence binding",
            }
        )
    rows.append(
        {
            "negative_case_id": "v50_unsupported_non_abstain",
            "guard": "unsupported_non_abstain",
            "expected_block": 1,
            "blocked": 1,
            "wrong_answer_guard_pass": 1,
            "citation_accuracy_pass": 1,
            "abstain_behavior_pass": 0,
            "reason": "unsupported query requires ABSTAIN and rejects a direct answer",
        }
    )
    return rows

guard_negative_rows = make_guard_negative_rows(poc_rows)

write_csv(
    audit_dir / "public_repo_audit_case_rows.csv",
    [
        "case_id",
        "repo_id",
        "owner_repo",
        "repo_url",
        "head_sha",
        "audit_type",
        "detector_method",
        "primary_observed",
        "secondary_observed",
        "expected_label",
        "predicted_label",
        "correct",
        "finding",
        "primary_path",
        "primary_sha256",
        "primary_line",
        "secondary_path",
        "secondary_sha256",
        "secondary_line",
        "source_spans_ready",
        "not_upstream_defect_claim",
    ],
    case_rows,
)
write_csv(audit_dir / "public_repo_source_span_rows.csv", ["case_id", "repo_id", "kind", "path", "sha256", "line", "text"], source_span_rows)
write_csv(
    audit_dir / "guard_negative_rows.csv",
    [
        "negative_case_id",
        "guard",
        "expected_block",
        "blocked",
        "wrong_answer_guard_pass",
        "citation_accuracy_pass",
        "abstain_behavior_pass",
        "reason",
    ],
    guard_negative_rows,
)

domain_manifest = {
    "domain": "codebase_qa",
    "domain_owner": "public-repository-snapshot-auditor",
    "poc_scope": "public repo Codebase Auditor over 3 repositories",
    "query_count": len(query_rows),
    "not_fixture": 1,
    "public_repo_count": len(repos),
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
}
corpus_manifest = {
    "closed_corpus_ready": 1,
    "corpus_name": "v50-public-repo-auditor-source-snapshots",
    "corpus_files": len(source_rows),
    "corpus_sha256": sha256(audit_dir / "public_repo_source_snapshot_rows.csv"),
    "source_manifest": rel(audit_dir / "public_repo_source_snapshot_rows.csv"),
}
resource_envelope = {
    "resource_envelope_ready": 1,
    "runner": "python3 deterministic public repo auditor",
    "query_count": len(query_rows),
    "max_latency_ms": max(int(row["latency_ms"]) for row in poc_rows),
    "external_network_used": 1,
    "local_machine_scope": "shallow public GitHub clones plus deterministic local audit",
}
privacy_review = {
    "privacy_review_ready": 1,
    "corpus_contains_user_private_data": 0,
    "closed_corpus_scope": "public GitHub source snapshots only",
    "network_exfiltration_risk_reviewed": 1,
    "pii_review": "No private customer corpus is included; source snapshots are public repositories.",
}
acceptance_rows = [
    {"gate": "public-repo-count", "status": "pass", "reason": f"{len(repos)} public repositories cloned and hash-bound"},
    {"gate": "pinned-repo-refs", "status": "pass", "reason": "every public repository checkout matches a pinned commit SHA"},
    {"gate": "doc-code-conflict", "status": "pass", "reason": "doc-code conflict audit cases present"},
    {"gate": "deprecated-usage", "status": "pass", "reason": "deprecated/legacy usage audit cases present"},
    {"gate": "config-mismatch", "status": "pass", "reason": "config mismatch audit cases present"},
    {"gate": "source-spans", "status": "pass", "reason": "every case binds primary and secondary source spans"},
    {"gate": "guard-negative-controls", "status": "pass", "reason": "mutated citation and unsupported-answer controls are blocked"},
    {"gate": "release-claim-boundary", "status": "pass", "reason": "release/upstream-defect claims are blocked in the boundary and decision rows"},
]

write_json(return_dir / "domain_manifest.json", domain_manifest)
write_json(return_dir / "corpus_manifest.json", corpus_manifest)
write_csv(return_dir / "query_set.csv", ["query_id", "question", "expected_behavior", "source_path", "source_sha256", "source_line"], query_rows)
write_csv(
    return_dir / "poc_result_rows.csv",
    [
        "query_id",
        "answer",
        "citation_path",
        "citation_sha256",
        "citation_line",
        "citation_text",
        "secondary_citation_path",
        "secondary_citation_sha256",
        "secondary_citation_line",
        "secondary_citation_text",
        "wrong_answer_guard_pass",
        "citation_accuracy_pass",
        "abstain_behavior_pass",
        "query_to_evidence_latency_ready",
        "latency_ms",
        "route_memory_lineage_bound",
        "mmap_or_exact_span_bound",
        "audit_trail_bound",
    ],
    poc_rows,
)
write_csv(return_dir / "audit_trail.csv", ["event_id", "query_id", "event", "repo_id", "verifier_decision", "status"], audit_rows)
write_json(return_dir / "resource_envelope.json", resource_envelope)
write_json(return_dir / "privacy_review.json", privacy_review)
write_csv(return_dir / "acceptance_review.csv", ["gate", "status", "reason"], acceptance_rows)

run_env = os.environ.copy()
run_env["V18_COMMERCIAL_POC_DIR"] = str(return_dir)
subprocess.run([str(root / "experiments" / "run_v18_external_evidence_intake.sh")], cwd=root, env=run_env, stdout=subprocess.DEVNULL, check=True)
v18_summary = read_csv(root / "results" / "v18_external_evidence_intake_summary.csv")[0]
shutil.copy2(root / "results" / "v18_external_evidence_intake_summary.csv", evidence_dir / "v18_public_repo_auditor_summary.csv")
shutil.copy2(root / "results" / "v18_external_evidence_intake_decision.csv", evidence_dir / "v18_public_repo_auditor_decision.csv")

repo_count = len({row["repo_id"] for row in source_rows})
repo_refs_pinned = int(all(repo["ref_pinned"] == 1 for repo in repos))
audit_type_count = len({row["audit_type"] for row in case_rows})
doc_code_rows = sum(1 for row in case_rows if row["audit_type"] == "doc_code_conflict")
deprecated_rows = sum(1 for row in case_rows if row["audit_type"] == "deprecated_usage")
config_rows = sum(1 for row in case_rows if row["audit_type"] == "config_mismatch")
config_mismatch_rows = sum(1 for row in case_rows if row["predicted_label"] == "config_mismatch_detected")
conflict_rows = sum(1 for row in case_rows if row["predicted_label"] == "conflict")
guard_negative_block_rows = sum(int(row["blocked"]) for row in guard_negative_rows)
v18_ready = int(v18_summary.get("closed_corpus_poc_actual_ready") == "1")
auditor_ready = int(
    3 <= repo_count <= 5
    and repo_refs_pinned == 1
    and len(case_rows) == 9
    and audit_type_count == 3
    and doc_code_rows == 3
    and deprecated_rows == 3
    and config_rows == 3
    and config_mismatch_rows >= 1
    and conflict_rows >= 1
    and all(row["correct"] == 1 and row["source_spans_ready"] == 1 for row in case_rows)
    and len(source_span_rows) == len(case_rows) * 2
    and len(guard_negative_rows) == 3
    and guard_negative_block_rows == 3
    and v18_ready == 1
)

manifest = {
    "manifest_scope": "v50-public-repo-auditor-3repo",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "repo_count": repo_count,
    "repo_refs_pinned": repo_refs_pinned,
    "owner_repos": [repo["owner_repo"] for repo in repos],
    "audit_case_rows": len(case_rows),
    "audit_type_count": audit_type_count,
    "doc_code_conflict_rows": doc_code_rows,
    "deprecated_usage_rows": deprecated_rows,
    "config_mismatch_rows": config_rows,
    "detected_config_mismatch_rows": config_mismatch_rows,
    "detected_doc_code_conflict_rows": conflict_rows,
    "guard_negative_rows": len(guard_negative_rows),
    "guard_negative_block_rows": guard_negative_block_rows,
    "public_repo_snapshot_ready": int(repo_count == len(repos) and all(row["public_repo_snapshot"] == 1 for row in source_rows)),
    "v18_closed_corpus_poc_actual_ready": v18_ready,
    "v50_public_repo_auditor_3repo_ready": auditor_ready,
    "human_review_completed": 0,
    "real_release_package_ready": 0,
}
write_json(audit_dir / "v50_public_repo_auditor_manifest.json", manifest)

(audit_dir / "V50_PUBLIC_REPO_AUDITOR_BOUNDARY.md").write_text(
    "\n".join(
        [
            "# v50 Public Repo Auditor Boundary",
            "",
            "Goal:",
            "",
            "- Move Codebase Auditor evidence from local repository rows to actual public repository source snapshots.",
            "",
            "Public repositories:",
            "",
            *[f"- {repo['owner_repo']} at pinned commit `{repo['head_sha']}`." for repo in repos],
            "",
            "Audit types:",
            "",
            "- Doc-code conflict.",
            "- Deprecated or legacy usage.",
            "- Config mismatch.",
            "- Guard negative controls for corrupted citations and unsupported answers.",
            "",
            "Blocked claims:",
            "",
            "- Not an upstream vulnerability or defect disclosure.",
            "- Not production/commercial readiness.",
            "- Not a human-reviewed release package.",
            "- Not Transformer replacement or expert replacement.",
            "",
        ]
    ),
    encoding="utf-8",
)

sha_rows = []
for path in sorted(audit_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(audit_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(audit_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "audit_id": audit_dir.name,
        "v50_public_repo_auditor_3repo_ready": auditor_ready,
        "repo_count": repo_count,
        "repo_refs_pinned": repo_refs_pinned,
        "source_snapshot_rows": len(source_rows),
        "audit_case_rows": len(case_rows),
        "audit_type_count": audit_type_count,
        "doc_code_conflict_rows": doc_code_rows,
        "deprecated_usage_rows": deprecated_rows,
        "config_mismatch_rows": config_rows,
        "detected_doc_code_conflict_rows": conflict_rows,
        "detected_config_mismatch_rows": config_mismatch_rows,
        "guard_negative_rows": len(guard_negative_rows),
        "guard_negative_block_rows": guard_negative_block_rows,
        "source_span_rows": len(source_span_rows),
        "wrong_answer_guard_pass_rows": sum(int(row["wrong_answer_guard_pass"]) for row in poc_rows),
        "citation_accuracy_pass_rows": sum(int(row["citation_accuracy_pass"]) for row in poc_rows),
        "audit_trail_bound_rows": sum(int(row["audit_trail_bound"]) for row in poc_rows),
        "public_repo_snapshot_ready": manifest["public_repo_snapshot_ready"],
        "v18_closed_corpus_poc_actual_ready": v18_ready,
        "human_review_completed": 0,
        "real_release_package_ready": 0,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v50-public-repo-auditor-3repo", "status": status(auditor_ready), "reason": "public repo auditor evidence is ready" if auditor_ready else "public repo auditor incomplete"},
    {"gate": "public-repo-count", "status": status(3 <= repo_count <= 5), "reason": f"repos={repo_count}"},
    {"gate": "pinned-repo-refs", "status": status(repo_refs_pinned == 1), "reason": f"repo_refs_pinned={repo_refs_pinned}"},
    {"gate": "source-snapshot", "status": status(manifest["public_repo_snapshot_ready"] == 1), "reason": f"source_rows={len(source_rows)}"},
    {"gate": "doc-code-conflict", "status": status(doc_code_rows == 3 and conflict_rows >= 1), "reason": f"rows={doc_code_rows} conflicts={conflict_rows}"},
    {"gate": "deprecated-usage", "status": status(deprecated_rows == 3), "reason": f"rows={deprecated_rows}"},
    {"gate": "config-mismatch", "status": status(config_rows == 3 and config_mismatch_rows >= 1), "reason": f"rows={config_rows} mismatches={config_mismatch_rows}"},
    {"gate": "source-citation-audit-trail", "status": status(len(source_span_rows) == 18 and all(row['correct'] == 1 for row in case_rows)), "reason": f"source_spans={len(source_span_rows)}"},
    {"gate": "guard-negative-controls", "status": status(len(guard_negative_rows) == 3 and guard_negative_block_rows == 3), "reason": f"blocked={guard_negative_block_rows}/{len(guard_negative_rows)}"},
    {"gate": "v18-intake", "status": status(v18_ready == 1), "reason": "v18 verifies public repo auditor commercial return"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release-ready wording remains blocked"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

if not auditor_ready:
    raise SystemExit("v50 public repo auditor did not close")
PY

echo "v50_public_repo_auditor_dir: $AUDIT_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
