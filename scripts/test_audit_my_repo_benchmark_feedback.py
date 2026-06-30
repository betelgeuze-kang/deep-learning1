#!/usr/bin/env python3
"""Smoke tests for maintainer feedback normalization."""
from __future__ import annotations

from audit_my_repo_benchmark import normalize_maintainer_feedback, sha256_text


CASES = [{"case_id": "case-001", "human_labeled": True, "synthetic": False}]


def expect_value_error(rows: list[dict], expected: str) -> None:
    try:
        normalize_maintainer_feedback(rows, CASES)
    except ValueError as exc:
        assert expected in str(exc), str(exc)
    else:
        raise AssertionError(f"expected ValueError containing {expected!r}")


def main() -> int:
    feedback_text = "Reviewed the source-bound findings for case 001."
    valid = normalize_maintainer_feedback(
        [
            {
                "feedback_id": "fb-001",
                "case_id": "case-001",
                "maintainer_id": "maintainer.alpha+repo@review.invalid",
                "human_feedback": True,
                "synthetic": False,
                "feedback_text": feedback_text,
                "feedback_text_sha256": sha256_text(feedback_text),
            }
        ],
        CASES,
    )
    assert valid[0]["feedback_text_sha256"] == sha256_text(feedback_text)
    assert valid[0]["feedback_text_bytes"] == len(feedback_text.encode("utf-8"))
    assert valid[0]["maintainer_id_sha256"].startswith("sha256:")
    assert valid[0]["counts_for_beta"] == 1

    sha_only = normalize_maintainer_feedback(
        [
            {
                "feedback_id": "fb-002",
                "case_id": "case-001",
                "maintainer_id": "maintainer-beta",
                "human_feedback": True,
                "synthetic": False,
                "feedback_text_sha256": "sha256:" + ("1" * 64),
            }
        ],
        CASES,
    )
    assert sha_only[0]["feedback_text_sha256"] == "sha256:" + ("1" * 64)
    assert sha_only[0]["feedback_text_bytes"] == 0

    expect_value_error(
        [
            {
                "case_id": "case-001",
                "maintainer_id": "EXAMPLE-maintainer",
                "human_feedback": True,
                "feedback_text": feedback_text,
            }
        ],
        "maintainer_id must not be example/placeholder",
    )
    expect_value_error(
        [
            {
                "case_id": "case-001",
                "maintainer_id": "maintainer alpha",
                "human_feedback": True,
                "feedback_text": feedback_text,
            }
        ],
        "maintainer_id must be a safe identifier",
    )
    expect_value_error(
        [
            {
                "case_id": "case-001",
                "maintainer_id": "maintainer-alpha",
                "human_feedback": True,
                "feedback_text": "placeholder",
            }
        ],
        "feedback_text must not be example/placeholder",
    )
    expect_value_error(
        [
            {
                "case_id": "case-001",
                "maintainer_id": "maintainer-alpha",
                "human_feedback": True,
                "feedback_text": feedback_text,
                "feedback_text_sha256": feedback_text,
            }
        ],
        "feedback_text_sha256 must be sha256:<64 hex>",
    )
    expect_value_error(
        [
            {
                "case_id": "case-001",
                "maintainer_id": "maintainer-alpha",
                "human_feedback": True,
                "feedback_text": feedback_text,
                "feedback_text_sha256": "sha256:" + ("0" * 64),
            }
        ],
        "feedback_text_sha256 must match feedback_text",
    )

    print("audit_my_repo_benchmark maintainer feedback smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
