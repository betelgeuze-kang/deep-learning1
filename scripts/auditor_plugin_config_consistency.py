from __future__ import annotations

from pathlib import Path

from auditor_plugins import AuditPlugin, Finding, SourceFile, _first_existing, _read


class ConfigConsistencyPlugin(AuditPlugin):
    plugin_id = "config_consistency"
    audit_type = "config_consistency"

    def run(self, repo: Path, sources: list[SourceFile]) -> list[Finding]:
        config = _first_existing(repo, ["pyproject.toml", "setup.cfg", "tox.ini", "CMakeLists.txt", "package.json"])
        readme = _first_existing(repo, ["README.md", "README.rst", "README.txt"])
        if config is None:
            return [
                Finding(
                    self.audit_type,
                    "Is there a source-bound configuration surface to inspect?",
                    "Abstain: no supported config file was found.",
                    (readme or sources[0].path,) if sources else tuple(),
                    ("README",),
                    abstain=1,
                    plugin_id=self.plugin_id,
                )
            ]
        config_text = _read(config)
        if "requires-python" in config_text and readme and "Python" in _read(readme):
            answer = "Python/runtime configuration is source-bound; any version mismatch requires human review before promotion."
        else:
            answer = "A source-bound configuration file was found; no deterministic promoted mismatch was detected."
        return [
            Finding(
                self.audit_type,
                "Is there a source-bound configuration mismatch candidate?",
                answer,
                tuple(path for path in [config, readme] if path is not None),
                ("requires-python", "Python", "name"),
                plugin_id=self.plugin_id,
            )
        ]
