# v0.2-pre Design Notes

This stage is now implemented as `dmv02` and treated as the locked baseline for the next milestone.

`v0.2-b` is next, but only after the current diagnostics stay healthy.

Implemented choices:

- byte-level next-byte prediction
- two-channel nibble state
- shared local field `H[channel][input_byte][state]`
- contrastive positive/negative updates
- diagnostics including `oracle1_acc`, `field_byte_acc`, and `field_margin`

Reference behavior:

- each epoch resets node state from the current input byte window
- relaxation produces the negative state
- learning updates only the shared field table
- `counter` with `lambda_v = 0` is the first correctness gate
- higher `lambda_v` values should hurt `counter`, not rescue it
- default `mass_init = 0` keeps the first field-learning check from being blocked by inertia
- `repeating-text` should keep `field_byte_acc` below `oracle1_acc` but above `byte_acc` early and mid training
- a representative `text_lv0.csv` ends near `field_margin = 3.682054`, `field_byte_acc = 0.644531`, `byte_acc = 0.484375`, and `oracle1_acc ≈ 0.703125`
- `proposal_count` is still a useful tuning knob in `v0.2-b`, but the current block-local coupled proposal path now keeps the default weak-coupling run healthy on `counter`
- the main `v0.2-b` isolation test is still tuned no-coupling control vs tuned weak coupling on repeating text
