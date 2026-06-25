"""Deterministic smoke test for scripts/v58_blind_eval_packet.py.

Covers HMAC blinding + secret/public separation, reviewer-registry integrity,
review completeness (assignment/review binding, 2-review fail-closed,
allowed-value validation), and Cohen's kappa. Synthetic data is for schema
testing only, never real blind evidence.

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
SECRET = "00112233445566778899aabbccddeeff"

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


def write_rows(path: Path, header: list[str], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def test_cohens_kappa_value() -> None:
    po, pe, kappa = cohens_kappa([("y", "y"), ("y", "y"), ("n", "n"), ("n", "y")])
    assert abs(po - 0.75) < 1e-9 and abs(pe - 0.5) < 1e-9 and abs(kappa - 0.5) < 1e-9
    print("kappa: numeric values OK")


def test_blind_map(tmp: Path) -> Path:
    blind = tmp / "blind"
    assert run_tool(
        "blind-map", "--out", str(blind), "--systems", "A,B",
        "--queries-per-system", "2", "--secret", SECRET,
    ) == 0
    assert (blind / "SECRET_unblinding_key.csv").is_file()
    assert (blind / "SECRET_hmac_key.txt").is_file()
    pub = blind / "public_blind_response_template.csv"
    header, rows = read_rows(pub)
    assert "source_system_id" not in header, "public file must not expose source identity"
    assert len(rows) == 4
    assert all(r["blind_system_id"].startswith("s") for r in rows)
    assert all(r["blind_response_id"].startswith("r") for r in rows)
    assert len({r["blind_response_id"] for r in rows}) == 4, "HMAC ids must be distinct"

    # Determinism: same secret reproduces identical blind ids.
    blind2 = tmp / "blind2"
    assert run_tool(
        "blind-map", "--out", str(blind2), "--systems", "A,B",
        "--queries-per-system", "2", "--secret", SECRET,
    ) == 0
    _, rows2 = read_rows(blind2 / "public_blind_response_template.csv")
    assert [r["blind_response_id"] for r in rows] == [r["blind_response_id"] for r in rows2]
    print("blind-map: HMAC ids + secret/public separation + determinism OK")
    return blind


def test_registry_and_assignment(tmp: Path, blind: Path) -> Path:
    reg = tmp / "registry"
    pub = blind / "public_blind_response_template.csv"
    assert run_tool("reviewer-registry", "--out", str(reg), "--responses", str(pub)) == 0
    _, assignments = read_rows(reg / "review_assignment.csv")
    by_resp: dict[str, list[dict]] = {}
    for row in assignments:
        by_resp.setdefault(row["blind_response_id"], []).append(row)
    assert len(by_resp) == 4
    for assigned in by_resp.values():
        assert len(assigned) == 2 and assigned[0]["reviewer_pool_id"] != assigned[1]["reviewer_pool_id"]

    # Registry integrity: a single-pool registry is blocked.
    bad = tmp / "bad_registry.csv"
    write_rows(
        bad,
        ["reviewer_id", "reviewer_pool_id", "reviewer_independent", "conflict_disclosed"],
        [
            {"reviewer_id": "x1", "reviewer_pool_id": "pool-1", "reviewer_independent": "true", "conflict_disclosed": "true"},
            {"reviewer_id": "x2", "reviewer_pool_id": "pool-1", "reviewer_independent": "true", "conflict_disclosed": "true"},
        ],
    )
    assert run_tool("reviewer-registry", "--out", str(tmp / "reg_bad"), "--responses", str(pub), "--registry", str(bad)) == 1
    print("reviewer-registry: assignment + single-pool integrity block OK")
    return reg / "review_assignment.csv"


def _reviews_from_assignment(assignment_path: Path) -> list[dict]:
    _, assignments = read_rows(assignment_path)
    return [
        {
            "blind_response_id": a["blind_response_id"],
            "reviewer_id": a["reviewer_id"],
            "answer_correctness": "correct",
            "review_decision": "accept",
        }
        for a in assignments
    ]


def test_completeness(tmp: Path, assignment_path: Path) -> None:
    header = ["blind_response_id", "reviewer_id", "answer_correctness", "review_decision"]
    reviews = tmp / "reviews.csv"

    # Complete + valid -> pass.
    rows = _reviews_from_assignment(assignment_path)
    write_rows(reviews, header, rows)
    assert run_tool("completeness", "--assignment", str(assignment_path), "--reviews", str(reviews)) == 0
    print("completeness: full 2-review + binding PASS")

    # Drop one review -> fail closed.
    write_rows(reviews, header, rows[:-1])
    assert run_tool("completeness", "--assignment", str(assignment_path), "--reviews", str(reviews)) == 1
    print("completeness: missing review BLOCKED")

    # Disallowed metric value -> blocked.
    bad_rows = _reviews_from_assignment(assignment_path)
    bad_rows[0]["answer_correctness"] = "maybe"
    write_rows(reviews, header, bad_rows)
    assert run_tool("completeness", "--assignment", str(assignment_path), "--reviews", str(reviews)) == 1
    print("completeness: disallowed value BLOCKED")

    # Unassigned reviewer -> blocked.
    bad_rows = _reviews_from_assignment(assignment_path)
    bad_rows[0]["reviewer_id"] = "stranger"
    write_rows(reviews, header, bad_rows)
    assert run_tool("completeness", "--assignment", str(assignment_path), "--reviews", str(reviews)) == 1
    print("completeness: unassigned reviewer BLOCKED")


def main() -> int:
    test_cohens_kappa_value()
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        blind = test_blind_map(tmp)
        assignment_path = test_registry_and_assignment(tmp, blind)
        test_completeness(tmp, assignment_path)
    print("v58 blind eval packet v2 smoke OK (staging only; admits no evidence)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
