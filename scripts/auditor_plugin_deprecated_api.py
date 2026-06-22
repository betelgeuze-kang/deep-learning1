from __future__ import annotations

import ast
import re
from pathlib import Path

from auditor_plugins import AuditPlugin, Finding, PluginRule, SourceFile, _first_existing


class DeprecatedApiPlugin(AuditPlugin):
    plugin_id = "deprecated_api"
    audit_type = "deprecated_api"
    language = "multi"

    patterns = (
        ({".py"}, "distutils", "python distutils import/call"),
        ({".py"}, "imp", "python imp import/call"),
        ({".py"}, "pkg_resources", "python pkg_resources import/call"),
        ({".cfg", ".toml"}, "setup.py test", "python setup.py test config usage"),
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

    @staticmethod
    def parser_for_suffixes(suffixes: set[str]) -> str:
        if suffixes <= {".py"}:
            return "python_ast"
        if suffixes <= {".c", ".h", ".cc", ".cpp", ".cxx", ".hpp"}:
            return "cpp_lexical_code_candidate_parser"
        if suffixes <= {".js", ".jsx", ".ts", ".tsx"}:
            return "javascript_typescript_lexical_code_candidate_parser"
        return "text_pattern"

    def rules(self) -> tuple[PluginRule, ...]:
        return tuple(
            PluginRule(
                rule_id=f"deprecated-api-{idx:02d}",
                language=self.language_for_suffixes(set(suffixes)),
                file_suffixes=tuple(sorted(suffixes)),
                pattern_label=label,
                parser_id=self.parser_for_suffixes(set(suffixes)),
            )
            for idx, (suffixes, _needle, label) in enumerate(self.patterns, start=1)
        )

    def rule_ids_for_labels(self, labels: set[str]) -> tuple[str, ...]:
        return tuple(
            f"deprecated-api-{idx:02d}"
            for idx, (_suffixes, _needle, label) in enumerate(self.patterns, start=1)
            if label in labels
        )

    @staticmethod
    def _python_ast_hits(source: SourceFile) -> list[tuple[Path, str, str, int]]:
        hits: list[tuple[Path, str, str, int]] = []
        try:
            tree = ast.parse(source.text, filename=str(source.path))
        except SyntaxError:
            return hits
        deprecated_modules = {
            "distutils": ("python distutils import/call", "distutils"),
            "imp": ("python imp import/call", "imp"),
            "pkg_resources": ("python pkg_resources import/call", "pkg_resources"),
        }

        def dotted_name(node: ast.AST) -> str:
            if isinstance(node, ast.Name):
                return node.id
            if isinstance(node, ast.Attribute):
                parent = dotted_name(node.value)
                return f"{parent}.{node.attr}" if parent else node.attr
            return ""

        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    root = alias.name.split(".", 1)[0]
                    if root in deprecated_modules:
                        label, needle = deprecated_modules[root]
                        hits.append((source.path, label, needle, int(getattr(node, "lineno", 1))))
            elif isinstance(node, ast.ImportFrom):
                root = (node.module or "").split(".", 1)[0]
                if root in deprecated_modules:
                    label, needle = deprecated_modules[root]
                    hits.append((source.path, label, needle, int(getattr(node, "lineno", 1))))
            elif isinstance(node, ast.Call):
                root = dotted_name(node.func).split(".", 1)[0]
                if root in deprecated_modules:
                    label, needle = deprecated_modules[root]
                    hits.append((source.path, label, needle, int(getattr(node, "lineno", 1))))
            if len(hits) >= 5:
                break
        return hits

    @staticmethod
    def _previous_significant_token(masked_text: str) -> tuple[str, str]:
        idx = len(masked_text) - 1
        while idx >= 0 and masked_text[idx].isspace():
            idx -= 1
        if idx < 0:
            return "", ""
        ch = masked_text[idx]
        if ch.isidentifier() or ch in {"$", "_"}:
            end = idx + 1
            while idx >= 0 and (masked_text[idx].isalnum() or masked_text[idx] in {"$", "_"}):
                idx -= 1
            return masked_text[idx + 1 : end], "word"
        return ch, "char"

    @staticmethod
    def _regex_literal_end(text: str, start: int) -> int | None:
        idx = start + 1
        in_class = False
        while idx < len(text):
            ch = text[idx]
            if ch == "\n" or ch == "\r":
                return None
            if ch == "\\":
                idx += 2
                continue
            if ch == "[":
                in_class = True
                idx += 1
                continue
            if ch == "]" and in_class:
                in_class = False
                idx += 1
                continue
            if ch == "/" and not in_class:
                idx += 1
                while idx < len(text) and (text[idx].isalpha() or text[idx].isdigit()):
                    idx += 1
                return idx
            idx += 1
        return None

    @staticmethod
    def _looks_like_js_regex_start(masked_text: str) -> bool:
        token, token_type = DeprecatedApiPlugin._previous_significant_token(masked_text)
        if not token:
            return True
        if token_type == "word":
            return token in {"return", "throw", "case", "delete", "typeof", "void", "new", "in", "of", "yield", "await"}
        return token in {"(", "[", "{", ":", ";", ",", "=", "!", "?", "&", "|", "+", "-", "*", "~", "^", "<", ">"}

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
        closing = ")" + delimiter + '"'
        close_start = text.find(closing, open_paren + 1)
        if close_start < 0:
            return None
        return close_start + len(closing)

    @staticmethod
    def _quoted_string_end(text: str, start: int, quote: str) -> int:
        idx = start + 1
        while idx < len(text):
            ch = text[idx]
            if ch == "\\" and idx + 1 < len(text):
                idx += 2
                continue
            if ch == quote:
                return idx + 1
            idx += 1
        return len(text)

    @staticmethod
    def _js_template_expression_end(text: str, start: int) -> int | None:
        idx = start
        depth = 1
        masked_expression: list[str] = []
        while idx < len(text):
            ch = text[idx]
            nxt = text[idx + 1] if idx + 1 < len(text) else ""
            if ch == "/" and nxt == "/":
                newline = text.find("\n", idx + 2)
                if newline < 0:
                    return None
                masked_expression.append(DeprecatedApiPlugin._masked_segment(text, idx, newline + 1))
                idx = newline + 1
                continue
            if ch == "/" and nxt == "*":
                close = text.find("*/", idx + 2)
                if close < 0:
                    return None
                masked_expression.append(DeprecatedApiPlugin._masked_segment(text, idx, close + 2))
                idx = close + 2
                continue
            if ch == "/" and nxt not in {"/", "*"} and DeprecatedApiPlugin._looks_like_js_regex_start("".join(masked_expression)):
                regex_end = DeprecatedApiPlugin._regex_literal_end(text, idx)
                if regex_end is not None:
                    masked_expression.append(DeprecatedApiPlugin._masked_segment(text, idx, regex_end))
                    idx = regex_end
                    continue
            if ch in {"'", '"'}:
                string_end = DeprecatedApiPlugin._quoted_string_end(text, idx, ch)
                masked_expression.append(DeprecatedApiPlugin._masked_segment(text, idx, string_end))
                idx = string_end
                continue
            if ch == "`":
                template_end = DeprecatedApiPlugin._js_template_literal_end(text, idx)
                if template_end is None:
                    return None
                masked_expression.append(DeprecatedApiPlugin._masked_segment(text, idx, template_end))
                idx = template_end
                continue
            if ch == "{":
                depth += 1
                masked_expression.append(ch)
                idx += 1
                continue
            if ch == "}":
                depth -= 1
                if depth == 0:
                    return idx
                masked_expression.append(ch)
                idx += 1
                continue
            masked_expression.append(ch)
            idx += 1
        return None

    @staticmethod
    def _js_template_literal_end(text: str, start: int) -> int | None:
        idx = start + 1
        while idx < len(text):
            ch = text[idx]
            nxt = text[idx + 1] if idx + 1 < len(text) else ""
            if ch == "\\" and idx + 1 < len(text):
                idx += 2
                continue
            if ch == "`":
                return idx + 1
            if ch == "$" and nxt == "{":
                expression_end = DeprecatedApiPlugin._js_template_expression_end(text, idx + 2)
                if expression_end is None:
                    return None
                idx = expression_end + 1
                continue
            idx += 1
        return None

    @staticmethod
    def _mask_js_template_literal(text: str, start: int) -> tuple[str, int]:
        out = [" "]
        idx = start + 1
        while idx < len(text):
            ch = text[idx]
            nxt = text[idx + 1] if idx + 1 < len(text) else ""
            if ch == "\\" and idx + 1 < len(text):
                out.append(DeprecatedApiPlugin._masked_segment(text, idx, idx + 2))
                idx += 2
                continue
            if ch == "`":
                out.append(" ")
                return "".join(out), idx + 1
            if ch == "$" and nxt == "{":
                expression_end = DeprecatedApiPlugin._js_template_expression_end(text, idx + 2)
                if expression_end is None:
                    out.append(DeprecatedApiPlugin._masked_segment(text, idx, len(text)))
                    return "".join(out), len(text)
                expression_text = text[idx + 2 : expression_end]
                out.append("  ")
                out.append(DeprecatedApiPlugin._code_without_comments_or_strings(expression_text, language="javascript"))
                out.append(" ")
                idx = expression_end + 1
                continue
            out.append("\n" if ch == "\n" else " ")
            idx += 1
        return "".join(out), len(text)

    @staticmethod
    def _masked_segment(text: str, start: int, end: int) -> str:
        return "".join("\n" if ch == "\n" else " " for ch in text[start:end])

    @staticmethod
    def _code_without_comments_or_strings(text: str, language: str = "generic") -> str:
        out: list[str] = []
        idx = 0
        state = "code"
        quote = ""
        while idx < len(text):
            ch = text[idx]
            nxt = text[idx + 1] if idx + 1 < len(text) else ""
            if state == "code":
                if language == "cpp" and ch == "R" and nxt == '"':
                    raw_end = DeprecatedApiPlugin._cpp_raw_string_end(text, idx)
                    if raw_end is not None:
                        out.append(DeprecatedApiPlugin._masked_segment(text, idx, raw_end))
                        idx = raw_end
                        continue
                if ch == "/" and nxt == "/":
                    out.extend([" ", " "])
                    idx += 2
                    state = "line_comment"
                    continue
                if ch == "/" and nxt == "*":
                    out.extend([" ", " "])
                    idx += 2
                    state = "block_comment"
                    continue
                if language == "javascript" and ch == "/" and nxt not in {"/", "*"} and DeprecatedApiPlugin._looks_like_js_regex_start("".join(out)):
                    regex_end = DeprecatedApiPlugin._regex_literal_end(text, idx)
                    if regex_end is not None:
                        out.append(DeprecatedApiPlugin._masked_segment(text, idx, regex_end))
                        idx = regex_end
                        continue
                if language == "javascript" and ch == "`":
                    masked, end = DeprecatedApiPlugin._mask_js_template_literal(text, idx)
                    out.append(masked)
                    idx = end
                    continue
                if ch in {"'", '"', "`"}:
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
            if state == "string":
                if ch == "\\" and idx + 1 < len(text):
                    out.extend(["\n" if ch == "\n" else " ", "\n" if nxt == "\n" else " "])
                    idx += 2
                    continue
                out.append("\n" if ch == "\n" else " ")
                if ch == quote:
                    state = "code"
                    quote = ""
                idx += 1
                continue
        return "".join(out)

    @staticmethod
    def _first_code_line_for(code_text: str, needle: str) -> int | None:
        if needle == "var ":
            pattern = re.compile(r"(^|[^A-Za-z0-9_$])var\s+")
            for idx, line in enumerate(code_text.splitlines(), start=1):
                if pattern.search(line):
                    return idx
            return None
        for idx, line in enumerate(code_text.splitlines(), start=1):
            if needle in line:
                return idx
        return None

    def run(self, repo: Path, sources: list[SourceFile]) -> list[Finding]:
        hits: list[tuple[Path, str, str, int]] = []
        for source in sources:
            suffix = source.path.suffix.lower()
            if suffix == ".py":
                hits.extend(self._python_ast_hits(source))
                if len(hits) >= 5:
                    break
                continue
            if suffix in {".c", ".h", ".cc", ".cpp", ".cxx", ".hpp"}:
                code_text = self._code_without_comments_or_strings(source.text, language="cpp")
            elif suffix in {".js", ".jsx", ".ts", ".tsx"}:
                code_text = self._code_without_comments_or_strings(source.text, language="javascript")
            else:
                code_text = source.text
            for suffixes, needle, label in self.patterns:
                if suffix not in suffixes:
                    continue
                line_no = self._first_code_line_for(code_text, needle)
                if line_no is not None:
                    hits.append((source.path, label, needle, line_no))
                    break
            if len(hits) >= 5:
                break
        if hits:
            hits = hits[:5]
            labels = sorted({label for _, label, _, _ in hits})
            rule_ids = self.rule_ids_for_labels(set(labels))
            return [
                Finding(
                    self.audit_type,
                    "Are there source-bound deprecated or legacy API usage candidates?",
                    "Potential deprecated/legacy usage candidates detected: " + ", ".join(labels) + ".",
                    tuple(path for path, _, _, _ in hits),
                    tuple(needle for _, _, needle, _ in hits),
                    severity="medium",
                    plugin_id=self.plugin_id,
                    language=self.language,
                    rule_ids=rule_ids,
                    confidence="medium",
                    evidence_line_numbers=tuple(line_no for _, _, _, line_no in hits),
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
                rule_ids=tuple(rule.rule_id for rule in self.rules()),
            )
        ]
