#!/usr/bin/env python3
"""Convert a captured Ollama /api/generate JSON response into metric replacement CSV values."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

METRIC_ENV_NAMES = (
    "V61HO_PROMPT_TOKENS",
    "V61HO_OUTPUT_TOKENS",
    "V61HO_PREFILL_MS",
    "V61HO_DECODE_MS",
    "V61HO_TOKENS_PER_SECOND",
)

TOTAL_MS_ENV_NAME = "V61HO_TOTAL_MS"

FORBIDDEN_VALUE_WORDS = (
    "template",
    "fixture",
    "synthetic",
    "sample",
    "example",
)


class MetricReplacementError(Exception):
    """Raised when Ollama metrics cannot be converted safely."""


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Convert a captured non-streaming Ollama /api/generate JSON response "
            "into first-real-slice replacement CSV metric values."
        )
    )
    parser.add_argument(
        "--ollama-response",
        required=True,
        help="Path to the captured Ollama /api/generate JSON response.",
    )
    parser.add_argument(
        "--replacements",
        required=True,
        help="Path to the replacements CSV to read and update.",
    )
    parser.add_argument(
        "--output",
        help="Optional output CSV path. Overrides --in-place when both are provided.",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Write updated replacements back to --replacements.",
    )
    parser.add_argument(
        "--update-total-ms",
        action="store_true",
        help="Also update V61HO_TOTAL_MS from Ollama total_duration.",
    )
    return parser.parse_args(argv)


def resolve_output_path(replacements_path: Path, output: str | None, in_place: bool) -> Path:
    if output:
        return Path(output)
    if in_place:
        return replacements_path
    return replacements_path.with_name(
        f"{replacements_path.stem}.metrics_candidate{replacements_path.suffix}"
    )


def load_ollama_response(path: Path) -> dict:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise MetricReplacementError(f"failed to read Ollama response: {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise MetricReplacementError(f"invalid JSON in Ollama response: {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise MetricReplacementError(
            f"Ollama response must be a JSON object, got {type(payload).__name__}"
        )
    return payload


def require_positive_number(payload: dict, field_name: str) -> float:
    if field_name not in payload:
        raise MetricReplacementError(f"missing required Ollama field: {field_name}")
    raw_value = payload[field_name]
    if isinstance(raw_value, bool) or not isinstance(raw_value, (int, float)):
        raise MetricReplacementError(
            f"non-numeric Ollama field: {field_name}={raw_value!r}"
        )
    value = float(raw_value)
    if value <= 0:
        raise MetricReplacementError(
            f"Ollama field must be positive: {field_name}={raw_value!r}"
        )
    return value


def format_replacement_value(value: float | int) -> str:
    if isinstance(value, bool):
        raise MetricReplacementError("replacement value must be numeric")
    if isinstance(value, int):
        text = str(value)
    else:
        numeric = float(value)
        if numeric.is_integer():
            text = str(int(numeric))
        else:
            text = format(numeric, ".6g")
    lowered = text.lower()
    for word in FORBIDDEN_VALUE_WORDS:
        if word in lowered:
            raise MetricReplacementError(
                f"generated replacement value contains forbidden word {word!r}: {text!r}"
            )
    return text


def nanoseconds_to_milliseconds(duration_ns: float) -> float:
    return duration_ns / 1_000_000.0


def derive_metric_replacements(payload: dict, update_total_ms: bool) -> dict[str, str]:
    prompt_tokens = int(require_positive_number(payload, "prompt_eval_count"))
    output_tokens = int(require_positive_number(payload, "eval_count"))
    prefill_ms = nanoseconds_to_milliseconds(
        require_positive_number(payload, "prompt_eval_duration")
    )
    eval_duration_ns = require_positive_number(payload, "eval_duration")
    decode_ms = nanoseconds_to_milliseconds(eval_duration_ns)
    tokens_per_second = output_tokens / (eval_duration_ns / 1_000_000_000.0)
    if tokens_per_second <= 0:
        raise MetricReplacementError(
            "derived tokens per second must be positive "
            f"(eval_count={output_tokens}, eval_duration={eval_duration_ns})"
        )

    replacements = {
        "V61HO_PROMPT_TOKENS": format_replacement_value(prompt_tokens),
        "V61HO_OUTPUT_TOKENS": format_replacement_value(output_tokens),
        "V61HO_PREFILL_MS": format_replacement_value(prefill_ms),
        "V61HO_DECODE_MS": format_replacement_value(decode_ms),
        "V61HO_TOKENS_PER_SECOND": format_replacement_value(tokens_per_second),
    }

    if update_total_ms:
        total_ms = nanoseconds_to_milliseconds(
            require_positive_number(payload, "total_duration")
        )
        replacements[TOTAL_MS_ENV_NAME] = format_replacement_value(total_ms)

    return replacements


def load_replacement_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    try:
        with path.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames is None:
                raise MetricReplacementError(f"replacements CSV has no header: {path}")
            rows = [dict(row) for row in reader]
    except OSError as exc:
        raise MetricReplacementError(f"failed to read replacements CSV: {path}: {exc}") from exc
    return list(reader.fieldnames), rows


def apply_metric_replacements(
    fieldnames: list[str],
    rows: list[dict[str, str]],
    metric_values: dict[str, str],
) -> list[str]:
    if "env_name" not in fieldnames:
        raise MetricReplacementError("replacements CSV must include env_name column")
    if "replacement_value" not in fieldnames:
        raise MetricReplacementError("replacements CSV must include replacement_value column")

    env_names_in_csv = {row.get("env_name", "") for row in rows}
    missing_env_names = sorted(name for name in metric_values if name not in env_names_in_csv)
    if missing_env_names:
        raise MetricReplacementError(
            "replacements CSV is missing required env_name rows: "
            + ", ".join(missing_env_names)
        )

    updated_env_names: list[str] = []
    for row in rows:
        env_name = row.get("env_name", "")
        if env_name not in metric_values:
            continue
        row["replacement_value"] = metric_values[env_name]
        updated_env_names.append(env_name)

    return updated_env_names


def write_replacement_rows(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
            writer.writeheader()
            writer.writerows(rows)
    except OSError as exc:
        raise MetricReplacementError(f"failed to write replacements CSV: {path}: {exc}") from exc


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    replacements_path = Path(args.replacements)
    ollama_response_path = Path(args.ollama_response)
    output_path = resolve_output_path(replacements_path, args.output, args.in_place)

    payload = load_ollama_response(ollama_response_path)
    metric_values = derive_metric_replacements(payload, args.update_total_ms)
    fieldnames, rows = load_replacement_rows(replacements_path)
    updated_env_names = apply_metric_replacements(fieldnames, rows, metric_values)
    write_replacement_rows(output_path, fieldnames, rows)

    print(output_path)
    print(",".join(updated_env_names))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except MetricReplacementError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
