from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Protocol


@dataclass(frozen=True)
class Query:
    query_id: str
    sanitized_question: str
    corpus_snapshot_sha256: str
    context_budget: int
    retrieval_budget: int


@dataclass(frozen=True)
class RunResult:
    system_id: str
    query_id: str
    raw_answer: str
    raw_citation: str
    abstained: bool
    latency_ns: int
    peak_memory_mb: int
    prompt_sha256: str
    output_sha256: str


class BaselineAdapter(Protocol):
    system_id: str

    def run(self, query: Query) -> RunResult:
        ...


def execute_frozen_benchmark(adapter: BaselineAdapter, queries: Iterable[Query]) -> list[RunResult]:
    return [adapter.run(query) for query in queries]


def quality_score(row: dict[str, float]) -> float:
    return (
        0.35 * row["answer_accuracy"]
        + 0.25 * row["citation_correctness"]
        + 0.20 * row["unsupported_abstention_accuracy"]
        + 0.10 * row["source_span_exactness"]
        + 0.10 * row["replayability"]
        - 0.50 * row["wrong_answer_rate"]
    )
