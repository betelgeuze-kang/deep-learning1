# v0.1 Design Notes

`v0.1` is the fixed local-dynamics validation stage.

Implemented choices:

- graph: 1D ring with bounded degree `K = 2R`, capped at the reference maximum `8`
- node state: single discrete state `s_i in {0, ..., S-1}` with `S <= 16`
- score table: deterministic synthetic per-node `h_table`, initialized from `U[-1, 1]`
- inertia: per-node `mass` defaults to a constant `1.0`
- proposals: sample up to `proposal_count` alternative states and pick the lowest `DeltaEeff`
- schedule: color-based block-asynchronous sweep with `C_colors > 2R`
- diagnostics: raw mean disagreement count per node, mean tick, mean absolute reservoir, and transition counters

Deliberate constraints:

- single-threaded reference code
- no learning
- no byte interface
- no sparse routing

The implementation optimizes for reproducibility and observability over speed.
