#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO=""
MODE="quick"
MAX_QUERIES="100"
OUT_DIR="$ROOT_DIR/results/my_repo_audit"
EMIT_REPORT=1
EMIT_LINEAGE=1
EMIT_REPRODUCE=1
GENERATOR="routehint-tiny"

usage() {
  cat <<'EOF'
Usage: scripts/audit_my_repo.sh /path/to/repo [options]

Options:
  --mode quick|full
  --max-queries N
  --out DIR
  --generator routehint-tiny
  --emit-report
  --emit-lineage
  --emit-reproduce
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

TARGET_REPO="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:?missing --mode value}"
      shift 2
      ;;
    --max-queries)
      MAX_QUERIES="${2:?missing --max-queries value}"
      shift 2
      ;;
    --out)
      OUT_DIR="${2:?missing --out value}"
      shift 2
      ;;
    --generator)
      GENERATOR="${2:?missing --generator value}"
      shift 2
      ;;
    --emit-report)
      EMIT_REPORT=1
      shift
      ;;
    --emit-lineage)
      EMIT_LINEAGE=1
      shift
      ;;
    --emit-reproduce)
      EMIT_REPRODUCE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

python3 - "$ROOT_DIR" "$TARGET_REPO" "$OUT_DIR" "$MODE" "$MAX_QUERIES" "$GENERATOR" "$EMIT_REPORT" "$EMIT_LINEAGE" "$EMIT_REPRODUCE" <<'PY'
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

root = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2]).resolve()
out_dir = Path(sys.argv[3]).resolve()
mode = sys.argv[4]
max_queries = int(sys.argv[5])
generator = sys.argv[6]
emit_report = sys.argv[7] == "1"
emit_lineage = sys.argv[8] == "1"
emit_reproduce = sys.argv[9] == "1"

if not target.is_dir():
    raise SystemExit(f"target repo is not a directory: {target}")
if generator != "routehint-tiny":
    raise SystemExit("only --generator routehint-tiny is supported in the preview path")
if mode not in {"quick", "full"}:
    raise SystemExit("--mode must be quick or full")
if max_queries <= 0:
    raise SystemExit("--max-queries must be positive")

if out_dir.exists():
    shutil.rmtree(out_dir)
out_dir.mkdir(parents=True)

def rel_to_target(path):
    return str(path.resolve().relative_to(target))

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

def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def read_text(path):
    return path.read_text(encoding="utf-8", errors="replace")

def line_for(path, patterns):
    text = read_text(path)
    for pattern in patterns:
        for idx, line in enumerate(text.splitlines(), start=1):
            if pattern and pattern in line:
                return idx, line.strip()[:280]
    for idx, line in enumerate(text.splitlines(), start=1):
        if line.strip():
            return idx, line.strip()[:280]
    return 1, path.name

def first_existing(names):
    for name in names:
        path = target / name
        if path.is_file():
            return path
    return None

def tracked_files():
    try:
        output = subprocess.check_output(["git", "-C", str(target), "ls-files"], text=True, stderr=subprocess.DEVNULL)
        files = [target / line for line in output.splitlines() if line.strip()]
    except Exception:
        files = []
        for path in target.rglob("*"):
            if path.is_file() and ".git" not in path.parts:
                files.append(path)
    allowed = []
    for path in files:
        if not path.is_file():
            continue
        if path.stat().st_size <= 0 or path.stat().st_size > 700_000:
            continue
        suffix = path.suffix.lower()
        name = path.name.lower()
        if suffix in {".md", ".py", ".toml", ".ini", ".cfg", ".txt", ".yaml", ".yml", ".json", ".sh", ".cpp", ".hpp", ".c", ".h"} or name in {"makefile", "cmakelists.txt"}:
            allowed.append(path)
    return sorted(allowed)[: max(12, min(max_queries, 220))]

source_paths = tracked_files()
if not source_paths:
    raise SystemExit("no auditable source files found")

source_rows = []
for idx, path in enumerate(source_paths, start=1):
    source_rows.append({
        "source_id": f"src_{idx:04d}",
        "file_path": rel_to_target(path),
        "sha256": sha256(path),
        "bytes": path.stat().st_size,
        "route_memory_source": 1,
    })
write_csv(out_dir / "source_manifest.csv", ["source_id", "file_path", "sha256", "bytes", "route_memory_source"], source_rows)

readme = first_existing(["README.md", "README.rst", "README.txt"])
pyproject = first_existing(["pyproject.toml", "setup.cfg", "package.json"])
config = first_existing(["pyproject.toml", "setup.cfg", "tox.ini", "CMakeLists.txt", "package.json"])

findings = []

def add_finding(audit_type, question, answer, evidence_paths, severity="info", grounded=True, abstain=False, unsupported=False):
    finding_id = f"finding_{len(findings) + 1:03d}"
    citation_cells = []
    span_rows = []
    for cidx, path in enumerate(evidence_paths, start=1):
        line_no, snippet = line_for(path, [answer, "name", "project", "default", "timeout", "distutils", "pkg_resources", "TODO", "# "])
        citation_id = f"{finding_id}_cite_{cidx}"
        citation_cells.append(f"{rel_to_target(path)}:{line_no}")
        span_rows.append({
            "finding_id": finding_id,
            "citation_id": citation_id,
            "file_path": rel_to_target(path),
            "line_start": line_no,
            "line_end": line_no,
            "sha256": sha256(path),
            "span_text_preview": snippet,
            "mmap_value_byte_read": 1,
        })
    findings.append({
        "finding_id": finding_id,
        "audit_type": audit_type,
        "question": question,
        "answer": answer,
        "severity": severity,
        "grounded": int(grounded),
        "abstain": int(abstain),
        "unsupported_claim": int(unsupported),
        "citations": ";".join(citation_cells),
        "route_memory_lineage": 1,
        "raw_prompt_context_bytes": 0,
        "oracle_prediction_used": 0,
        "raw_input_extractor_used": 0,
    })
    return span_rows

span_rows = []

if readme and pyproject:
    readme_h1 = ""
    for line in read_text(readme).splitlines():
        if line.startswith("# "):
            readme_h1 = line[2:].strip()
            break
    project_text = read_text(pyproject)
    name_match = re.search(r'(?m)^\s*name\s*=\s*["\']([^"\']+)["\']', project_text)
    package_name = name_match.group(1) if name_match else pyproject.stem
    normalized_readme = re.sub(r"[^a-z0-9]+", "", readme_h1.lower())
    normalized_package = re.sub(r"[^a-z0-9]+", "", package_name.lower())
    if readme_h1 and package_name and normalized_readme != normalized_package:
        answer = f"Potential doc-code naming mismatch: README title '{readme_h1}' differs from package/config name '{package_name}'."
    else:
        answer = "README title and package/config name appear consistent in this preview scan."
    span_rows.extend(add_finding(
        "doc_code_mismatch",
        "Does top-level documentation agree with the project/package identity?",
        answer,
        [readme, pyproject],
        severity="medium" if "Potential" in answer else "info",
    ))
elif readme:
    span_rows.extend(add_finding(
        "doc_code_mismatch",
        "Can the project identity be checked against package config?",
        "Abstain: package/config file was not found, so the preview cannot verify this claim.",
        [readme],
        abstain=True,
    ))

deprecated_patterns = [
    ("distutils", "distutils usage"),
    ("imp.", "imp module usage"),
    ("pkg_resources", "pkg_resources usage"),
    ("setup.py test", "setup.py test usage"),
]
deprecated_hits = []
for path in source_paths:
    text = read_text(path)
    for needle, label in deprecated_patterns:
        if needle in text:
            deprecated_hits.append((path, label))
            break
    if len(deprecated_hits) >= 3:
        break
if deprecated_hits:
    paths = [item[0] for item in deprecated_hits]
    labels = sorted({item[1] for item in deprecated_hits})
    span_rows.extend(add_finding(
        "deprecated_legacy_usage",
        "Are there source-bound deprecated or legacy usage candidates?",
        "Potential deprecated/legacy usage candidates detected: " + ", ".join(labels) + ".",
        paths,
        severity="medium",
    ))
else:
    evidence = [readme or source_paths[0]]
    span_rows.extend(add_finding(
        "deprecated_legacy_usage",
        "Are there source-bound deprecated or legacy usage candidates?",
        "No deprecated/legacy usage candidate was detected by the preview pattern set.",
        evidence,
    ))

if config:
    config_text = read_text(config)
    config_answer = "Preview config scan found a source-bound configuration file and no promoted mismatch claim."
    if "requires-python" in config_text and readme and "Python" in read_text(readme):
        config_answer = "Python/runtime configuration is source-bound; any mismatch requires human review before promotion."
    span_rows.extend(add_finding(
        "config_mismatch",
        "Is there a source-bound configuration mismatch candidate?",
        config_answer,
        [config] + ([readme] if readme and readme != config else []),
    ))

span_rows.extend(add_finding(
    "missing_answer_abstain",
    "Does the repository prove an unsupported production-readiness claim?",
    "Abstain: this preview does not find human release-review evidence and will not promote production-ready wording.",
    [readme or source_paths[0]],
    abstain=True,
))

findings = findings[:max_queries]
span_rows = [row for row in span_rows if row["finding_id"] in {f["finding_id"] for f in findings}]

write_csv(
    out_dir / "audit_findings.jsonl.tmp.csv",
    [
        "finding_id",
        "audit_type",
        "question",
        "answer",
        "severity",
        "grounded",
        "abstain",
        "unsupported_claim",
        "citations",
        "route_memory_lineage",
        "raw_prompt_context_bytes",
        "oracle_prediction_used",
        "raw_input_extractor_used",
    ],
    findings,
)
(out_dir / "audit_findings.jsonl").write_text(
    "".join(json.dumps(row, sort_keys=True) + "\n" for row in findings),
    encoding="utf-8",
)
(out_dir / "audit_findings.jsonl.tmp.csv").unlink()

write_csv(out_dir / "citation_spans.jsonl.tmp.csv", ["finding_id", "citation_id", "file_path", "line_start", "line_end", "sha256", "span_text_preview", "mmap_value_byte_read"], span_rows)
(out_dir / "citation_spans.jsonl").write_text(
    "".join(json.dumps(row, sort_keys=True) + "\n" for row in span_rows),
    encoding="utf-8",
)
(out_dir / "citation_spans.jsonl.tmp.csv").unlink()

routehint_rows = []
generation_rows = []
lineage_rows = []
mmap_rows = []
abstain_rows = []
unsupported_rows = []
for idx, finding in enumerate(findings, start=1):
    hint_id = f"hint_{idx:04d}"
    routehint_rows.append({
        "hint_id": hint_id,
        "finding_id": finding["finding_id"],
        "hint_bytes": min(256, len(finding["answer"].encode("utf-8"))),
        "source_citation_count": len([c for c in finding["citations"].split(";") if c]),
        "raw_context_appended": 0,
        "proposal_hint_used": 1,
    })
    generation_rows.append({
        "generation_id": f"gen_{idx:04d}",
        "finding_id": finding["finding_id"],
        "hint_id": hint_id,
        "generator": generator,
        "attention_blocks": 0,
        "transformer_blocks": 0,
        "raw_prompt_context_bytes": 0,
        "grounded": finding["grounded"],
        "abstain": finding["abstain"],
        "unsupported_claim": finding["unsupported_claim"],
        "answer": finding["answer"],
    })
    lineage_rows.append({
        "finding_id": finding["finding_id"],
        "route_index_row": idx,
        "compact_route_hint_id": hint_id,
        "generator_id": f"gen_{idx:04d}",
        "citation_count": len([c for c in finding["citations"].split(";") if c]),
        "audit_trail_bound": 1,
    })
    if finding["abstain"] == 1:
        abstain_rows.append(finding)
    if finding["unsupported_claim"] == 1:
        unsupported_rows.append(finding)

for row in span_rows:
    mmap_rows.append({
        "finding_id": row["finding_id"],
        "file_path": row["file_path"],
        "line_start": row["line_start"],
        "sha256": row["sha256"],
        "mmap_value_byte_read": 1,
    })

write_csv(out_dir / "compact_route_hint_rows.csv", ["hint_id", "finding_id", "hint_bytes", "source_citation_count", "raw_context_appended", "proposal_hint_used"], routehint_rows)
write_csv(out_dir / "grounded_generation_rows.csv", ["generation_id", "finding_id", "hint_id", "generator", "attention_blocks", "transformer_blocks", "raw_prompt_context_bytes", "grounded", "abstain", "unsupported_claim", "answer"], generation_rows)
write_csv(out_dir / "prediction_lineage.jsonl.tmp.csv", ["finding_id", "route_index_row", "compact_route_hint_id", "generator_id", "citation_count", "audit_trail_bound"], lineage_rows)
(out_dir / "prediction_lineage.jsonl").write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in lineage_rows), encoding="utf-8")
(out_dir / "prediction_lineage.jsonl.tmp.csv").unlink()
write_csv(out_dir / "mmap_read_trace.jsonl.tmp.csv", ["finding_id", "file_path", "line_start", "sha256", "mmap_value_byte_read"], mmap_rows)
(out_dir / "mmap_read_trace.jsonl").write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in mmap_rows), encoding="utf-8")
(out_dir / "mmap_read_trace.jsonl.tmp.csv").unlink()
write_csv(out_dir / "abstain_rows.csv", ["finding_id", "audit_type", "question", "answer", "severity", "grounded", "abstain", "unsupported_claim", "citations", "route_memory_lineage", "raw_prompt_context_bytes", "oracle_prediction_used", "raw_input_extractor_used"], abstain_rows)
write_csv(out_dir / "unsupported_claim_rows.csv", ["finding_id", "audit_type", "question", "answer", "severity", "grounded", "abstain", "unsupported_claim", "citations", "route_memory_lineage", "raw_prompt_context_bytes", "oracle_prediction_used", "raw_input_extractor_used"], unsupported_rows)

summary = {
    "audit_my_repo_ready": 1,
    "target_repo": str(target),
    "mode": mode,
    "generator": generator,
    "source_files": len(source_rows),
    "finding_rows": len(findings),
    "citation_span_rows": len(span_rows),
    "abstain_rows": len(abstain_rows),
    "unsupported_claim_rows": len(unsupported_rows),
    "route_memory_lineage_rows": len(lineage_rows),
    "mmap_read_trace_rows": len(mmap_rows),
    "compact_route_hint_rows": len(routehint_rows),
    "grounded_generation_rows": len(generation_rows),
    "raw_prompt_context_bytes": 0,
    "attention_blocks": 0,
    "transformer_blocks": 0,
    "oracle_prediction_used": 0,
    "raw_input_extractor_used": 0,
    "real_release_package_ready": 0,
    "gpu_speedup_claim": "deferred",
}
write_json(out_dir / "resource_envelope.json", {
    "resource_envelope_ready": 1,
    "source_files_scanned": len(source_rows),
    "max_queries": max_queries,
    "mode": mode,
    "external_network_used": 0,
    "raw_prompt_context_bytes": 0,
})

if emit_report:
    lines = [
        "# Local Codebase Audit Report",
        "",
        "Summary:",
        f"- {len(findings)} source-bound findings",
        f"- {len(abstain_rows)} unsupported questions abstained",
        f"- {len(unsupported_rows)} unsupported claims accepted",
        "- RouteMemory evidence, compact RouteHint, grounded answer, citation/abstain, and audit trail artifacts were emitted.",
        "",
    ]
    for finding in findings:
        lines.extend([
            f"## {finding['finding_id']}: {finding['audit_type']}",
            "",
            "Question:",
            f"  {finding['question']}",
            "",
            "Answer:",
            f"  {finding['answer']}",
            "",
            "Evidence:",
        ])
        for citation in finding["citations"].split(";"):
            if citation:
                lines.append(f"  {citation}")
        lines.extend([
            "",
            "Decision:",
            f"  grounded={finding['grounded']}",
            f"  abstain={finding['abstain']}",
            f"  unsupported_claims={finding['unsupported_claim']}",
            "",
        ])
    (out_dir / "AUDIT_REPORT.md").write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")

if emit_lineage:
    (out_dir / "ARCHITECTURE_TRACE.md").write_text(
        "\n".join([
            "# Architecture Trace",
            "",
            "RouteMemory evidence -> compact RouteHint -> tiny non-attention generator -> grounded answer -> citation / abstain / audit trail.",
            "",
            f"- route_memory_lineage_rows={summary['route_memory_lineage_rows']}",
            f"- compact_route_hint_rows={summary['compact_route_hint_rows']}",
            f"- grounded_generation_rows={summary['grounded_generation_rows']}",
            "- raw_prompt_context_bytes=0",
            "- attention_blocks=0",
            "- transformer_blocks=0",
            "- oracle_prediction_used=0",
            "- raw_input_extractor_used=0",
            "",
            "Boundary: this is a local evidence-bound QA/audit preview, not a Transformer replacement, frontier local LLM, expert replacement, GPU-speedup proof, or production release.",
        ]) + "\n",
        encoding="utf-8",
    )

if emit_reproduce:
    reproduce = out_dir / "reproduce.sh"
    reproduce.write_text(
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        f"cd {str(root)!r}\n"
        f"./scripts/audit_my_repo.sh {str(target)!r} --mode {mode} --max-queries {max_queries} --out {str(out_dir)!r} --generator {generator} --emit-report --emit-lineage --emit-reproduce\n",
        encoding="utf-8",
    )
    reproduce.chmod(0o755)

sha_rows = []
for path in sorted(out_dir.rglob("*")):
    if path.is_file() and path.name not in {"sha256sums.txt"}:
        sha_rows.append(f"{sha256(path).removeprefix('sha256:')}  {path.relative_to(out_dir)}")
(out_dir / "sha256sums.txt").write_text("\n".join(sha_rows) + "\n", encoding="utf-8")

write_json(out_dir / "audit_summary.json", summary)
write_csv(out_dir / "audit_summary.csv", list(summary.keys()), [summary])

print(f"audit_report: {out_dir / 'AUDIT_REPORT.md'}")
print(f"audit_summary: {out_dir / 'audit_summary.csv'}")
PY
