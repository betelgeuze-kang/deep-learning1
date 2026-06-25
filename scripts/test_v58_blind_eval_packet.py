"""Deterministic smoke test for scripts/v58_blind_eval_packet.py.

Exercises blind-map, reviewer-registry, and kappa on synthetic schema-test data
(allowed for schema testing only, never as real blind evidence).

Run:  python3 scripts/test_v58_blind_eval_packet.py
"""
from __future__ import annotations

import csv
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT = SCRIPTS_DIR.parent
TOOL = SCRIPTS_DIR / "v58_blind_eval_packet.py"
CONTRACT = ROOT / "v58" / "blind_eval_real.json"

if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))
from v58_blind_eval_packet import cohens_kappa  # noqa: E402


def run_tool(*args: str) -> int:
    return subprocess.run(
        [sys.executable, str(TOOL), "--contract", str(CONTRACT), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    ).returncode


def read_rows(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def test_cohens_kappa_value() -> None:
    pairs = [("y", "y"), ("y", "y"), ("n", "n"), ("n", "y")]
    po, pe, kappa = cohens_kappa(pairs)
    assert abs(po - 0.75) < 1e-9
    assert abs(pe - 0.5) < 1e-9
    assert abs(kappa - 0.5) < 1e-9
    # Perfect agreement -> kappa 1.0
    _, _, k_perfect = cohens_kappa([("a", "a"), ("b", "b")])
    assert abs(k_perfect - 1.0) < 1e-9
    print("kappa: numeric values OK")


def test_blind_map_and_assignment(tmp: Path) -> None:
    blind = tmp / "blind"
    assert run_tool(
        "blind-map", "--out", str(blind), "--systems", "A,B", "--queries-per-system", "2", "--seed", "1"
    ) == 0
    key_header, key_rows = read_rows(blind / "UNBLINDING_KEY.csv")
    assert {r["source_system_id"] for r in key_rows} == {"A", "B"}
    assert len({r["blind_system_id"] for r in key_rows}) == 2, "blind ids must be distinct"

    resp_header, resp_rows = read_rows(blind / "blind_response_template.csv")
    assert "blind_response_id" in resp_header and "response_text" in resp_header
    assert len(resp_rows) == 4, "2 systems x 2 queries"
    assert all(not (r["response_text"]).strip() for r in resp_rows), "response_text left for executor"
    # No source identity leaks into the blinded rows.
    assert all(r["blind_system_id"].startswith("S") for r in resp_rows)

    reg = tmp / "registry"
    assert run_tool(
        "reviewer-registry", "--out", str(reg), "--responses", str(blind / "blind_response_template.csv")
    ) == 0
    _, assignments = read_rows(reg / "review_assignment.csv")
    by_resp: dict[str, list[dict]] = {}
    for row in assignments:
        by_resp.setdefault(row["blind_response_id"], []).append(row)
    assert len(by_resp) == 4
    for response_id, assigned in by_resp.items():
        assert len(assigned) == 2, f"{response_id} needs 2 reviewers"
        assert assigned[0]["reviewer_pool_id"] != assigned[1]["reviewer_pool_id"], "distinct pools"
    print("blind-map + reviewer-registry: blinding, distinctness, 2-cross-pool OK")


def test_kappa_report(tmp: Path) -> None:
    reviews = tmp / "reviews.csv"
    header = ["blind_response_id", "reviewer_id", "answer_correctness", "review_decision"]
    rows = [
        {"blind_response_id": "r1", "reviewer_id": "rev-a1", "answer_correctness": "correct", "review_decision": "accept"},
        {"blind_response_id": "r1", "reviewer_id": "rev-b1", "answer_correctness": "correct", "review_decision": "accept"},
        {"blind_response_id": "r2", "reviewer_id": "rev-a1", "answer_correctness": "correct", "review_decision": "accept"},
        {"blind_response_id": "r2", "reviewer_id": "rev-b1", "answer_correctness": "incorrect", "review_decision": "accept"},
        {"blind_response_id": "r3", "reviewer_id": "rev-a1", "answer_correctness": "correct", "review_decision": "accept"},
        {"blind_response_id": "r3", "reviewer_id": "rev-b1", "answer_correctness": "correct", "review_decision": "accept"},
    ]
    with reviews.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    out = tmp / "kappa"
    assert run_tool("kappa", "--reviews", str(reviews), "--out", str(out)) == 0
    _, report = read_rows(out / "inter_rater_kappa_report.csv")
    metrics = {r["metric"]: r for r in report}
    assert "answer_correctness" in metrics and "review_decision" in metrics
    assert metrics["answer_correctness"]["n_responses"] == "3"
    assert metrics["answer_correctness"]["disagreements"] == "1"
    assert metrics["review_decision"]["disagreements"] == "0"

    _, queue = read_rows(out / "adjudication_queue_rows.csv")
    assert len(queue) == 1 and queue[0]["blind_response_id"] == "r2"
    print("kappa: report + adjudication queue OK")


def main() -> int:
    test_cohens_kappa_value()
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        test_blind_map_and_assignment(tmp)
        test_kappa_report(tmp)
    print("v58 blind eval packet smoke OK (staging only; admits no evidence)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
