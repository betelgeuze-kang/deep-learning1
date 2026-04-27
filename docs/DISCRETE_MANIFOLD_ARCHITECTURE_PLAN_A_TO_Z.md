# Discrete Local-Energy Architecture — A to Z Implementation Plan

## 0. One-Sentence Thesis

We propose a discrete local-energy learning substrate that replaces global backpropagation and dense attention with bounded-degree state dynamics and local contrastive field updates, aiming for linear-time streaming adaptation.

Korean thesis:

> 우리는 역전파와 전역 어텐션 없이, bounded-degree 이산 상태 그래프의 국소 에너지 완화와 대조적 필드 업데이트만으로 스트리밍 데이터에 선형 시간으로 적응하는 학습 기판을 제안한다.

---

# 1. Core Implementation Philosophy

## 1.1 What This Architecture Is

This architecture is a staged research prototype for a new compute substrate.

It is:

- a bounded-degree graph of discrete state nodes,
- a local energy relaxation system,
- a contrastive local learning system,
- a future sparse routing and streaming adaptation substrate.

It is not initially:

- a Transformer replacement,
- a frontier LLM,
- a full world model,
- a GPU-optimized engine,
- an AGI system.

The first goal is to prove that the core dynamics and learning loop work at small scale.

---

## 1.2 Guiding Principles

### Principle 1 — Locality first

Every update must depend only on:

\[
i,\quad \mathcal{N}(i),\quad x_i,\quad \text{constant-size local state}
\]

unless a later stage explicitly introduces sparse routing.

### Principle 2 — Bounded degree

For every node:

\[
|\mathcal{N}(i)| \le K
\]

with fixed \(K\).

This is the foundation of linear-time scaling.

### Principle 3 — Constant per-node state

Each node stores a fixed-size state:

- discrete state channels,
- reservoir,
- tick,
- mass,
- age,
- input byte or local input code.

Per-node memory must not grow with context length.

### Principle 4 — Separate dynamics from learning

The architecture has two distinct processes:

1. **Inference / relaxation dynamics**  
   State evolves to reduce local energy.

2. **Learning update**  
   Shared tables are updated using positive/negative state statistics.

Do not mix them until each is individually validated.

### Principle 5 — One new capability per version

Each version should add exactly one major capability.

- v0.1: fixed local dynamics
- v0.2-pre: shared field learning
- v0.2-b: intra-node channel coupling
- v0.3: sparse routing
- v0.4: routing plasticity
- v0.5: continual learning

### Principle 6 — Diagnostics before claims

Every stage must log enough metrics to determine whether failure comes from:

- energy dynamics,
- proposal rule,
- tick/reservoir stabilization,
- learning rule,
- data interface,
- routing.

### Principle 7 — No premature Transformer claims

Do not claim that this architecture beats Transformers until it passes:

- long-context recall,
- online continual adaptation,
- cost/accuracy comparisons,
- scaling curves.

Current stages are substrate validation.

---

# 2. Architecture Overview

## 2.1 Graph Substrate

The system is defined on a graph:

\[
G=(V,E)
\]

Each node \(i\in V\) carries a discrete state.

In v0.1 and v0.2-pre, use a simple ring topology.

Radius:

\[
R=4
\]

Degree:

\[
K=8
\]

Neighbors:

\[
\mathcal{N}(i)
=
\{i-4,i-3,i-2,i-1,i+1,i+2,i+3,i+4\}\mod N
\]

This is not the final topology.  
It is a deterministic, debuggable testbed.

---

## 2.2 State Variables

### v0.1

Single discrete state:

\[
s_i\in\{0,\dots,15\}
\]

Node variables:

\[
X_i=(s_i,m_i,r_i,\tau_i,age_i,h_i)
\]

where:

- \(s_i\): state
- \(m_i\): mass / inertia prior
- \(r_i\): reservoir
- \(\tau_i\): tick / local relaxation scalar
- \(age_i\): cycles since last state change
- \(h_i\): fixed synthetic local score table

### v0.2-pre

Two-channel byte state:

\[
s_i=(s_i^{(0)},s_i^{(1)})
\]

with:

\[
s_i^{(c)}\in\{0,\dots,15\}
\]

The two channels decode to one byte:

\[
\hat{y}_i=16s_i^{(0)}+s_i^{(1)}
\]

Node variables:

\[
X_i=(s_i^{(0)},s_i^{(1)},x_i,y_i,m_i,r_i,\tau_i,age_i)
\]

The local field is no longer per-node.  
It is shared:

\[
H_c[x,a]
\]

---

# 3. v0.1 — Fixed Local Dynamics

## 3.1 Purpose

v0.1 answers:

> Can bounded-degree discrete local energy dynamics run stably and reduce energy without backpropagation?

It does not learn from data.

---

## 3.2 Energy

\[
E_i =
-\lambda_u h_i[s_i]
+
\lambda_v
\sum_{j\in\mathcal{N}(i)}
\mathbf{1}[s_i\ne s_j]
\]

Total reported energy:

\[
H=
\sum_i -\lambda_u h_i[s_i]
+
\frac{1}{2}\lambda_v
\sum_i\sum_{j\in\mathcal{N}(i)}
\mathbf{1}[s_i\ne s_j]
\]

---

## 3.3 Delta Energy

For proposal \(s_i\to s_i'\):

\[
\Delta E_i =
-\lambda_u(h_i[s_i']-h_i[s_i])
+
\lambda_v
\sum_{j\in\mathcal{N}(i)}
\left(
\mathbf{1}[s_i'\ne s_j]
-
\mathbf{1}[s_i\ne s_j]
\right)
\]

Add inertia:

\[
\Delta E_i^{eff}=\Delta E_i+\lambda_m m_i
\]

---

## 3.4 Tick Gating

\[
P_{try}(i)=\min(1,1/\tau_i)
\]

If the Bernoulli draw fails, node \(i\) skips update.

Purpose:

- avoid priority queues,
- reduce oscillation,
- preserve local scheduling.

---

## 3.5 Stagnation

\[
D_i=\sum_{j\in\mathcal{N}(i)}\mathbf{1}[s_i\ne s_j]
\]

\[
stag_i = \mathbf{1}[age_i\ge W]\mathbf{1}[D_i\ge \delta_{stag}]
\]

Only stagnant nodes may accept uphill moves.

---

## 3.6 Local Temperature

\[
T_i=T_0+\alpha_T\frac{|r_i|}{\tau_i+\epsilon}
\]

Interpretation:

- reservoir increases local stochasticity,
- tick suppresses repeated jumps.

---

## 3.7 Acceptance

\[
\Delta E_i^{eff}\le 0
\Rightarrow accept
\]

If:

\[
\Delta E_i^{eff}>0
\]

then:

\[
P_{acc}=
\exp
\left(
-\frac{\Delta E_i^{eff}}{T_i+\epsilon}
\right)
\]

but only when \(stag_i=1\).

This gives:

> Greedy by default, stochastic only under local stagnation.

---

## 3.8 Accepted Update

If accepted:

\[
s_i\leftarrow s_i'
\]

\[
q_i=\Delta E_i^{eff}
\]

Reservoir redistribution:

\[
r_j\leftarrow r_j+\frac{\eta_r q_i}{K}
\quad \forall j\in\mathcal{N}(i)
\]

Tick increase:

\[
\tau_i\leftarrow
\min(\tau_{max},\tau_i+\eta_\tau|q_i|)
\]

---

## 3.9 End-of-cycle Relaxation

\[
\tau_i\leftarrow
\max(1,(1-\lambda_\tau^{decay})\tau_i+\lambda_\tau^{decay})
\]

\[
r_i\leftarrow(1-\lambda_r^{decay})r_i
\]

Age:

\[
age_i=
\begin{cases}
0 & \text{if changed}\\
\min(255,age_i+1) & \text{otherwise}
\end{cases}
\]

---

## 3.10 v0.1 Success Criteria

v0.1 succeeds if:

- energy generally trends downward,
- tick remains bounded,
- reservoir remains bounded,
- changed count decreases as the system settles,
- uphill moves happen rarely but do not destabilize.

---

# 4. v0.2-pre — Byte-Level Contrastive Field Learning

## 4.1 Purpose

v0.2-pre answers:

> Can the architecture learn a real input-output mapping through local contrastive field updates?

The task is byte-level next-byte prediction.

---

## 4.2 Input and Target

Input byte:

\[
x_i\in\{0,\dots,255\}
\]

Target:

\[
y_i=x_{i+1}
\]

---

## 4.3 State and Decoder

State:

\[
s_i=(s_i^{(0)},s_i^{(1)})
\]

with:

\[
s_i^{(c)}\in\{0,\dots,15\}
\]

Decoder:

\[
\hat{y}_i=16s_i^{(0)}+s_i^{(1)}
\]

---

## 4.4 Positive State

\[
z_i^{+,(0)}=\left\lfloor \frac{y_i}{16}\right\rfloor
\]

\[
z_i^{+,(1)}=y_i\bmod 16
\]

Thus:

\[
z_i^+=(z_i^{+,(0)},z_i^{+,(1)})
\]

This is directly defined by data.

---

## 4.5 Negative State

At epoch start:

\[
s_i^{(0)}(0)=\left\lfloor \frac{x_i}{16}\right\rfloor
\]

\[
s_i^{(1)}(0)=x_i\bmod 16
\]

Run relaxation for \(T\) cycles.

Negative state:

\[
z_i^-=s_i(T)
\]

---

## 4.6 Shared Local Field

\[
H_c[x,a]
\]

where:

- \(c\in\{0,1\}\),
- \(x\in\{0,\dots,255\}\),
- \(a\in\{0,\dots,15\}\).

For node \(i\):

\[
h_{i,c}[a]=H_c[x_i,a]
\]

Table size:

\[
2\times256\times16=8192
\]

constant in sequence length.

---

## 4.7 Energy

\[
E_i=
-\lambda_u\sum_c H_c[x_i,s_i^{(c)}]
+
\lambda_v
\sum_{j\in\mathcal{N}(i)}
\sum_c
\mathbf{1}[s_i^{(c)}\ne s_j^{(c)}]
\]

Reported total:

\[
H=
\sum_i
-\lambda_u\sum_c H_c[x_i,s_i^{(c)}]
+
\frac{1}{2}\lambda_v
\sum_i\sum_{j\in\mathcal{N}(i)}\sum_c
\mathbf{1}[s_i^{(c)}\ne s_j^{(c)}]
\]

Default:

\[
\lambda_v=0
\]

for first correctness test.

---

## 4.8 v0.2 Proposal

Proposal changes one channel:

\[
s_i^{(c)}:a_{old}\to a_{new}
\]

where:

\[
a_{new}\ne a_{old}
\]

Delta:

\[
\Delta E_i =
-\lambda_u(H_c[x_i,a_{new}]-H_c[x_i,a_{old}])
+
\lambda_v
\sum_{j\in\mathcal{N}(i)}
(
\mathbf{1}[a_{new}\ne s_j^{(c)}]
-
\mathbf{1}[a_{old}\ne s_j^{(c)}]
)
\]

Effective delta:

\[
\Delta E_i^{eff}=\Delta E_i+\lambda_m m_i
\]

---

## 4.9 Contrastive Learning Rule

After relaxation:

Positive:

\[
z_i^{+,(c)}
\]

Negative:

\[
z_i^{-,(c)}
\]

Update:

\[
H_c[x_i,a]\leftarrow H_c[x_i,a]
+
\eta_h
(
\mathbf{1}[a=z_i^{+,(c)}]
-
\mathbf{1}[a=z_i^{-,(c)}]
)
\]

If positive equals negative, skip.

Then decay:

\[
H_c[x,a]\leftarrow(1-\eta_h\lambda_h)H_c[x,a]
\]

Clip:

\[
H_c[x,a]\leftarrow clip(H_c[x,a],-H_{clip},H_{clip})
\]

This is:

- not backpropagation,
- not reinforcement learning,
- local contrastive energy learning.

---

## 4.10 Field-only Prediction

\[
\hat{s}_{i,H}^{(0)}=\arg\max_a H_0[x_i,a]
\]

\[
\hat{s}_{i,H}^{(1)}=\arg\max_a H_1[x_i,a]
\]

\[
\hat{y}_{i,H}=16\hat{s}_{i,H}^{(0)}+\hat{s}_{i,H}^{(1)}
\]

Metric:

\[
field\_byte\_acc
\]

---

## 4.11 First-order Oracle

Transition counts:

\[
count[x,y]
\]

Oracle:

\[
oracle1(x)=\arg\max_y count[x,y]
\]

Accuracy:

\[
oracle1\_acc=
\frac{1}{N}\sum_i
\mathbf{1}[oracle1(x_i)=y_i]
\]

Use this to interpret repeating-text results.

---

## 4.12 Field Margin

\[
M_{i,c}=H_c[x_i,z_i^{+,(c)}]
-
\max_{a\ne z_i^{+,(c)}}H_c[x_i,a]
\]

Average:

\[
field\_margin=
\frac{1}{2N}\sum_i\sum_c M_{i,c}
\]

Expected diagnostic order:

```text
field_margin -> field_byte_acc -> byte_acc
```

---

# 5. Metrics and Interpretation

## 5.1 v0.2 CSV Header

```csv
epoch,H,byte_acc,field_byte_acc,oracle1_acc,ch0_acc,ch1_acc,field_ch0_acc,field_ch1_acc,field_margin,mean_disagreement,mean_tick,mean_abs_reservoir,changed,downhill_accepts,uphill_accepts,rejected,skipped
```

## 5.2 Interpretation

### Good

```text
field_margin rises
field_byte_acc rises
byte_acc eventually rises
tick bounded
reservoir bounded
```

### Field learning works, dynamics needs tuning

```text
field_margin rises
field_byte_acc rises
byte_acc stays low
```

### Learning broken

```text
field_margin flat
field_byte_acc flat
```

under:

```bash
--lambda-v 0
```

### Neighbor smoothing conflict

```text
lambda_v=0 succeeds
lambda_v=0.25 fails
```

This is expected on counter data.

---

# 6. Experiments

## 6.1 v0.1 Smoke Tests

```bash
./build/dmv01 --N 32 --cycles 100 --seed 1 > results/v01_N32.csv
./build/dmv01 --N 128 --cycles 300 --seed 1 > results/v01_N128.csv
./build/dmv01 --N 1000 --cycles 1000 --seed 1 > results/v01_N1000.csv
```

## 6.2 v0.2 Counter

```bash
./build/dmv02 --dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --seed 1 --lambda-v 0 > results/counter_lv0.csv
```

## 6.3 v0.2 Counter Ablation

```bash
./build/dmv02 --dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --seed 1 --lambda-v 0.05 > results/counter_lv005.csv
./build/dmv02 --dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --seed 1 --lambda-v 0.25 > results/counter_lv025.csv
```

## 6.4 v0.2 Repeating Text

```bash
./build/dmv02 --dataset repeating-text --N 256 --epochs 300 --cycles-per-epoch 20 --seed 1 --lambda-v 0 > results/text_lv0.csv
```

Evaluate against oracle1_acc.

---

# 7. Complexity

For fixed:

- degree \(K\),
- proposal count \(M\),
- channel count \(C\),
- state count \(S\),

each node update is:

\[
O(1)
\]

One cycle is:

\[
O(N)
\]

One epoch is:

\[
O(NT)
\]

where \(T\) is cycles per epoch.

If \(T\) is fixed, per-epoch cost is linear in \(N\).

Memory:

\[
O(N)
\]

for active nodes.

Per-node memory:

\[
O(1)
\]

Field table memory:

\[
O(1)
\]

with respect to \(N\).

Important:

Do not claim total memory is \(O(1)\) when active nodes scale with sequence length.

Correct claim:

> constant-size per-node state and linear total memory in active stream length.

---

# 8. Roadmap Beyond v0.2-pre

## 8.1 v0.2-b — Channel Coupling

Problem:

v0.2-pre treats high and low nibble independently.

Add:

\[
B[x,a,b]
\]

Energy:

\[
E_i^{intra}=-\lambda_b B[x_i,s_i^{(0)},s_i^{(1)}]
\]

Size:

\[
256\times16\times16=65536
\]

Contrastive update:

\[
B[x_i,z_i^{+,(0)},z_i^{+,(1)}]+= \eta_b
\]

\[
B[x_i,z_i^{-,(0)},z_i^{-,(1)}]-= \eta_b
\]

Goal:

> Learn high-low channel compatibility.

---

## 8.2 v0.3 — Sparse Routing

Problem:

Local ring cannot solve long-range dependency.

Add:

\[
\mathcal{N}(i)=\mathcal{N}_{local}(i)\cup\mathcal{N}_{jump}(i)
\]

Constraint:

\[
|\mathcal{N}_{jump}(i)|\le K_{jump}
\]

Never scan all nodes.

Candidate generation:

- LSH bucket,
- memory slots,
- learned edge score.

Trigger:

\[
|r_i|>\rho
\quad\text{or}\quad
stag_i=1
\]

Goal:

> event-triggered nonlocal transition with O(1) candidates.

---

## 8.3 v0.4 — Routing Plasticity

Edge score:

\[
g_{ij}
\]

Local advantage:

\[
A_{ij}=E_{before}(\mathcal{B}(i))-E_{after}(\mathcal{B}(i))-cost(i,j)
\]

Update:

\[
g_{ij}\leftarrow(1-\lambda_g)g_{ij}+\eta_g A_{ij}
\]

Goal:

> keep useful long-range edges and decay useless ones.

---

## 8.4 v0.5 — Continual Learning

Benchmark:

```text
Task A -> Task B -> Task A
```

Metrics:

- new task adaptation speed,
- old task retention,
- forgetting score,
- updates per example,
- energy per correct prediction.

Goal:

> demonstrate backprop-free online adaptation.

---

# 9. Higher-Level Representation Roadmap

Byte-level prediction is not the final target.

## Stage A — Byte sanity

Current v0.2-pre.

## Stage B — Byte-context field

Use local context:

\[
H_c[x_{i-1},x_i,x_{i+1},a]
\]

or hashed n-gram context.

## Stage C — Chunk nodes

Group 4–8 bytes into chunk nodes.

```text
byte nodes -> chunk nodes
```

## Stage D — Token-like nodes

Frequent chunks become reusable token-like nodes.

```text
chunk nodes -> token nodes
```

## Stage E — Sparse routing at chunk/token level

Do not apply long-range routing too early at raw byte level.

Meaningful routing requires meaningful codes.

---

# 10. Investor and Paper Positioning

## 10.1 Correct Paper Claim

Good:

> A backpropagation-free local energy substrate for linear-time online adaptation.

Avoid:

> A Transformer killer.

## 10.2 Correct Memory Claim

Good:

> constant-size state per node and linear memory in active stream length.

Avoid:

> infinite context with total O(1) memory.

## 10.3 Correct Long-context Claim

Good after v0.3:

> sparse O(1)-candidate retrieval without dense attention.

Avoid:

> perfect infinite recall.

## 10.4 Thesis Statement

Recommended:

> We introduce a discrete local-energy substrate that replaces global backpropagation and dense attention with bounded-degree state dynamics and contrastive field updates, enabling linear-time adaptation on streaming data.

---

# 11. Required Killer Graphs for Later Pitch

Not for v0.2-pre yet.

1. memory vs context length,
2. throughput vs context length,
3. passkey accuracy vs context length,
4. online adaptation curve,
5. old-task retention under distribution shift,
6. energy per correct recall,
7. scaling curve vs compute/memory budget.

---

# 12. Red Lines

Do not proceed to sparse routing until:

- v0.2-pre field_margin rises,
- field_byte_acc rises,
- byte_acc rises or dynamics failure is understood,
- lambda_v ablation is completed.

Do not proceed to investor claims until:

- passkey retrieval works,
- memory/throughput profiles exist,
- continual learning benchmark exists.

Do not proceed to paper submission until:

- baselines are implemented,
- limitations are documented,
- ablations are complete.

---

# 13. Final Execution Order

## Step 1

Implement v0.1.

## Step 2

Run v0.1 smoke tests.

## Step 3

Implement v0.2-pre.

## Step 4

Run counter with lambda_v=0.

## Step 5

Run counter lambda_v ablation.

## Step 6

Run repeating-text and compare to oracle1.

## Step 7

Analyze curves:

```text
field_margin -> field_byte_acc -> byte_acc
```

## Step 8

Only if successful, implement v0.2-b.

## Step 9

Only after meaningful codes exist, implement v0.3 sparse routing.

---

# 14. Minimal Success Definition

The architecture is worth continuing if v0.2-pre shows:

```text
counter:
  field_margin rises
  field_byte_acc rises
  byte_acc rises or lag is explainable

repeating-text:
  field_byte_acc approaches oracle1_acc

stability:
  tick bounded
  reservoir bounded
```

If these fail under lambda_v=0, stop and debug before adding any complexity.
