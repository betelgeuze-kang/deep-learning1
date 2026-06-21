from __future__ import annotations

from pathlib import Path

from auditor_plugins import AuditPlugin, Finding, SourceFile


class UserQuestionPlugin(AuditPlugin):
    plugin_id = "user_question"
    audit_type = "user_question"
    language = "generic"

    def run(self, repo: Path, sources: list[SourceFile]) -> list[Finding]:
        return []

    def run_question(self, sources: list[SourceFile], question: str) -> Finding | None:
        if not question:
            return None
        evidence = tuple([sources[0].path]) if sources else tuple()
        return Finding(
            self.audit_type,
            question,
            "Abstain: free-form user questions require exact source evidence; this alpha path records the question but does not infer an unsupported answer.",
            evidence,
            grounded=0,
            abstain=1,
            plugin_id=self.plugin_id,
        )


USER_QUESTION_PLUGIN = UserQuestionPlugin()
