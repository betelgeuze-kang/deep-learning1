from __future__ import annotations

import re
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
    negation_terms = (
        "not",
        "no",
        "never",
        "without",
        "blocked",
        "deferred",
        "false",
        "cannot",
        "must not",
        "do not",
        "does not",
        "not claim",
        "not promote",
        "not release",
    )

    def rules(self) -> tuple[PluginRule, ...]:
        return (
            PluginRule(
                rule_id="unsupported-claim-readiness-capability-wording",
                language="generic",
                file_suffixes=(".md", ".txt", ".py", ".toml", ".json", ".js", ".ts", ".cpp", ".hpp", ".c", ".h"),
                pattern_label="readiness/capability claim terms",
                parser_id="claim_boundary_negation_code_literal_filter",
            ),
        )

    def run(self, repo: Path, sources: list[SourceFile]) -> list[Finding]:
        hits: list[Path] = []
        terms: list[str] = []
        line_numbers: list[int] = []
        for source in sources:
            rel_lower = source.rel_path.lower()
            if "claim_boundary" in rel_lower or "claim-boundary" in rel_lower:
                continue
            matched: list[str] = []
            matched_line = 0
            for line_no, lower in self._iter_claim_candidate_lines(source):
                if self._line_is_boundary_or_negation(lower):
                    continue
                for term in self.risky_terms:
                    if not re.search(r"(?<![a-z0-9_-])" + re.escape(term) + r"(?![a-z0-9_-])", lower):
                        continue
                    matched.append(term)
                    matched_line = line_no
                    break
                if matched:
                    break
            if matched:
                hits.append(source.path)
                line_numbers.append(matched_line)
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
                    confidence="medium",
                    evidence_line_numbers=tuple(line_numbers),
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
                confidence="low",
            )
        ]

    @staticmethod
    def _iter_claim_candidate_lines(source: SourceFile) -> list[tuple[int, str]]:
        rows: list[tuple[int, str]] = []
        in_markdown_fence = False
        markdown_like = source.path.suffix.lower() in {".md", ".txt"}
        code_like = source.path.suffix.lower() in {
            ".py",
            ".js",
            ".jsx",
            ".ts",
            ".tsx",
            ".c",
            ".h",
            ".cc",
            ".cpp",
            ".cxx",
            ".hpp",
        }
        text = UnsupportedClaimPlugin._mask_code_comments_and_strings(source.text, source.path.suffix.lower()) if code_like else source.text
        for line_no, line in enumerate(text.splitlines(), start=1):
            stripped = line.lstrip()
            if markdown_like and (stripped.startswith("```") or stripped.startswith("~~~")):
                in_markdown_fence = not in_markdown_fence
                continue
            if in_markdown_fence:
                continue
            if markdown_like:
                line = UnsupportedClaimPlugin._mask_inline_markdown_code(line)
            rows.append((line_no, line.lower()))
        return rows

    @staticmethod
    def _mask_segment(text: str, start: int, end: int) -> str:
        return "".join("\n" if ch == "\n" else " " for ch in text[start:end])

    @staticmethod
    def _cpp_raw_string_end(text: str, start: int) -> int | None:
        if not text.startswith('R"', start):
            return None
        delimiter_start = start + 2
        open_paren = text.find("(", delimiter_start, delimiter_start + 18)
        if open_paren < 0:
            return None
        delimiter = text[delimiter_start:open_paren]
        if any(ch.isspace() or ch in {"(", ")", "\\"} for ch in delimiter):
            return None
        close = text.find(")" + delimiter + '"', open_paren + 1)
        if close < 0:
            return None
        return close + len(delimiter) + 2

    @staticmethod
    def _mask_code_comments_and_strings(text: str, suffix: str) -> str:
        out: list[str] = []
        idx = 0
        state = "code"
        quote = ""
        triple_quote = ""
        cpp_like = suffix in {".c", ".h", ".cc", ".cpp", ".cxx", ".hpp"}
        js_like = suffix in {".js", ".jsx", ".ts", ".tsx"}
        py_like = suffix == ".py"
        while idx < len(text):
            ch = text[idx]
            nxt = text[idx + 1] if idx + 1 < len(text) else ""
            if state == "code":
                if py_like and ch == "#":
                    out.append(" ")
                    idx += 1
                    state = "line_comment"
                    continue
                if (cpp_like or js_like) and ch == "/" and nxt == "/":
                    out.extend([" ", " "])
                    idx += 2
                    state = "line_comment"
                    continue
                if (cpp_like or js_like) and ch == "/" and nxt == "*":
                    out.extend([" ", " "])
                    idx += 2
                    state = "block_comment"
                    continue
                if cpp_like and ch == "R" and nxt == '"':
                    raw_end = UnsupportedClaimPlugin._cpp_raw_string_end(text, idx)
                    if raw_end is not None:
                        out.append(UnsupportedClaimPlugin._mask_segment(text, idx, raw_end))
                        idx = raw_end
                        continue
                if py_like and text.startswith("'''", idx):
                    out.extend([" ", " ", " "])
                    idx += 3
                    triple_quote = "'''"
                    state = "triple_string"
                    continue
                if py_like and text.startswith('"""', idx):
                    out.extend([" ", " ", " "])
                    idx += 3
                    triple_quote = '"""'
                    state = "triple_string"
                    continue
                if ch in {"'", '"'} or (js_like and ch == "`"):
                    quote = ch
                    out.append(" ")
                    idx += 1
                    state = "string"
                    continue
                out.append(ch)
                idx += 1
                continue
            if state == "line_comment":
                out.append("\n" if ch == "\n" else " ")
                if ch == "\n":
                    state = "code"
                idx += 1
                continue
            if state == "block_comment":
                if ch == "*" and nxt == "/":
                    out.extend([" ", " "])
                    idx += 2
                    state = "code"
                    continue
                out.append("\n" if ch == "\n" else " ")
                idx += 1
                continue
            if state == "triple_string":
                if text.startswith(triple_quote, idx):
                    out.extend([" ", " ", " "])
                    idx += 3
                    triple_quote = ""
                    state = "code"
                    continue
                out.append("\n" if ch == "\n" else " ")
                idx += 1
                continue
            if state == "string":
                if ch == "\\" and idx + 1 < len(text):
                    out.extend(["\n" if ch == "\n" else " ", "\n" if nxt == "\n" else " "])
                    idx += 2
                    continue
                out.append("\n" if ch == "\n" else " ")
                if ch == quote:
                    quote = ""
                    state = "code"
                idx += 1
                continue
        return "".join(out)

    @staticmethod
    def _mask_inline_markdown_code(line: str) -> str:
        chars = list(line)
        idx = 0
        while idx < len(chars):
            if chars[idx] != "`":
                idx += 1
                continue
            tick_end = idx
            while tick_end < len(chars) and chars[tick_end] == "`":
                tick_end += 1
            marker = "`" * (tick_end - idx)
            close = line.find(marker, tick_end)
            end = len(chars) if close < 0 else close + len(marker)
            for pos in range(idx, end):
                chars[pos] = " "
            idx = end
        return "".join(chars)

    @classmethod
    def _line_is_boundary_or_negation(cls, lower_line: str) -> bool:
        compact = " ".join(lower_line.split())
        if not compact:
            return True
        boundary_phrases = (
            "blocked claim",
            "blocked claims",
            "claim boundary",
            "must remain blocked",
            "remain blocked",
            "no release claim",
            "no production-ready claim",
            "not production ready",
            "not production-ready",
            "not release ready",
            "not release-ready",
            "not state of the art",
            "not human-level",
            "not frontier",
        )
        if any(phrase in compact for phrase in boundary_phrases):
            return True
        for term in cls.risky_terms:
            pos = compact.find(term)
            if pos < 0:
                continue
            window = compact[max(0, pos - 48):pos]
            if any(negation in window.split() for negation in {"not", "no", "never", "without", "cannot"}):
                return True
            if any((" " in phrase or "-" in phrase) and phrase in window for phrase in cls.negation_terms):
                return True
        return False
