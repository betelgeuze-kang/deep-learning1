from __future__ import annotations

from pathlib import Path

from auditor_plugins import AuditPlugin, Finding, PluginRule, SourceFile, _first_existing


class UnsupportedClaimPlugin(AuditPlugin):
    plugin_id = "unsupported_claim"
    audit_type = "unsupported_claim"

    risky_terms = (
        "production ready",
        "production-ready",
        "release ready",
        "release-ready",
        "guaranteed",
        "sota",
        "state of the art",
        "human-level",
        "frontier",
    )

    def rules(self) -> tuple[PluginRule, ...]:
        return (
            PluginRule(
                rule_id="unsupported-claim-readiness-capability-wording",
                language="generic",
                file_suffixes=(".md", ".txt", ".py", ".toml", ".json", ".js", ".ts", ".cpp", ".hpp", ".c", ".h"),
                pattern_label="readiness/capability claim terms",
            ),
        )

    def run(self, repo: Path, sources: list[SourceFile]) -> list[Finding]:
        hits: list[Path] = []
        terms: list[str] = []
        for source in sources:
            lower = source.text.lower()
            matched = [term for term in self.risky_terms if term in lower]
            if matched:
                hits.append(source.path)
                terms.extend(matched)
            if len(hits) >= 5:
                break
        if hits:
            return [
                Finding(
                    self.audit_type,
                    "Does the repository contain unsupported readiness or capability wording?",
                    "Potential unsupported capability/readiness wording was detected and must remain blocked until evidence is supplied.",
                    tuple(hits),
                    tuple(dict.fromkeys(terms)),
                    severity="high",
                    unsupported_claim=1,
                    plugin_id=self.plugin_id,
                    rule_ids=("unsupported-claim-readiness-capability-wording",),
                )
            ]
        evidence = (_first_existing(repo, ["README.md"]) or sources[0].path,) if sources else tuple()
        return [
            Finding(
                self.audit_type,
                "Does the repository prove an unsupported production-readiness claim?",
                "Abstain: this local audit did not find independent release-review evidence and will not promote production-ready wording.",
                evidence,
                ("README",),
                abstain=1,
                plugin_id=self.plugin_id,
                rule_ids=("unsupported-claim-readiness-capability-wording",),
            )
        ]
