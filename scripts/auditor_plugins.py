from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SourceFile:
    source_id: str
    path: Path
    rel_path: str
    sha256: str
    text: str


@dataclass(frozen=True)
class Finding:
    audit_type: str
    question: str
    answer: str
    evidence_paths: tuple[Path, ...]
    evidence_terms: tuple[str, ...] = tuple()
    severity: str = "info"
    grounded: int = 1
    abstain: int = 0
    unsupported_claim: int = 0
    plugin_id: str = ""
    language: str = "generic"


class AuditPlugin:
    plugin_id = "base"
    audit_type = "base"
    language = "generic"

    def run(self, repo: Path, sources: list[SourceFile]) -> list[Finding]:
        raise NotImplementedError


def _first_existing(repo: Path, names: list[str]) -> Path | None:
    for name in names:
        path = repo / name
        if path.is_file():
            return path
    return None


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def _first_file_under(path: Path) -> Path | None:
    if path.is_file():
        return path
    if not path.is_dir():
        return None
    for candidate in sorted(path.rglob("*")):
        if candidate.is_file():
            return candidate
    return None


from auditor_plugin_config_consistency import ConfigConsistencyPlugin
from auditor_plugin_deprecated_api import DeprecatedApiPlugin
from auditor_plugin_doc_code_identity import DocCodeIdentityPlugin
from auditor_plugin_missing_evidence import MissingEvidencePlugin
from auditor_plugin_unsupported_claim import UnsupportedClaimPlugin


DEFAULT_PLUGINS: tuple[AuditPlugin, ...] = (
    DocCodeIdentityPlugin(),
    DeprecatedApiPlugin(),
    ConfigConsistencyPlugin(),
    UnsupportedClaimPlugin(),
    MissingEvidencePlugin(),
)
