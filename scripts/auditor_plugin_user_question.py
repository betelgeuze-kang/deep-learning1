from __future__ import annotations

from pathlib import Path

from auditor_plugins import AuditPlugin, Finding, PluginRule, SourceFile


class UserQuestionPlugin(AuditPlugin):
    plugin_id = "user_question"
    audit_type = "user_question"
    language = "generic"

    def rules(self) -> tuple[PluginRule, ...]:
        return (
            PluginRule(
                rule_id="user-question-source-evidence-required",
                language="generic",
                file_suffixes=("*",),
                pattern_label="free-form question abstains without exact evidence",
                evidence_policy="abstain-when-missing-source-bound-span",
            ),
        )

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
            rule_ids=("user-question-source-evidence-required",),
        )


USER_QUESTION_PLUGIN = UserQuestionPlugin()
