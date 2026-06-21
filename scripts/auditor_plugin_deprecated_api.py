from __future__ import annotations

from pathlib import Path

from auditor_plugins import AuditPlugin, Finding, PluginRule, SourceFile, _first_existing


class DeprecatedApiPlugin(AuditPlugin):
    plugin_id = "deprecated_api"
    audit_type = "deprecated_api"
    language = "multi"

    patterns = (
        ({".py", ".cfg", ".toml", ".md", ".txt"}, "distutils", "python distutils usage"),
        ({".py", ".cfg", ".toml", ".md", ".txt"}, "imp.", "python imp module usage"),
        ({".py", ".cfg", ".toml", ".md", ".txt"}, "pkg_resources", "python pkg_resources usage"),
        ({".py", ".cfg", ".toml", ".md", ".txt"}, "setup.py test", "python setup.py test usage"),
        ({".c", ".h", ".cc", ".cpp", ".cxx", ".hpp"}, "std::auto_ptr", "c++ std::auto_ptr usage"),
        ({".c", ".h", ".cc", ".cpp", ".cxx", ".hpp"}, "gets(", "c/c++ gets usage"),
        ({".js", ".jsx", ".ts", ".tsx"}, "document.write", "javascript document.write usage"),
        ({".js", ".jsx", ".ts", ".tsx"}, "eval(", "javascript eval usage"),
        ({".js", ".jsx", ".ts", ".tsx"}, "var ", "javascript var declaration candidate"),
    )

    @staticmethod
    def language_for_suffixes(suffixes: set[str]) -> str:
        if suffixes <= {".py", ".cfg", ".toml", ".md", ".txt"}:
            return "python"
        if suffixes <= {".c", ".h", ".cc", ".cpp", ".cxx", ".hpp"}:
            return "cpp"
        if suffixes <= {".js", ".jsx", ".ts", ".tsx"}:
            return "javascript"
        return "generic"

    def rules(self) -> tuple[PluginRule, ...]:
        return tuple(
            PluginRule(
                rule_id=f"deprecated-api-{idx:02d}",
                language=self.language_for_suffixes(set(suffixes)),
                file_suffixes=tuple(sorted(suffixes)),
                pattern_label=label,
            )
            for idx, (suffixes, _needle, label) in enumerate(self.patterns, start=1)
        )

    def run(self, repo: Path, sources: list[SourceFile]) -> list[Finding]:
        hits: list[tuple[Path, str, str]] = []
        for source in sources:
            suffix = source.path.suffix.lower()
            for suffixes, needle, label in self.patterns:
                if suffix not in suffixes:
                    continue
                if needle in source.text:
                    hits.append((source.path, label, needle))
                    break
            if len(hits) >= 5:
                break
        if hits:
            labels = sorted({label for _, label, _ in hits})
            return [
                Finding(
                    self.audit_type,
                    "Are there source-bound deprecated or legacy API usage candidates?",
                    "Potential deprecated/legacy usage candidates detected: " + ", ".join(labels) + ".",
                    tuple(path for path, _, _ in hits),
                    tuple(needle for _, _, needle in hits),
                    severity="medium",
                    plugin_id=self.plugin_id,
                    language=self.language,
                )
            ]
        evidence = (_first_existing(repo, ["README.md"]) or sources[0].path,) if sources else tuple()
        return [
            Finding(
                self.audit_type,
                "Are there source-bound deprecated or legacy API usage candidates?",
                "No deprecated/legacy API candidate was detected by the deterministic pattern set.",
                evidence,
                ("README",),
                plugin_id=self.plugin_id,
                language=self.language,
            )
        ]
