"""Deterministic smoke test for scripts/v54_generation_training_packet.py.

Builds a valid filled packet (synthetic, schema-test only) and checks preflight
passes, then checks each v54 rule is fail-closed: teacher forcing at eval,
heldout/train repo overlap, free_running_in_eval=false, source-locator leakage,
and an out-of-heldout generation query.

Run:  python3 scripts/test_v54_generation_training_packet.py
"""
from __future__ import annotations

import csv
import json
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT = SCRIPTS_DIR.parent
TOOL = SCRIPTS_DIR / "v54_generation_training_packet.py"

if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))
from v54_generation_training_packet import (  # noqa: E402
    GEN_FIELDS,
    HELDOUT_METRIC_COLUMNS,
    SPLIT_COLUMNS,
    V54F_CONTRACT,
    generation_columns,
)

SHA = "sha256:" + "a" * 64
NUMERIC = {"output_token_count", "latency_ns", "peak_memory_mb", "retrieved_text_in_prompt"}


def write_csv(path: Path, header: list[str], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def gen_row(columns: list[str], query_id: str) -> dict:
    row = {}
    for col in columns:
        if col in GEN_FIELDS:
            row[col] = GEN_FIELDS[col]
        elif col.endswith("_sha256"):
            row[col] = SHA
        elif col == "query_id":
            row[col] = query_id
        elif col in NUMERIC:
            row[col] = "1"
        else:
            row[col] = ""
    return row


def split_rows(split: str, repos: list[str]) -> list[dict]:
    return [
        {"query_id": f"q{idx:06d}", "repo_id": repo, "split": split, "source_query_hash": SHA}
        for repo in repos
        for idx in (1, 2)
    ]


def build_valid(packet: Path, columns: list[str]) -> None:
    packet.mkdir(parents=True, exist_ok=True)
    write_csv(packet / "train_split_rows.csv", SPLIT_COLUMNS, split_rows("train", ["t1", "t2"]))
    write_csv(packet / "calibration_split_rows.csv", SPLIT_COLUMNS, split_rows("calibration", ["c1"]))
    write_csv(packet / "heldout_split_rows.csv", SPLIT_COLUMNS, split_rows("heldout", ["u1", "u2"]))
    (packet / "generation_config.json").write_text(
        json.dumps(
            {
                "generator_id": "ref",
                "seed": 0,
                "teacher_forcing_in_training": True,
                "free_running_in_eval": True,
                "raw_source_span_in_prompt": False,
                "source_locator_leakage": False,
            }
        ),
        encoding="utf-8",
    )
    (packet / "checkpoint_manifest.json").write_text(
        json.dumps({"checkpoint_sha256": SHA, "config_sha256": SHA, "trained_on_split": "train"}),
        encoding="utf-8",
    )
    write_csv(packet / "free_running_generation_rows.csv", columns, [gen_row(columns, "q000001")])
    write_csv(
        packet / "heldout_metric_rows.csv",
        HELDOUT_METRIC_COLUMNS,
        [{"split": "heldout", "metric": "answer_exact_match", "value": "0.5", "n": "2"}],
    )


def run_tool(*args: str) -> int:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    ).returncode


def main() -> int:
    columns = generation_columns(ROOT / V54F_CONTRACT)
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)

        # template emits the 7 packet files.
        out = tmp / "tmpl"
        assert run_tool("template", "--out", str(out)) == 0
        for name in ("train_split_rows.csv", "generation_config.json", "free_running_generation_rows.csv"):
            assert (out / name).is_file(), name
        print("template: emits packet files OK")

        # valid filled packet + manifest -> preflight passes.
        packet = tmp / "valid"
        build_valid(packet, columns)
        assert run_tool("manifest", "--packet", str(packet)) == 0
        assert run_tool("preflight", "--packet", str(packet), "--require-manifest") == 0
        print("preflight: valid packet PASS")

        # teacher forcing at eval -> blocked.
        p = tmp / "tf"
        build_valid(p, columns)
        rows = [gen_row(columns, "q000001")]
        rows[0]["teacher_forcing_used"] = "1"
        write_csv(p / "free_running_generation_rows.csv", columns, rows)
        assert run_tool("preflight", "--packet", str(p)) == 1
        print("preflight: teacher forcing at eval BLOCKED")

        # heldout repo overlaps train -> blocked.
        p = tmp / "overlap"
        build_valid(p, columns)
        write_csv(p / "heldout_split_rows.csv", SPLIT_COLUMNS, split_rows("heldout", ["t1", "u2"]))
        assert run_tool("preflight", "--packet", str(p)) == 1
        print("preflight: heldout/train overlap BLOCKED")

        # free_running_in_eval=false -> blocked.
        p = tmp / "noeval"
        build_valid(p, columns)
        cfg = json.loads((p / "generation_config.json").read_text())
        cfg["free_running_in_eval"] = False
        (p / "generation_config.json").write_text(json.dumps(cfg), encoding="utf-8")
        assert run_tool("preflight", "--packet", str(p)) == 1
        print("preflight: free_running_in_eval=false BLOCKED")

        # source locator leakage -> blocked.
        p = tmp / "leak"
        build_valid(p, columns)
        rows = [gen_row(columns, "q000001")]
        rows[0]["source_locator_leakage"] = "1"
        write_csv(p / "free_running_generation_rows.csv", columns, rows)
        assert run_tool("preflight", "--packet", str(p)) == 1
        print("preflight: source-locator leakage BLOCKED")

        # generation query not in heldout split -> blocked.
        p = tmp / "notheldout"
        build_valid(p, columns)
        write_csv(p / "free_running_generation_rows.csv", columns, [gen_row(columns, "q999999")])
        assert run_tool("preflight", "--packet", str(p)) == 1
        print("preflight: out-of-heldout generation query BLOCKED")

    print("v54 training/heldout packet smoke OK (staging/preflight only; admits no evidence)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
