from __future__ import annotations

import re
from pathlib import Path

from auditor_plugins import AuditPlugin, Finding, PluginRule, SourceFile, _first_existing, _read


class DocCodeIdentityPlugin(AuditPlugin):
    plugin_id = "doc_code_identity"
    audit_type = "doc_code_identity"

    def rules(self) -> tuple[PluginRule, ...]:
        return (
            PluginRule(
                rule_id="doc-code-identity-readme-config-name",
                language="generic",
                file_suffixes=("README.md", "README.rst", "README.txt", "pyproject.toml", "package.json", "setup.cfg"),
                pattern_label="README heading/package name consistency",
            ),
        )

    def run(self, repo: Path, sources: list[SourceFile]) -> list[Finding]:
        readme = _first_existing(repo, ["README.md", "README.rst", "README.txt"])
        config = _first_existing(repo, ["pyproject.toml", "package.json", "setup.cfg"])
        if readme is None:
            return [
                Finding(
                    self.audit_type,
                    "Can project identity be checked against top-level documentation?",
                    "Abstain: README was not found, so project identity cannot be checked.",
                    (sources[0].path,) if sources else tuple(),
                    ("README",),
                    abstain=1,
                    plugin_id=self.plugin_id,
                    rule_ids=("doc-code-identity-readme-config-name",),
                )
            ]
        if config is None:
            return [
                Finding(
                    self.audit_type,
                    "Can project identity be checked against package config?",
                    "Abstain: package/config file was not found, so project identity cannot be verified.",
                    (readme,),
                    ("# ",),
                    abstain=1,
                    plugin_id=self.plugin_id,
                    rule_ids=("doc-code-identity-readme-config-name",),
                )
            ]

        readme_h1 = ""
        for line in _read(readme).splitlines():
            if line.startswith("# "):
                readme_h1 = line[2:].strip()
                break
        config_text = _read(config)
        name_match = re.search(r'(?m)^\s*name\s*=\s*["\']([^"\']+)["\']', config_text)
        package_match = re.search(r'"name"\s*:\s*"([^"]+)"', config_text)
        package_name = (name_match or package_match).group(1) if (name_match or package_match) else config.stem
        normalized_readme = re.sub(r"[^a-z0-9]+", "", readme_h1.lower())
        normalized_package = re.sub(r"[^a-z0-9]+", "", package_name.lower())
        if readme_h1 and package_name and normalized_readme != normalized_package:
            answer = f"Potential doc-code naming mismatch: README title '{readme_h1}' differs from package/config name '{package_name}'."
            severity = "medium"
        else:
            answer = "README title and package/config name appear consistent in this deterministic scan."
            severity = "info"
        return [
            Finding(
                self.audit_type,
                "Does top-level documentation agree with project/package identity?",
                answer,
                (readme, config),
                tuple(term for term in [readme_h1, package_name, "name"] if term),
                severity=severity,
                plugin_id=self.plugin_id,
                rule_ids=("doc-code-identity-readme-config-name",),
            )
        ]
