from __future__ import annotations

from pathlib import Path

from auditor_plugins import AuditPlugin, Finding, SourceFile, _first_existing, _first_file_under


class MissingEvidencePlugin(AuditPlugin):
    plugin_id = "missing_evidence"
    audit_type = "missing_evidence"

    def run(self, repo: Path, sources: list[SourceFile]) -> list[Finding]:
        evidence_dirs = [repo / "evidence", repo / "results", repo / "docs"]
        has_evidence_surface = any(path.exists() for path in evidence_dirs)
        evidence = (_first_existing(repo, ["README.md"]) or sources[0].path,) if sources else tuple()
        if not has_evidence_surface:
            return [
                Finding(
                    self.audit_type,
                    "Is there local evidence for release or benchmark claims?",
                    "Abstain: no local evidence/results/docs surface was detected for benchmark or release claims.",
                    evidence,
                    ("README", "evidence", "results", "docs"),
                    abstain=1,
                    plugin_id=self.plugin_id,
                )
            ]
        return [
            Finding(
                self.audit_type,
                "Is there local evidence for release or benchmark claims?",
                "Local evidence/documentation directories exist, but this audit does not promote release claims without exact source-bound receipts.",
                tuple(
                    candidate
                    for candidate in (_first_file_under(path) for path in evidence_dirs)
                    if candidate is not None
                )[:2] or evidence,
                ("evidence", "results", "docs"),
                plugin_id=self.plugin_id,
            )
        ]
