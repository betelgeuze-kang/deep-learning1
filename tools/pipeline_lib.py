#!/usr/bin/env python3
"""Shared helpers for migrating shell workflow stages to Python adapters."""

from __future__ import annotations

import csv
import hashlib
import json
import shutil
import tempfile
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Iterator

EVIDENCE_FAMILIES = frozenset({"fixture", "synthetic", "real_benchmark"})


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def canonical_json_sha256(payload: object) -> str:
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return sha256_text(encoded)


def content_addressed_cache_key(
    *,
    source_sha256: dict[str, str],
    input_sha256: dict[str, str],
    environment: dict[str, object],
    config: dict[str, object],
) -> str:
    """Build a stable cache key from source, input, environment, and config state."""
    for label, values in [
        ("source_sha256", source_sha256),
        ("input_sha256", input_sha256),
        ("environment", environment),
        ("config", config),
    ]:
        if not isinstance(values, dict):
            raise TypeError(f"{label} must be a dict for content-addressed cache keys")
        if not values:
            raise ValueError(f"{label} must be non-empty for content-addressed cache keys")
    payload = {
        "schema_version": "pipeline_cache_key.v1",
        "source_sha256": source_sha256,
        "input_sha256": input_sha256,
        "environment": environment,
        "config": config,
    }
    return canonical_json_sha256(payload)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, fieldnames: Iterable[str], rows: Iterable[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(fieldnames), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_summary_csv(run_dir: Path, summary: dict[str, object]) -> Path:
    """Write the canonical per-run summary artifact."""
    summary_path = run_dir / "summary.csv"
    write_csv(summary_path, summary.keys(), [summary])
    return summary_path


def run_packet_dir(results_root: Path, stage_id: str, run_id: str) -> Path:
    if not stage_id or stage_id == ".." or "/" in stage_id or "\\" in stage_id:
        raise ValueError("stage_id must be a non-empty path segment")
    if not run_id or run_id == ".." or "/" in run_id or "\\" in run_id:
        raise ValueError("run_id must be a non-empty path segment")
    return results_root / stage_id / run_id


def evidence_packet_dir(results_root: Path, evidence_family: str, stage_id: str, run_id: str) -> Path:
    if evidence_family not in EVIDENCE_FAMILIES:
        raise ValueError(f"evidence_family must be one of {', '.join(sorted(EVIDENCE_FAMILIES))}")
    return run_packet_dir(results_root / evidence_family, stage_id, run_id)


def metric_namespace(evidence_family: str, metric_name: str) -> str:
    if evidence_family not in EVIDENCE_FAMILIES:
        raise ValueError(f"evidence_family must be one of {', '.join(sorted(EVIDENCE_FAMILIES))}")
    if not metric_name or metric_name == ".." or "/" in metric_name or "\\" in metric_name:
        raise ValueError("metric_name must be a non-empty namespace segment")
    prefix = f"{evidence_family}."
    if metric_name.startswith(prefix):
        return metric_name
    if "." in metric_name:
        raise ValueError("metric_name must not carry a different evidence-family prefix")
    return prefix + metric_name


@contextmanager
def atomic_run_dir(final_dir: Path) -> Iterator[Path]:
    """Publish a new run directory atomically after all artifacts are written."""
    final_dir = final_dir.resolve()
    final_dir.parent.mkdir(parents=True, exist_ok=True)
    if final_dir.exists():
        raise FileExistsError(f"run directory already exists: {final_dir}")
    tmp_dir = Path(tempfile.mkdtemp(prefix=f".{final_dir.name}.tmp-", dir=final_dir.parent))
    try:
        yield tmp_dir
        summary_path = tmp_dir / "summary.csv"
        if not summary_path.is_file() or summary_path.stat().st_size == 0:
            _raise_missing_summary(tmp_dir)
        tmp_dir.replace(final_dir)
    except Exception:
        if tmp_dir.exists():
            shutil.rmtree(tmp_dir)
        raise


def _raise_missing_summary(tmp_dir: Path) -> None:
    raise FileNotFoundError(f"atomic run directory missing non-empty summary.csv: {tmp_dir}")


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

    def write_run_summary(self) -> Path:
        return write_summary_csv(self.run_dir, self.summary)

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
