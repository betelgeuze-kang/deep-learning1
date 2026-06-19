#!/usr/bin/env python3
"""Build a deterministic sha256 manifest for small artifact directories."""

from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("-o", "--output", type=Path, default=None)
    parser.add_argument("--exclude", action="append", default=["sha256_manifest.csv"])
    args = parser.parse_args()

    root = args.root
    output = args.output or root / "sha256_manifest.csv"
    excluded = set(args.exclude)
    rows = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        if rel in excluded or path == output:
            continue
        rows.append({"path": rel, "sha256": sha256(path), "bytes": str(path.stat().st_size)})
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["path", "sha256", "bytes"], lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
