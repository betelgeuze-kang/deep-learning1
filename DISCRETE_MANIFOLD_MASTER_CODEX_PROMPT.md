# Master Codex Prompt — Discrete Local-Energy Architecture

You are implementing a research prototype for a new discrete local-energy learning substrate.

This project is not a Transformer clone.
This project is not yet a full language model.
This project is not a GPU-first performance implementation.

The goal is to build a staged, testable, deterministic C++17 reference implementation of a bounded-degree discrete-state graph dynamics system that can later be extended toward sparse routing, online learning, and long-context retrieval.

The core implementation philosophy is:

1. Keep every operation local unless a stage explicitly introduces sparse long-range routing.
2. Preserve bounded-degree updates.
3. Preserve constant-size per-node state.
4. Separate inference dynamics from learning updates.
5. Add exactly one new capability per milestone.
6. Log enough metrics to tell whether failure comes from dynamics, learning, or routing.
7. Never claim Transformer-level capability until the relevant benchmark exists.
8. Prefer correctness and diagnostics over speed.
9. Prefer simple tables and explicit state transitions over deep abstractions.
10. Keep every version reproducible with a fixed RNG seed.

---

## 0. Repository Name

Create a repository:

```text
discrete-local-energy/
```

Executable names:

```text
dmv01
dmv02
```

The project should support multiple staged experiments in one codebase.

---

## 1. Repository Structure

Create the following structure:

```text
discrete-local-energy/
  CMakeLists.txt
  README.md
  docs/
    ARCHITECTURE_PLAN_A_TO_Z.md
    DESIGN_V01.md
    DESIGN_V02_PRE.md
    ROADMAP.md
    EXPERIMENTS.md
  src/
    common/
      Params.hpp
      RNG.hpp
      Metrics.hpp
      CSVLogger.hpp
      CLI.hpp
    v01/
      main_v01.cpp
      NodeV01.hpp
      GraphV01.hpp
      GraphV01.cpp
      OptimizerV01.hpp
      OptimizerV01.cpp
    v02_pre/
      main_v02.cpp
      NodeV02.hpp
      GraphV02.hpp
      GraphV02.cpp
      FieldTable.hpp
      FieldTable.cpp
      ByteDataset.hpp
      ByteDataset.cpp
      OptimizerV02.hpp
      OptimizerV02.cpp
  experiments/
    run_v01_smoke.sh
    run_v02_counter.sh
    run_v02_ablation.sh
  results/
    .gitkeep
```

No external dependencies except the C++17 standard library.

---

## 2. Build

Use CMake and C++17.

Required commands:

```bash
cmake -S . -B build
cmake --build build -j
```

Build two executables:

```bash
./build/dmv01
./build/dmv02
```

---

## 3. Version Discipline

Implement in staged order.

### v0.1

Purpose:

```text
Validate fixed local discrete dynamics.
```

Includes:

- single-channel or simple discrete state,
- fixed synthetic per-node h_table,
- local energy relaxation,
- greedy + stagnation-triggered uphill acceptance,
- reservoir redistribution,
- tick gating,
- tick relaxation,
- bounded-degree ring graph,
- color-based block-asynchronous schedule.

Excludes:

- learning,
- byte input/output,
- shared field table,
- sparse routing,
- GPU.

### v0.2-pre

Purpose:

```text
Validate minimal learnable shared local field on byte-level next-byte prediction.
```

Includes:

- byte sequence dataset,
- two-channel nibble state,
- fixed decoder,
- positive state from next byte,
- negative state from relaxed state,
- shared local field H[channel][input_byte][state],
- contrastive local field learning,
- oracle1 baseline,
- field-only accuracy,
- field margin.

Excludes:

- sparse routing,
- LSH,
- memory slots,
- channel coupling,
- pairwise compatibility table,
- RL,
- eligibility traces,
- GPU.

### v0.2-b, future

Purpose:

```text
Add intra-node channel coupling B[x, high, low].
```

Do not implement unless v0.2-pre diagnostics pass.

### v0.3, future

Purpose:

```text
Add sparse long-range routing through O(1) candidate sets.
```

Do not implement until local code space is meaningful.

---

# PART A — v0.1 Implementation

## A1. v0.1 Graph

Use 1D ring.

Default:

```cpp
N = 1000
R = 4
K = 8
C_colors = 9
```

Neighbors:

```text
i-4, i-3, i-2, i-1, i+1, i+2, i+3, i+4 mod N
```

Color:

```text
color(i) = i % 9
```

Schedule:

```cpp
for cycle in cycles:
  for color in 0..8:
    for i in 0..N-1:
      if i % 9 == color:
        update_node(i)
  relax_tick_and_reservoir()
  update_age()
  log_metrics()
```

## A2. v0.1 Node

```cpp
struct NodeV01 {
    uint8_t state;
    float mass;
    float reservoir;
    float tick;
    uint8_t age_since_change;
    std::array<int, 8> neighbors;
    std::array<float, 16> h_table;
};
```

## A3. v0.1 Parameters

```cpp
int N = 1000;
int S = 16;
int R = 4;
int K = 8;
int C_colors = 9;
int cycles = 1000;
int seed = 1;

float lambda_u = 1.0f;
float lambda_v = 0.25f;
float lambda_m = 0.05f;

float eta_r = 0.10f;
float eta_tau = 0.25f;
float tau_max = 4.0f;
float tau_decay = 0.05f;
float reservoir_decay = 0.01f;

float T0 = 0.0f;
float alpha_T = 0.20f;
float eps_T = 1e-6f;

int stagnation_window = 8;
int stagnation_threshold = 2;
int proposal_count = 4;
```

Support CLI overrides for all important parameters.

## A4. v0.1 Energy

```math
E_i =
-\lambda_u h_i[s_i]
+
\lambda_v \sum_{j\in N(i)} 1[s_i \ne s_j]
```

Reported total energy:

```math
H =
\sum_i -\lambda_u h_i[s_i]
+
0.5\lambda_v
\sum_i \sum_{j\in N(i)} 1[s_i \ne s_j]
```

## A5. v0.1 Delta

```math
\Delta E =
-\lambda_u(h_i[s']-h_i[s])
+
\lambda_v\sum_{j\in N(i)}
(1[s'\ne s_j]-1[s\ne s_j])
```

```math
\Delta E^{eff}=\Delta E+\lambda_m m_i
```

## A6. v0.1 Acceptance

Tick gate:

```math
P_try = min(1, 1/tick_i)
```

Stagnation:

```math
D_i=\sum_j 1[s_i\ne s_j]
```

```text
stag = age_since_change >= W && D_i >= delta_stag
```

Temperature:

```math
T_i=T0+\alpha_T |r_i|/(tick_i+eps)
```

Acceptance:

```text
if DeltaEeff <= 0:
    accept downhill
else if stag:
    accept with probability exp(-DeltaEeff/(T_i+eps))
else:
    reject
```

Accepted update:

```cpp
state = proposed_state;
q = DeltaEeff;
for neighbor j:
    reservoir[j] += eta_r * q / K;
tick = min(tau_max, tick + eta_tau * abs(q));
changed_this_cycle[i] = true;
```

End-of-cycle:

```cpp
tick = max(1.0f, (1 - tau_decay) * tick + tau_decay);
reservoir = (1 - reservoir_decay) * reservoir;
age_since_change = changed ? 0 : min(255, age_since_change + 1);
```

## A7. v0.1 Logging

CSV header:

```csv
cycle,H,mean_disagreement,mean_tick,mean_abs_reservoir,changed,downhill_accepts,uphill_accepts,rejected,skipped
```

---

# PART B — v0.2-pre Implementation

## B1. Purpose

v0.2-pre introduces a real input/output interface and minimal contrastive learning.

Task:

```text
byte-level next-byte prediction
```

For each position:

```text
input byte x_i
target byte y_i = x_{i+1}
```

State:

```text
state[0] = high nibble
state[1] = low nibble
```

Decoded output:

```cpp
predicted_byte = 16 * state[0] + state[1];
```

Positive state:

```cpp
positive[0] = target_byte / 16;
positive[1] = target_byte % 16;
```

Negative state:

```cpp
negative = relaxed node state after T cycles;
```

Learned table:

```cpp
H[channel][input_byte][state]
```

## B2. v0.2 Node

```cpp
struct NodeV02 {
    std::array<uint8_t, 2> state;

    uint8_t x_byte;
    uint8_t target_byte;

    float mass;
    float reservoir;
    float tick;

    uint8_t age_since_change;

    std::array<int, 8> neighbors;
};
```

Do not store per-node h_table.

## B3. FieldTable

```cpp
class FieldTable {
public:
    static constexpr int Channels = 2;
    static constexpr int ByteValues = 256;
    static constexpr int States = 16;

    float H[Channels][ByteValues][States];

    void initialize(std::mt19937& rng); // uniform(-0.01, 0.01)
    float score(int ch, uint8_t x, uint8_t state) const;
    void add(int ch, uint8_t x, uint8_t state, float delta);
    void decay(float eta_h, float lambda_h);
    void clip(float H_clip);

    int argmax_state(int ch, uint8_t x) const;
    float positive_margin(int ch, uint8_t x, uint8_t positive_state) const;
};
```

## B4. v0.2 Parameters

```cpp
int N = 256;
int S = 16;
int channels = 2;

int R = 4;
int K = 8;
int C_colors = 9;

int epochs = 300;
int cycles_per_epoch = 20;
int seed = 1;

std::string dataset = "counter";
std::string input_path = "";

float lambda_u = 1.0f;
float lambda_v = 0.0f; // default zero for first validation
float lambda_m = 0.05f;

float eta_r = 0.10f;
float eta_tau = 0.25f;
float tau_max = 4.0f;
float tau_decay = 0.05f;
float reservoir_decay = 0.01f;

float T0 = 0.0f;
float alpha_T = 0.20f;
float eps_T = 1e-6f;

int stagnation_window = 8;
int stagnation_threshold = 2;
int proposal_count = 4;

float eta_h = 0.05f;
float lambda_h = 1e-4f;
float H_clip = 8.0f;
```

## B5. Dataset

Implement `ByteDataset`.

Datasets:

### counter

```cpp
data[t] = uint8_t(t % 256);
```

This tests:

```text
x -> x+1 mod 256
```

### repeating-text

Use built-in repeated text:

```text
"the quick brown fox jumps over the lazy dog. "
```

### input file

If `--input path` is provided, read bytes as unsigned bytes.

If shorter than `N+1`, repeat cyclically.

Window for epoch `e`:

```cpp
offset = (e * N) % data.size();

x_i = data[(offset + i) % data.size()];
y_i = data[(offset + i + 1) % data.size()];
```

## B6. Oracle1 Baseline

Compute full-dataset transition counts:

```cpp
count[256][256]
```

For all transitions:

```cpp
count[data[t]][data[(t+1)%size]]++;
```

Then:

```cpp
oracle_next[x] = argmax_y count[x][y];
```

During an epoch:

```cpp
oracle1_acc = mean(oracle_next[x_i] == target_byte_i);
```

## B7. v0.2 Energy

```math
E_i =
-\lambda_u \sum_c H_c[x_i, s_i^c]
+
\lambda_v \sum_{j\in N(i)}\sum_c 1[s_i^c\ne s_j^c]
```

Reported total energy:

```math
H =
\sum_i -\lambda_u \sum_c H_c[x_i,s_i^c]
+
0.5\lambda_v
\sum_i \sum_{j\in N(i)} \sum_c 1[s_i^c\ne s_j^c]
```

## B8. v0.2 Proposal and Delta

A proposal changes one channel.

```text
choose random channel c in {0,1}
choose random new state a_new != state[c]
```

Delta:

```math
\Delta E =
-\lambda_u(H_c[x_i,a_new]-H_c[x_i,a_old])
+
\lambda_v \sum_{j\in N(i)}
(1[a_new\ne s_j^c]-1[a_old\ne s_j^c])
```

```math
\Delta E^{eff}=\Delta E+\lambda_m m_i
```

Sample `proposal_count` candidates and select lowest DeltaEeff.

## B9. v0.2 Acceptance

Same as v0.1, but disagreement sums over both channels.

```math
D_i=\sum_{j\in N(i)}\sum_c 1[s_i^c\ne s_j^c]
```

## B10. v0.2 Contrastive Learning

After all relaxation cycles in an epoch:

For every node and channel:

```cpp
pos = positive_state(i, ch);
neg = node.state[ch];
x = node.x_byte;

if (pos != neg) {
    field.add(ch, x, pos, +eta_h);
    field.add(ch, x, neg, -eta_h);
}
```

Then:

```cpp
field.decay(eta_h, lambda_h);
field.clip(H_clip);
```

This is not backprop.
This is not RL.
This is local contrastive energy learning.

## B11. v0.2 Metrics

CSV header:

```csv
epoch,H,byte_acc,field_byte_acc,oracle1_acc,ch0_acc,ch1_acc,field_ch0_acc,field_ch1_acc,field_margin,mean_disagreement,mean_tick,mean_abs_reservoir,changed,downhill_accepts,uphill_accepts,rejected,skipped
```

Definitions:

- `byte_acc`: decoded relaxed-state accuracy.
- `field_byte_acc`: field-only prediction accuracy.
- `oracle1_acc`: current-byte-only oracle accuracy.
- `field_margin`: average positive state margin in H.
- `changed`: accepted changes across the epoch.
- `downhill_accepts`, `uphill_accepts`, `rejected`, `skipped`: totals over all cycles in the epoch.

## B12. v0.2 Evaluation Rule

Do not judge only by byte_acc.

Correct diagnostic order:

```text
field_margin -> field_byte_acc -> byte_acc
```

Interpretation:

- If field_margin rises, H is learning.
- If field_byte_acc rises, H can predict target code.
- If byte_acc lags, dynamics needs tuning.
- If field metrics do not rise under lambda_v=0, the learning rule or data loop is wrong.

---

# PART C — Required Experiments

## C1. v0.1 Smoke Test

```bash
./build/dmv01 --N 32 --cycles 100 --seed 1 > results/v01_N32.csv
./build/dmv01 --N 128 --cycles 300 --seed 1 > results/v01_N128.csv
./build/dmv01 --N 1000 --cycles 1000 --seed 1 > results/v01_N1000.csv
```

Expected:

- H generally trends downward but not necessarily monotonic.
- mean_tick bounded.
- mean_abs_reservoir bounded.
- changed decreases as system settles.

## C2. v0.2-pre Counter Ablation

```bash
./build/dmv02 --dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --seed 1 --lambda-v 0 > results/counter_lv0.csv
./build/dmv02 --dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --seed 1 --lambda-v 0.05 > results/counter_lv005.csv
./build/dmv02 --dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --seed 1 --lambda-v 0.25 > results/counter_lv025.csv
```

Interpretation:

- `lambda_v=0` must succeed first.
- If `lambda_v=0` fails, debug data loop or contrastive update.
- If `lambda_v=0` succeeds and `0.25` fails, neighbor smoothing conflicts with counter.

## C3. v0.2-pre Repeating Text

```bash
./build/dmv02 --dataset repeating-text --N 256 --epochs 300 --cycles-per-epoch 20 --seed 1 --lambda-v 0 > results/text_lv0.csv
```

Interpret relative to oracle1_acc.

Success:

```text
field_byte_acc approaches oracle1_acc
```

---

# PART D — Future Versions

Do not implement future versions until earlier diagnostics pass.

## D1. v0.2-b: Intra-node Channel Coupling

Add:

```cpp
B[input_byte][high_state][low_state]
```

Energy:

```math
E_i^{intra}=-\lambda_b B[x_i,s_i^0,s_i^1]
```

Contrastive update:

```cpp
B[x][pos_hi][pos_lo] += eta_b;
B[x][neg_hi][neg_lo] -= eta_b;
```

Purpose:

```text
Learn high-low nibble dependency.
```

## D2. v0.3: Sparse Relation Routing

Only after meaningful state codes exist.

Neighbor set becomes:

```math
N(i)=N_local(i)\cup N_jump(i)
```

Constraints:

```text
|N_jump(i)| <= K_jump
K_total = K_local + K_jump = constant
```

Candidate sources:

- LSH buckets,
- memory slots,
- learned edge scores.

Important:

```text
Never scan all nodes to find a jump target.
```

## D3. v0.4: Routing Plasticity

For a jump edge `(i,j)`, define local advantage:

```math
A_{ij}=E_before(block_i)-E_after(block_i)-cost(i,j)
```

Update edge score:

```math
g_{ij}\leftarrow (1-\lambda_g)g_{ij}+\eta_g A_{ij}
```

## D4. v0.5: Continual Learning

Benchmark:

```text
Task A -> Task B -> Task A
```

Measure:

- new-task adaptation speed,
- old-task retention,
- forgetting score,
- updates per example,
- energy per correct prediction.

---

# PART E — Safety Against Overclaiming

Do not write that this implementation:

- beats Transformers,
- solves long-context language modeling,
- has infinite context,
- has total O(1) memory,
- is AGI,
- is post-backprop proof.

Correct claims for current stages:

### v0.1

```text
A bounded-degree discrete local energy dynamics reference implementation.
```

### v0.2-pre

```text
A minimal local contrastive learning loop for byte-level next-byte prediction.
```

### Future sparse-routing stage

```text
A testbed for O(1)-candidate long-range retrieval without dense attention.
```

---

# PART F — Final Deliverables

After implementation, provide:

1. build success,
2. v0.1 smoke CSVs,
3. v0.2 counter ablation CSVs,
4. v0.2 repeating-text CSV,
5. short summary of:
   - whether field_margin rose,
   - whether field_byte_acc rose,
   - whether byte_acc rose,
   - whether lambda_v interfered,
   - whether tick/reservoir stayed bounded.

Prioritize deterministic correctness over optimization.
