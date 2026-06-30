#!/usr/bin/env python3
"""Smoke tests for scripts/audit_my_repo_label_intake.py decision normalization."""
from __future__ import annotations

from audit_my_repo_label_intake import normalize_decisions


def expect_value_error(rows: list[dict], expected: str) -> None:
    try:
        normalize_decisions(rows)
    except ValueError as exc:
        assert expected in str(exc), str(exc)
    else:
        raise AssertionError(f"expected ValueError containing {expected!r}")


def main() -> int:
    valid = normalize_decisions(
        [
            {
                "candidate_label_id": "case-001-0001",
                "label_id": "case-001-label",
                "human_labeled": True,
                "expected": "present",
                "priority": "P1",
                "reviewer_id": "reviewer-one",
                "maintainer_id": "maintainer.alpha+repo@review.invalid",
                "maintainer_feedback": True,
            }
        ]
    )
    assert valid[0]["candidate_label_id"] == "case-001-0001"
    assert valid[0]["label_id"] == "case-001-label"
    assert valid[0]["reviewer_id_sha256"].startswith("sha256:")
    assert valid[0]["maintainer_id"] == "maintainer.alpha+repo@review.invalid"
    assert valid[0]["maintainer_feedback"] == 1

    expect_value_error(
        [{"candidate_label_id": "EXAMPLE-case-0001", "human_labeled": True, "expected": "present"}],
        "candidate_label_id must not be example/placeholder",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "label_id": "EXAMPLE-label",
                "human_labeled": True,
                "expected": "present",
            }
        ],
        "label_id must not be example/placeholder",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "reviewer_id": "reviewer alpha",
                "human_labeled": True,
                "expected": "present",
            }
        ],
        "reviewer_id must be a safe identifier",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "reviewer_id": "EXAMPLE-reviewer",
                "human_labeled": True,
                "expected": "present",
            }
        ],
        "reviewer_id must not be example/placeholder",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "maintainer_id": "maintainer alpha",
                "human_labeled": True,
                "expected": "present",
            }
        ],
        "maintainer_id must be a safe identifier",
    )
    expect_value_error(
        [
            {
                "candidate_label_id": "case-001-0001",
                "maintainer_id": "EXAMPLE-maintainer",
                "human_labeled": True,
                "expected": "present",
            }
        ],
        "maintainer_id must not be example/placeholder",
    )

    print("audit_my_repo_label_intake decision normalization smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
