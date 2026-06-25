#!/usr/bin/env python3
"""v58 blind evaluation staging helper: blinding, reviewer assignment, kappa.

Four return-side staging utilities for the v58 real blind evaluation:

    blind-map         derive HMAC blind_system_id / blind_response_id from a
                      per-eval secret, emit a PUBLIC blind-response template
                      (no source identity) and SECRET key files kept separate.
    reviewer-registry validate reviewer-pool registry integrity and assign two
                      independent reviewers from distinct pools per response.
    completeness      verify assignment/review binding, fail closed unless every
                      response has its two assigned reviews, and validate that
                      review values are in the allowed vocabulary.
    kappa             compute Cohen's kappa per review metric from filled human
                      review rows and list disagreements needing adjudication.

Column source of truth: ``v58/blind_eval_real.json`` (read at runtime), so the
templates cannot drift from the contract.

Boundary: this tool admits NOTHING and flips no readiness flag. It does not
itself perform blind review. Real acceptance still runs through
``experiments/test_v58c_blind_response_evidence_intake.sh`` and
``experiments/test_v58d_blind_review_return_intake.sh``. Synthetic rows are for
schema testing only and must never be promoted to real blind evidence. The
unblinding key must NOT be shared with reviewers until adjudication finishes.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import hmac
import json
import secrets
import sys
from pathlib import Path

DEFAULT_CONTRACT = "v58/blind_eval_real.json"
KAPPA_METRICS = [
    "answer_correctness",
    "citation_correctness",
    "abstain_correctness",
    "source_span_exactness",
    "unsupported_abstention_correctness",
    "review_decision",
]
BOOL_TRUE = {"1", "true", "yes"}
BOOL_FALSE = {"0", "false", "no"}
ALLOWED_REVIEW_VALUES = {
    "answer_correctness": {"correct", "incorrect", "partial", "not_applicable"},
    "citation_correctness": {"correct", "incorrect", "partial", "not_applicable"},
    "abstain_correctness": {"correct", "incorrect", "not_applicable"},
    "source_span_exactness": {"exact", "partial", "wrong", "not_applicable"},
    "unsupported_abstention_correctness": {"correct", "incorrect", "not_applicable"},
    "review_decision": {"accept", "reject", "revise"},
}


def _hmac_id(secret: str, message: str, hex_len: int) -> str:
    digest = hmac.new(secret.encode("utf-8"), message.encode("utf-8"), hashlib.sha256).hexdigest()
    return digest[:hex_len]


def load_contract(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema_version") != "v58_blind_eval.v1":
        raise SystemExit(f"{path}: unexpected schema_version")
    return data


def artifact(contract: dict, artifact_id: str) -> dict:
    for entry in contract.get("required_artifacts", []):
        if entry["artifact_id"] == artifact_id:
            return entry
    raise SystemExit(f"contract missing artifact {artifact_id}")


def write_csv(path: Path, header: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_rows(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


# --------------------------------------------------------------------------- #
# blind-map
# --------------------------------------------------------------------------- #
def cmd_blind_map(args: argparse.Namespace) -> int:
    contract = load_contract(Path(args.contract))
    systems = args.systems.split(",") if args.systems else list(contract["required_systems"])
    response_columns = artifact(contract, "v58-blind-response-rows")["required_columns"]
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    blind_eval_id = args.blind_eval_id

    # Per-eval HMAC secret. Blind ids are unguessable without it; only the
    # holder of the secret (via the secret key file) can unblind.
    secret = args.secret or secrets.token_hex(32)
    mapping = {source: "s" + _hmac_id(secret, f"system|{blind_eval_id}|{source}", 12) for source in systems}
    if len(set(mapping.values())) != len(systems):
        raise SystemExit("HMAC blind-system-id collision; choose a different secret/blind_eval_id")

    # SECRET artifacts (do NOT share with reviewers until adjudication finishes).
    write_csv(
        out / "SECRET_unblinding_key.csv",
        ["source_system_id", "blind_system_id", "blind_eval_id"],
        [
            {"source_system_id": s, "blind_system_id": mapping[s], "blind_eval_id": blind_eval_id}
            for s in systems
        ],
    )
    (out / "SECRET_hmac_key.txt").write_text(secret + "\n", encoding="utf-8")

    # PUBLIC blind-response template: blind ids only, no source identity.
    rows: list[dict] = []
    for source_system in systems:
        blind_system_id = mapping[source_system]
        for query_index in range(1, args.queries_per_system + 1):
            query_token = f"q{query_index:06d}"
            row = {col: "" for col in response_columns}
            row["blind_response_id"] = "r" + _hmac_id(
                secret, f"response|{blind_eval_id}|{source_system}|{query_token}", 16
            )
            if "blind_eval_id" in row:
                row["blind_eval_id"] = blind_eval_id
            row["blind_system_id"] = blind_system_id
            if "query_id" in row:
                row["query_id"] = query_token
            rows.append(row)

    # Fail closed if any source identity leaked into the public rows.
    leaks = _source_leaks(rows, systems, mapping)
    if leaks:
        raise SystemExit(f"source identity leaked into public blind rows: {sorted(leaks)}")
    if "source_system_id" in response_columns:
        raise SystemExit("public blind-response columns must not include source_system_id")
    if len({row["blind_response_id"] for row in rows}) != len(rows):
        raise SystemExit("HMAC blind-response-id collision; choose a different secret/blind_eval_id")

    write_csv(out / "public_blind_response_template.csv", response_columns, rows)

    print(
        f"wrote HMAC blind map to {out}: {len(systems)} systems, {len(rows)} blind responses. "
        f"SECRET_unblinding_key.csv + SECRET_hmac_key.txt are secret; "
        f"public_blind_response_template.csv carries no source identity."
    )
    return 0


def _source_leaks(rows: list[dict], systems: list[str], mapping: dict[str, str]) -> set[str]:
    """Return source system ids that appear verbatim in any public cell."""
    blind_values = set(mapping.values())
    leaks: set[str] = set()
    source_tokens = {s for s in systems if s not in blind_values}
    for row in rows:
        for value in row.values():
            text = str(value)
            for source in source_tokens:
                # whole-token match to avoid false hits inside hashes
                if source and (text == source or f"|{source}|" in f"|{text}|"):
                    leaks.add(source)
    return leaks


# --------------------------------------------------------------------------- #
# reviewer-registry
# --------------------------------------------------------------------------- #
REGISTRY_COLUMNS = ["reviewer_id", "reviewer_pool_id", "reviewer_independent", "conflict_disclosed"]
ASSIGNMENT_COLUMNS = ["blind_response_id", "reviewer_id", "reviewer_pool_id"]


def _validate_registry(reviewers: list[dict], errors: list[str]) -> list[dict]:
    """Integrity + allowed-value validation; returns assignment-eligible reviewers."""
    seen_ids: set[str] = set()
    eligible: list[dict] = []
    for index, reviewer in enumerate(reviewers, start=1):
        rid = (reviewer.get("reviewer_id") or "").strip()
        pool = (reviewer.get("reviewer_pool_id") or "").strip()
        independent = (reviewer.get("reviewer_independent") or "").strip().lower()
        disclosed = (reviewer.get("conflict_disclosed") or "").strip().lower()
        if not rid:
            errors.append(f"registry row {index}: reviewer_id is empty")
            continue
        if rid in seen_ids:
            errors.append(f"registry: duplicate reviewer_id {rid!r}")
        seen_ids.add(rid)
        if not pool:
            errors.append(f"registry {rid}: reviewer_pool_id is empty")
        if independent not in BOOL_TRUE | BOOL_FALSE:
            errors.append(f"registry {rid}: reviewer_independent must be boolean, got {independent!r}")
        if disclosed not in BOOL_TRUE | BOOL_FALSE:
            errors.append(f"registry {rid}: conflict_disclosed must be boolean, got {disclosed!r}")
        if independent in BOOL_TRUE and disclosed in BOOL_TRUE and pool:
            eligible.append(reviewer)
    return eligible


def cmd_reviewer_registry(args: argparse.Namespace) -> int:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    errors: list[str] = []

    registry_path = Path(args.registry) if args.registry else out / "reviewer_pool_registry.csv"
    if args.registry:
        header, reviewers = read_rows(registry_path)
        if header != REGISTRY_COLUMNS:
            raise SystemExit(f"{registry_path}: registry columns must be exactly {REGISTRY_COLUMNS}")
    else:
        # Emit a small template registry (2 pools, schema test only).
        reviewers = [
            {"reviewer_id": "rev-a1", "reviewer_pool_id": "pool-alpha", "reviewer_independent": "true", "conflict_disclosed": "true"},
            {"reviewer_id": "rev-a2", "reviewer_pool_id": "pool-alpha", "reviewer_independent": "true", "conflict_disclosed": "true"},
            {"reviewer_id": "rev-b1", "reviewer_pool_id": "pool-beta", "reviewer_independent": "true", "conflict_disclosed": "true"},
            {"reviewer_id": "rev-b2", "reviewer_pool_id": "pool-beta", "reviewer_independent": "true", "conflict_disclosed": "true"},
        ]
        write_csv(registry_path, REGISTRY_COLUMNS, reviewers)

    eligible = _validate_registry(reviewers, errors)
    pools = sorted({r["reviewer_pool_id"] for r in eligible})
    if len(pools) < 2:
        errors.append("need independent, conflict-disclosed reviewers in at least 2 distinct pools")
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f"reviewer registry BLOCKED: {len(errors)} integrity issue(s)", file=sys.stderr)
        return 1

    # All cross-pool reviewer pairs, for round-robin assignment.
    pairs: list[tuple[dict, dict]] = []
    for i in range(len(eligible)):
        for j in range(i + 1, len(eligible)):
            if eligible[i]["reviewer_pool_id"] != eligible[j]["reviewer_pool_id"]:
                pairs.append((eligible[i], eligible[j]))
    if not pairs:
        print("no cross-pool reviewer pair available", file=sys.stderr)
        return 1

    _, response_rows = read_rows(Path(args.responses))
    assignment_rows: list[dict] = []
    for index, response in enumerate(response_rows):
        blind_response_id = response["blind_response_id"]
        rev_a, rev_b = pairs[index % len(pairs)]
        for reviewer in (rev_a, rev_b):
            assignment_rows.append(
                {
                    "blind_response_id": blind_response_id,
                    "reviewer_id": reviewer["reviewer_id"],
                    "reviewer_pool_id": reviewer["reviewer_pool_id"],
                }
            )
    write_csv(out / "review_assignment.csv", ASSIGNMENT_COLUMNS, assignment_rows)
    print(
        f"registry valid; assigned 2 independent cross-pool reviewers to {len(response_rows)} "
        f"responses ({len(pools)} pools, {len(pairs)} usable pairs)"
    )
    return 0


def cmd_completeness(args: argparse.Namespace) -> int:
    """Assignment/review binding + 2-review fail-closed + allowed-value validation."""
    _, assignment_rows = read_rows(Path(args.assignment))
    review_header, review_rows = read_rows(Path(args.reviews))
    errors: list[str] = []

    # Assigned reviewers per response (must be exactly 2, distinct, distinct pools).
    assigned: dict[str, list[tuple[str, str]]] = {}
    for row in assignment_rows:
        rid = (row.get("blind_response_id") or "").strip()
        assigned.setdefault(rid, []).append(
            ((row.get("reviewer_id") or "").strip(), (row.get("reviewer_pool_id") or "").strip())
        )
    assigned_pairs: set[tuple[str, str]] = set()
    for response_id, reviewers in assigned.items():
        ids = [r[0] for r in reviewers]
        pools = [r[1] for r in reviewers]
        if len(reviewers) != 2:
            errors.append(f"assignment {response_id}: must have exactly 2 reviewers, got {len(reviewers)}")
        if len(set(ids)) != len(ids):
            errors.append(f"assignment {response_id}: duplicate reviewer assigned")
        if len(set(pools)) < min(2, len(reviewers)):
            errors.append(f"assignment {response_id}: reviewers must be from distinct pools")
        for rid, _pool in reviewers:
            assigned_pairs.add((response_id, rid))

    # Reviews: allowed-value validation + binding to assignment.
    review_pairs: dict[str, set[str]] = {}
    for index, row in enumerate(review_rows, start=1):
        response_id = (row.get("blind_response_id") or "").strip()
        rid = (row.get("reviewer_id") or "").strip()
        review_pairs.setdefault(response_id, set()).add(rid)
        if (response_id, rid) not in assigned_pairs:
            errors.append(f"review row {index}: ({response_id}, {rid}) is not an assigned reviewer")
        for metric, allowed in ALLOWED_REVIEW_VALUES.items():
            if metric in review_header:
                value = (row.get(metric) or "").strip()
                if value and value not in allowed:
                    errors.append(f"review row {index}: {metric}={value!r} not in {sorted(allowed)}")

    # Every assigned response must have exactly 2 reviews from its assigned reviewers (fail closed).
    for response_id, reviewers in assigned.items():
        got = review_pairs.get(response_id, set())
        if got != {r[0] for r in reviewers}:
            errors.append(
                f"response {response_id}: expected reviews from {sorted({r[0] for r in reviewers})}, "
                f"got {sorted(got)}"
            )

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f"v58 review completeness BLOCKED: {len(errors)} issue(s)", file=sys.stderr)
        return 1
    print(
        f"v58 review completeness ok: {len(assigned)} responses, all 2-review, "
        "assignment/review binding consistent, allowed values valid."
    )
    return 0


# --------------------------------------------------------------------------- #
# kappa
# --------------------------------------------------------------------------- #
def cohens_kappa(pairs: list[tuple[str, str]]) -> tuple[float, float, float]:
    """Return (observed_agreement, expected_agreement, cohens_kappa)."""
    n = len(pairs)
    if n == 0:
        raise ValueError("no rater pairs")
    agree = sum(1 for a, b in pairs if a == b)
    po = agree / n
    categories = {label for pair in pairs for label in pair}
    pe = 0.0
    for category in categories:
        pa = sum(1 for a, _ in pairs if a == category) / n
        pb = sum(1 for _, b in pairs if b == category) / n
        pe += pa * pb
    if pe >= 1.0:
        return po, pe, (1.0 if po >= 1.0 else 0.0)
    return po, pe, (po - pe) / (1.0 - pe)


def cmd_kappa(args: argparse.Namespace) -> int:
    header, rows = read_rows(Path(args.reviews))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    by_response: dict[str, list[dict]] = {}
    for row in rows:
        by_response.setdefault(row["blind_response_id"], []).append(row)

    paired = {}
    skipped = 0
    for response_id, review_rows in by_response.items():
        if len(review_rows) != 2:
            skipped += 1
            continue
        review_rows.sort(key=lambda r: r.get("reviewer_id", ""))
        paired[response_id] = review_rows

    metrics = [m for m in KAPPA_METRICS if m in header]
    report_rows: list[dict] = []
    disagreement_rows: list[dict] = []
    for metric in metrics:
        pairs = [(rr[0].get(metric, ""), rr[1].get(metric, "")) for rr in paired.values()]
        if not pairs:
            continue
        po, pe, kappa = cohens_kappa(pairs)
        disagreements = sum(1 for a, b in pairs if a != b)
        report_rows.append(
            {
                "metric": metric,
                "n_responses": len(pairs),
                "observed_agreement": f"{po:.6f}",
                "expected_agreement": f"{pe:.6f}",
                "cohens_kappa": f"{kappa:.6f}",
                "disagreements": disagreements,
            }
        )
    for response_id, rr in paired.items():
        for metric in metrics:
            if rr[0].get(metric, "") != rr[1].get(metric, ""):
                disagreement_rows.append(
                    {
                        "blind_response_id": response_id,
                        "metric": metric,
                        "reviewer_a_id": rr[0].get("reviewer_id", ""),
                        "reviewer_b_id": rr[1].get("reviewer_id", ""),
                        "reviewer_a_value": rr[0].get(metric, ""),
                        "reviewer_b_value": rr[1].get(metric, ""),
                        "needs_adjudication": "1",
                    }
                )

    write_csv(
        out / "inter_rater_kappa_report.csv",
        ["metric", "n_responses", "observed_agreement", "expected_agreement", "cohens_kappa", "disagreements"],
        report_rows,
    )
    write_csv(
        out / "adjudication_queue_rows.csv",
        [
            "blind_response_id",
            "metric",
            "reviewer_a_id",
            "reviewer_b_id",
            "reviewer_a_value",
            "reviewer_b_value",
            "needs_adjudication",
        ],
        disagreement_rows,
    )
    print(
        f"kappa report: {len(report_rows)} metric(s) over {len(paired)} paired responses, "
        f"{len(disagreement_rows)} disagreement(s) queued for adjudication"
        + (f"; skipped {skipped} response(s) without exactly 2 reviews" if skipped else "")
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", default=DEFAULT_CONTRACT, help="v58 contract (column source of truth)")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_map = sub.add_parser("blind-map", help="blind systems and emit blind-response template + secret key")
    p_map.add_argument("--out", required=True)
    p_map.add_argument("--systems", default="", help="comma-separated source systems (default: contract)")
    p_map.add_argument("--queries-per-system", type=int, default=500)
    p_map.add_argument("--blind-eval-id", dest="blind_eval_id", default="v58eval001")
    p_map.add_argument("--seed", type=int, default=0)
    p_map.add_argument("--secret", default="", help="HMAC secret (hex); auto-generated if omitted")
    p_map.set_defaults(func=cmd_blind_map)

    p_reg = sub.add_parser("reviewer-registry", help="registry integrity + 2-independent-cross-pool assignment")
    p_reg.add_argument("--out", required=True)
    p_reg.add_argument("--responses", required=True, help="blind-response template csv")
    p_reg.add_argument("--registry", default="", help="existing registry CSV (omit to emit a template)")
    p_reg.set_defaults(func=cmd_reviewer_registry)

    p_done = sub.add_parser("completeness", help="assignment/review binding + 2-review fail-closed")
    p_done.add_argument("--assignment", required=True, help="review_assignment.csv")
    p_done.add_argument("--reviews", required=True, help="filled human-review rows CSV")
    p_done.set_defaults(func=cmd_completeness)

    p_kappa = sub.add_parser("kappa", help="Cohen's kappa report from filled human-review rows")
    p_kappa.add_argument("--reviews", required=True, help="v58-human-review-rows CSV")
    p_kappa.add_argument("--out", required=True)
    p_kappa.set_defaults(func=cmd_kappa)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
