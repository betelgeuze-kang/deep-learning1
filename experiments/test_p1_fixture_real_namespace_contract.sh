#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/p1-fixture-real-namespace.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cd "$ROOT_DIR"

python3 - "$TMP_DIR" <<'PY'
import sys
from pathlib import Path

from tools.pipeline_lib import EVIDENCE_FAMILIES, evidence_packet_dir, metric_namespace

root = Path(sys.argv[1])

expected_families = {"fixture", "synthetic", "real_benchmark"}
if EVIDENCE_FAMILIES != expected_families:
    raise SystemExit(f"unexpected evidence families: {EVIDENCE_FAMILIES}")
try:
    EVIDENCE_FAMILIES.add("real")
except AttributeError:
    pass
else:
    raise SystemExit("EVIDENCE_FAMILIES must be immutable")

paths = {
    family: evidence_packet_dir(root, family, "stage_a", "run_001")
    for family in sorted(EVIDENCE_FAMILIES)
}
if len(set(paths.values())) != len(paths):
    raise SystemExit("fixture/synthetic/real benchmark evidence directories must be distinct")
for family, path in paths.items():
    if path.parts[-3:] != (family, "stage_a", "run_001"):
        raise SystemExit(f"unexpected evidence path for {family}: {path}")

metric_names = {
    family: metric_namespace(family, "qacc")
    for family in sorted(EVIDENCE_FAMILIES)
}
if metric_names != {
    "fixture": "fixture.qacc",
    "synthetic": "synthetic.qacc",
    "real_benchmark": "real_benchmark.qacc",
}:
    raise SystemExit(f"unexpected metric namespaces: {metric_names}")
if len(set(metric_names.values())) != len(metric_names):
    raise SystemExit("fixture/synthetic/real metric namespaces must be distinct")

if metric_namespace("fixture", "fixture.qacc") != "fixture.qacc":
    raise SystemExit("metric_namespace should preserve matching prefixes")

negative_cases = [
    ("empty-family", lambda: evidence_packet_dir(root, "", "stage_a", "run_001")),
    ("bad-family", lambda: evidence_packet_dir(root, "real", "stage_a", "run_001")),
    ("bad-stage", lambda: evidence_packet_dir(root, "fixture", "bad/stage", "run_001")),
    ("traversal-stage", lambda: evidence_packet_dir(root, "fixture", "..", "run_001")),
    ("bad-run", lambda: evidence_packet_dir(root, "fixture", "stage_a", "bad/run")),
    ("traversal-run", lambda: evidence_packet_dir(root, "fixture", "stage_a", "..")),
    ("bad-metric-family", lambda: metric_namespace("real", "qacc")),
    ("empty-metric", lambda: metric_namespace("fixture", "")),
    ("bad-metric-prefix", lambda: metric_namespace("fixture", "real_benchmark.qacc")),
    ("bad-metric-segment", lambda: metric_namespace("fixture", "bad/qacc")),
    ("traversal-metric", lambda: metric_namespace("fixture", "..")),
]
for name, thunk in negative_cases:
    try:
        thunk()
    except ValueError:
        pass
    else:
        raise SystemExit(f"negative case unexpectedly passed: {name}")

print("p1 fixture/real namespace contract passed")
PY
