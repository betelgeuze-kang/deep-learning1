#!/usr/bin/env python3
"""Run or dry-run JSON-compatible YAML pipeline adapters."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


def load_pipeline(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pipeline", type=Path)
    parser.add_argument("--stage", action="append", default=[])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    data = load_pipeline(args.pipeline)
    selected = set(args.stage)
    stages = [stage for stage in data["stages"] if not selected or stage["stage_id"] in selected]
    missing = selected - {stage["stage_id"] for stage in stages}
    if missing:
        raise SystemExit(f"unknown stage(s): {', '.join(sorted(missing))}")
    for stage in stages:
        command = stage["command"]
        for requirement in stage.get("requires", []):
            print(f"[requires] {stage['stage_id']} <- {requirement}")
        for override in stage.get("runtime_overrides", []):
            print(f"[runtime_override_declared] {stage['stage_id']} allows {override}")
        print(f"[{data['pipeline_id']}:{stage['stage_id']}] {' '.join(command)}")
        if args.dry_run:
            continue
        subprocess.run(command, check=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
