# v0.2-b Decision Boundary

This note separates two effects that were easy to blur together:

- the block-local coupled proposal fixes the old dynamics problem in the default weak-coupling run.
- weak coupling helps text once the dynamics are fixed.

See the longer run log in [V02B_RESULTS.md](V02B_RESULTS.md).

## Compact Comparison

| Setup | Counter 5-seed last10 mean | Repeating-text 5-seed last10 mean | Read |
| --- | --- | --- | --- |
| Default `v0.2-b` weak coupling | `field_byte_acc=1.000000`, `joint_byte_acc=1.000000`, `byte_acc=0.999688` | `field_byte_acc=0.681094`, `joint_byte_acc=0.685703`, `byte_acc=0.685625` | Shipped default weak coupling now passes both checks across five seeds.
| Default no coupling | `field_byte_acc=1.000000`, `joint_byte_acc=1.000000`, `byte_acc=0.934375` | `field_byte_acc=0.659453`, `joint_byte_acc=0.659453`, `byte_acc=0.508047` | Useful default-path comparison, but not the stage we want to ship.
| Tuned no-coupling (`proposal_count=30`) | `field_byte_acc=1.000000`, `joint_byte_acc=1.000000`, `byte_acc=1.000000` | `field_byte_acc=0.597656`, `joint_byte_acc=0.597656`, `byte_acc=0.597656` | Proposal tuning isolates coverage without adding coupling.
| Tuned weak coupling (`proposal_count=30`) | `field_byte_acc=1.000000`, `joint_byte_acc=1.000000`, `byte_acc=1.000000` | `field_byte_acc=0.687500`, `joint_byte_acc=0.687500`, `byte_acc=0.687500` | Coupling still adds a real text gain in the isolation control.

## What Changed

The pair proposal changed the default search dynamics without touching the uncoupled path. The default weak-coupling run now reaches the same stable `counter` endpoint that previously required `proposal_count=30`, and it does so across five seeds.

Coupling changed the text outcome after the dynamics were fixed. On repeating text, weak coupling lifts the default-path 5-seed average `byte_acc` from `0.508047` to `0.685625`, and it also lifts the tuned no-coupling endpoint from `0.597656` to `0.687500`.

## Decision Line

Use the current default weak-coupling implementation as the main `v0.2-b` path. Keep the tuned `proposal_count=30` scripts around as a control when you want to isolate coupling benefit from proposal coverage. Treat the default 5-seed regression, not the tuned control, as the main go/no-go boundary before any sparse-routing work.
