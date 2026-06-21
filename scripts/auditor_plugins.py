from __future__ import annotations

import re
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


class DocCodeIdentityPlugin(AuditPlugin):
    plugin_id = "doc_code_identity"
    audit_type = "doc_code_identity"

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
            )
        ]


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
            )
        ]


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
                tuple(path for path in evidence_dirs if path.exists())[:2] or evidence,
                ("evidence", "results", "docs"),
                plugin_id=self.plugin_id,
            )
        ]


DEFAULT_PLUGINS: tuple[AuditPlugin, ...] = (
    DocCodeIdentityPlugin(),
    DeprecatedApiPlugin(),
    ConfigConsistencyPlugin(),
    UnsupportedClaimPlugin(),
    MissingEvidencePlugin(),
)
