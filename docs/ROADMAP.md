# Roadmap

Execution order:

1. `v0.1` implementation
2. `v0.1` smoke test
3. `v0.2-pre` implementation
4. counter dataset with `lambda_v = 0`
5. `lambda_v` ablation
6. repeating-text plus `oracle1` comparison
7. `field_margin -> field_byte_acc -> byte_acc` curve check
8. `v0.2-b` only after diagnostics pass
9. sparse routing after local code space is meaningful

Positioning:

- not a "Transformer killer"
- yes to a backprop-free local-energy substrate for linear-time online adaptation
- use `O(1)` per token with fixed local state and bounded degree
- use `O(N)` with respect to active stream length
