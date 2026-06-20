#!/usr/bin/env python3
"""Shared helpers for migrating shell workflow stages to Python adapters."""

from __future__ import annotations

import csv
import hashlib
import json
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, fieldnames: Iterable[str], rows: Iterable[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(fieldnames), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy_into(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def rebuild_manifest(root: Path, manifest_name: str = "sha256_manifest.csv") -> Path:
    manifest_path = root / manifest_name
    rows = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path == manifest_path:
            continue
        rel = path.relative_to(root).as_posix()
        rows.append({"path": rel, "sha256": sha256_file(path), "bytes": str(path.stat().st_size)})
    write_csv(manifest_path, ["path", "sha256", "bytes"], rows)
    return manifest_path


@dataclass
class PipelineRun:
    stage_id: str
    run_dir: Path
    summary: dict[str, object] = field(default_factory=dict)
    decisions: list[dict[str, object]] = field(default_factory=list)
    boundary_lines: list[str] = field(default_factory=list)

    def add_decision(self, gate: str, status: str, reason: str) -> None:
        self.decisions.append({"gate": gate, "status": status, "reason": reason})

    def write_summary(self, path: Path) -> None:
        write_csv(path, self.summary.keys(), [self.summary])

    def write_decisions(self, path: Path) -> None:
        write_csv(path, ["gate", "status", "reason"], self.decisions)

    def write_boundary(self, path: Path, title: str, allowed: str, blocked: str) -> None:
        body = [f"# {title}", ""]
        body.extend(self.boundary_lines)
        body.extend(["", f"Allowed wording: {allowed}", "", f"Blocked wording: {blocked}", ""])
        path.write_text("\n".join(body), encoding="utf-8")

    def write_manifest_json(self, path: Path, extra: dict[str, object] | None = None) -> None:
        payload = {"stage_id": self.stage_id, **self.summary}
        if extra:
            payload.update(extra)
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
