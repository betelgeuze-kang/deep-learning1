#!/usr/bin/env python3
"""v58 blind evaluation staging helper: blinding, reviewer assignment, kappa.

Three return-side staging utilities for the v58 real blind evaluation:

    blind-map         assign blind_system_id / blind_response_id and emit a
                      blank blind-response template, plus a SECRET unblinding
                      key kept in a separate file.
    reviewer-registry build/validate a reviewer pool registry and assign two
                      independent reviewers from distinct pools per response.
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
import json
import random
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

    # Deterministic blinding: source system -> opaque blind id.
    rng = random.Random(args.seed)
    blind_labels = [f"S{index:02d}" for index in range(1, len(systems) + 1)]
    rng.shuffle(blind_labels)
    mapping = dict(zip(systems, blind_labels))

    # SECRET unblinding key (do not share with reviewers until adjudication).
    write_csv(
        out / "UNBLINDING_KEY.csv",
        ["source_system_id", "blind_system_id", "blind_eval_id"],
        [
            {"source_system_id": s, "blind_system_id": mapping[s], "blind_eval_id": blind_eval_id}
            for s in systems
        ],
    )

    # Blank blind-response template (response_text filled by the executor).
    rows: list[dict] = []
    running = 0
    for source_system in systems:
        blind_system_id = mapping[source_system]
        for query_index in range(1, args.queries_per_system + 1):
            running += 1
            row = {col: "" for col in response_columns}
            row["blind_response_id"] = f"{blind_eval_id}-r{running:06d}"
            if "blind_eval_id" in row:
                row["blind_eval_id"] = blind_eval_id
            row["blind_system_id"] = blind_system_id
            rows.append(row)
    write_csv(out / "blind_response_template.csv", response_columns, rows)

    print(
        f"wrote blind map to {out}: {len(systems)} systems blinded, "
        f"{len(rows)} blind responses (UNBLINDING_KEY.csv is secret)"
    )
    return 0


# --------------------------------------------------------------------------- #
# reviewer-registry
# --------------------------------------------------------------------------- #
REGISTRY_COLUMNS = ["reviewer_id", "reviewer_pool_id", "reviewer_independent", "conflict_disclosed"]
ASSIGNMENT_COLUMNS = ["blind_response_id", "reviewer_id", "reviewer_pool_id"]


def cmd_reviewer_registry(args: argparse.Namespace) -> int:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    registry_path = Path(args.registry) if args.registry else out / "reviewer_pool_registry.csv"
    if args.registry:
        header, reviewers = read_rows(registry_path)
        if set(header) != set(REGISTRY_COLUMNS):
            raise SystemExit(f"{registry_path}: registry columns must be {REGISTRY_COLUMNS}")
    else:
        # Emit a small template registry (2 pools, schema test only).
        reviewers = [
            {"reviewer_id": "rev-a1", "reviewer_pool_id": "pool-alpha", "reviewer_independent": "true", "conflict_disclosed": "true"},
            {"reviewer_id": "rev-a2", "reviewer_pool_id": "pool-alpha", "reviewer_independent": "true", "conflict_disclosed": "true"},
            {"reviewer_id": "rev-b1", "reviewer_pool_id": "pool-beta", "reviewer_independent": "true", "conflict_disclosed": "true"},
            {"reviewer_id": "rev-b2", "reviewer_pool_id": "pool-beta", "reviewer_independent": "true", "conflict_disclosed": "true"},
        ]
        write_csv(registry_path, REGISTRY_COLUMNS, reviewers)

    independent = [r for r in reviewers if (r.get("reviewer_independent") or "").lower() in {"1", "true", "yes"}]
    pools = sorted({r["reviewer_pool_id"] for r in independent})
    if len(pools) < 2:
        raise SystemExit("need independent reviewers in at least 2 distinct pools")

    # All cross-pool reviewer pairs, for round-robin assignment.
    pairs: list[tuple[dict, dict]] = []
    for i in range(len(independent)):
        for j in range(i + 1, len(independent)):
            if independent[i]["reviewer_pool_id"] != independent[j]["reviewer_pool_id"]:
                pairs.append((independent[i], independent[j]))
    if not pairs:
        raise SystemExit("no cross-pool reviewer pair available")

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
        f"assigned 2 independent cross-pool reviewers to {len(response_rows)} responses "
        f"({len(pools)} pools, {len(pairs)} usable pairs)"
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
    p_map.set_defaults(func=cmd_blind_map)

    p_reg = sub.add_parser("reviewer-registry", help="registry + 2-independent-cross-pool assignment")
    p_reg.add_argument("--out", required=True)
    p_reg.add_argument("--responses", required=True, help="blind_response_template.csv")
    p_reg.add_argument("--registry", default="", help="existing registry CSV (omit to emit a template)")
    p_reg.set_defaults(func=cmd_reviewer_registry)

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
