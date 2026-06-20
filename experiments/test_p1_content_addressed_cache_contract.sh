#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from tools.pipeline_lib import canonical_json_sha256, content_addressed_cache_key

base = {
    "source_sha256": {
        "tools/pipeline_lib.py": "sha256:" + "a" * 64,
        "experiments/input.csv": "sha256:" + "b" * 64,
    },
    "input_sha256": {
        "query_rows": "sha256:" + "c" * 64,
    },
    "environment": {
        "python": "3.x",
        "compiler": "g++",
        "rocm": "disabled",
    },
    "config": {
        "stage_id": "stage_a",
        "run_mode": "smoke",
        "seed": 1,
    },
}

key_a = content_addressed_cache_key(**base)
key_b = content_addressed_cache_key(
    source_sha256=dict(reversed(list(base["source_sha256"].items()))),
    input_sha256=dict(base["input_sha256"]),
    environment=dict(reversed(list(base["environment"].items()))),
    config=dict(reversed(list(base["config"].items()))),
)
if key_a != key_b:
    raise SystemExit("content-addressed cache key must be canonical and order-stable")
if not key_a.startswith("sha256:") or len(key_a) != len("sha256:") + 64:
    raise SystemExit("content-addressed cache key must be a sha256 digest")

for axis, field, value in [
    ("source_sha256", "tools/pipeline_lib.py", "sha256:" + "d" * 64),
    ("input_sha256", "query_rows", "sha256:" + "e" * 64),
    ("environment", "python", "3.y"),
    ("config", "seed", 2),
]:
    mutated = {
        "source_sha256": dict(base["source_sha256"]),
        "input_sha256": dict(base["input_sha256"]),
        "environment": dict(base["environment"]),
        "config": dict(base["config"]),
    }
    mutated[axis][field] = value
    if content_addressed_cache_key(**mutated) == key_a:
        raise SystemExit(f"content-addressed cache key must change when {axis}.{field} changes")

for axis in ["source_sha256", "input_sha256", "environment", "config"]:
    mutated = {
        "source_sha256": dict(base["source_sha256"]),
        "input_sha256": dict(base["input_sha256"]),
        "environment": dict(base["environment"]),
        "config": dict(base["config"]),
    }
    mutated[axis] = {}
    try:
        content_addressed_cache_key(**mutated)
    except ValueError as exc:
        if axis not in str(exc):
            raise SystemExit(f"empty {axis} failed with wrong diagnostic: {exc}")
    else:
        raise SystemExit(f"content-addressed cache key must reject empty {axis}")

try:
    content_addressed_cache_key(
        source_sha256=[("not", "a-dict")],
        input_sha256=dict(base["input_sha256"]),
        environment=dict(base["environment"]),
        config=dict(base["config"]),
    )
except TypeError as exc:
    if "source_sha256" not in str(exc):
        raise SystemExit(f"non-dict source failed with wrong diagnostic: {exc}")
else:
    raise SystemExit("content-addressed cache key must reject non-dict source_sha256")

if canonical_json_sha256({"b": 2, "a": 1}) != canonical_json_sha256({"a": 1, "b": 2}):
    raise SystemExit("canonical_json_sha256 must be key-order stable")
if canonical_json_sha256({"outer": {"b": [2, 1], "a": {"z": 0}}}) != canonical_json_sha256({"outer": {"a": {"z": 0}, "b": [2, 1]}}):
    raise SystemExit("canonical_json_sha256 must be nested key-order stable")

print("p1 content-addressed cache contract passed")
PY
