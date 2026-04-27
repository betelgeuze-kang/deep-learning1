#include "v01/GraphV01.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <limits>
#include <stdexcept>

namespace dle {

namespace {

int wrap_index(int index, int n) {
    const int mod = index % n;
    return mod < 0 ? mod + n : mod;
}

}  // namespace

GraphV01::GraphV01(const V01Params& params) : params_(params), rng_(static_cast<std::uint32_t>(params.seed)) {
    validate_params();
    initialize_graph();
}

CycleMetrics GraphV01::run_cycle(int cycle) {
    std::fill(changed_this_cycle_.begin(), changed_this_cycle_.end(), false);

    int downhill = 0;
    int uphill = 0;
    int rejected = 0;
    int skipped = 0;

    for (int color = 0; color < params_.C_colors; ++color) {
        for (int index = color; index < params_.N; index += params_.C_colors) {
            try_update_node(index, downhill, uphill, rejected, skipped);
        }
    }

    relax_tick_and_reservoir();
    update_age();

    return collect_metrics(cycle, downhill, uphill, rejected, skipped);
}

void GraphV01::initialize_graph() {
    nodes_.assign(static_cast<std::size_t>(params_.N), {});
    changed_this_cycle_.assign(static_cast<std::size_t>(params_.N), false);

    for (int i = 0; i < params_.N; ++i) {
        NodeV01& node = nodes_[static_cast<std::size_t>(i)];
        node.state = static_cast<std::uint8_t>(rng_.uniform_int(0, params_.S - 1));
        node.mass = params_.mass_init;
        node.reservoir = 0.0f;
        node.tick = 1.0f;
        node.age_since_change = 0;

        node.neighbors.fill(i);
        int slot = 0;
        for (int offset = -params_.R; offset <= params_.R; ++offset) {
            if (offset == 0) {
                continue;
            }
            node.neighbors[static_cast<std::size_t>(slot++)] = wrap_index(i + offset, params_.N);
        }

        for (int s = 0; s < 16; ++s) {
            node.h_table[static_cast<std::size_t>(s)] = rng_.uniform_float(-1.0f, 1.0f);
        }
    }
}

void GraphV01::validate_params() const {
    if (params_.N <= 0) {
        throw std::runtime_error("N must be positive");
    }
    if (params_.S < 2 || params_.S > 16) {
        throw std::runtime_error("S must be in [2, 16] for the reference implementation");
    }
    if (params_.R < 1 || params_.R > 4) {
        throw std::runtime_error("R must be in [1, 4] for the reference implementation");
    }
    if (params_.K != 2 * params_.R) {
        throw std::runtime_error("K must equal 2 * R in the reference ring graph");
    }
    if (params_.K < 2 || params_.K > 8) {
        throw std::runtime_error("K must be in [2, 8]");
    }
    if (params_.C_colors <= 2 * params_.R) {
        throw std::runtime_error("C_colors must be greater than 2 * R for a safe color schedule");
    }
    if (params_.proposal_count <= 0) {
        throw std::runtime_error("proposal_count must be positive");
    }
}

GraphV01::Candidate GraphV01::sample_best_candidate(int index) {
    const NodeV01& node = nodes_[static_cast<std::size_t>(index)];
    Candidate best;

    if (params_.proposal_count >= params_.S - 1) {
        for (int state = 0; state < params_.S; ++state) {
            if (state == node.state) {
                continue;
            }
            const float delta = delta_energy(index, static_cast<std::uint8_t>(state));
            const float delta_eff = delta + params_.lambda_m * node.mass;
            if (!best.valid || delta_eff < best.delta_eff) {
                best.state = static_cast<std::uint8_t>(state);
                best.delta = delta;
                best.delta_eff = delta_eff;
                best.valid = true;
            }
        }
        return best;
    }

    std::array<bool, 16> seen{};
    seen[static_cast<std::size_t>(node.state)] = true;

    int sampled = 0;
    while (sampled < params_.proposal_count) {
        const int proposal = rng_.uniform_int(0, params_.S - 1);
        if (seen[static_cast<std::size_t>(proposal)]) {
            continue;
        }
        seen[static_cast<std::size_t>(proposal)] = true;
        ++sampled;

        const float delta = delta_energy(index, static_cast<std::uint8_t>(proposal));
        const float delta_eff = delta + params_.lambda_m * node.mass;
        if (!best.valid || delta_eff < best.delta_eff) {
            best.state = static_cast<std::uint8_t>(proposal);
            best.delta = delta;
            best.delta_eff = delta_eff;
            best.valid = true;
        }
    }

    return best;
}

float GraphV01::delta_energy(int index, std::uint8_t new_state) const {
    const NodeV01& node = nodes_[static_cast<std::size_t>(index)];
    const std::uint8_t current_state = node.state;

    float delta = -params_.lambda_u *
                  (node.h_table[static_cast<std::size_t>(new_state)] -
                   node.h_table[static_cast<std::size_t>(current_state)]);

    for (int n = 0; n < params_.K; ++n) {
        const NodeV01& neighbor = nodes_[static_cast<std::size_t>(node.neighbors[static_cast<std::size_t>(n)])];
        const float new_disagreement = new_state != neighbor.state ? 1.0f : 0.0f;
        const float old_disagreement = current_state != neighbor.state ? 1.0f : 0.0f;
        delta += params_.lambda_v * (new_disagreement - old_disagreement);
    }

    return delta;
}

int GraphV01::disagreement(int index) const {
    const NodeV01& node = nodes_[static_cast<std::size_t>(index)];
    int total = 0;
    for (int n = 0; n < params_.K; ++n) {
        const NodeV01& neighbor = nodes_[static_cast<std::size_t>(node.neighbors[static_cast<std::size_t>(n)])];
        total += node.state != neighbor.state ? 1 : 0;
    }
    return total;
}

float GraphV01::local_temperature(int index) const {
    const NodeV01& node = nodes_[static_cast<std::size_t>(index)];
    return params_.T0 + params_.alpha_T * std::abs(node.reservoir) / (node.tick + params_.eps_T);
}

void GraphV01::try_update_node(int index, int& downhill, int& uphill, int& rejected, int& skipped) {
    const NodeV01& node = nodes_[static_cast<std::size_t>(index)];
    const float p_try = std::min(1.0f, 1.0f / std::max(1.0f, node.tick));
    if (!rng_.bernoulli(p_try)) {
        ++skipped;
        return;
    }

    const Candidate candidate = sample_best_candidate(index);
    if (!candidate.valid) {
        ++rejected;
        return;
    }

    if (candidate.delta_eff <= 0.0f) {
        accept_update(index, candidate, downhill, uphill);
        return;
    }

    const bool stagnant =
        node.age_since_change >= params_.stagnation_window &&
        disagreement(index) >= params_.stagnation_threshold;
    if (!stagnant) {
        ++rejected;
        return;
    }

    const float temperature = local_temperature(index);
    const float acceptance =
        std::exp(-candidate.delta_eff / std::max(temperature + params_.eps_T, params_.eps_T));
    if (rng_.bernoulli(acceptance)) {
        accept_update(index, candidate, downhill, uphill);
        return;
    }

    ++rejected;
}

void GraphV01::accept_update(int index, const Candidate& candidate, int& downhill, int& uphill) {
    NodeV01& node = nodes_[static_cast<std::size_t>(index)];
    node.state = candidate.state;

    const float q = candidate.delta_eff;
    for (int n = 0; n < params_.K; ++n) {
        NodeV01& neighbor =
            nodes_[static_cast<std::size_t>(node.neighbors[static_cast<std::size_t>(n)])];
        neighbor.reservoir += params_.eta_r * q / static_cast<float>(params_.K);
    }
    node.tick = std::min(params_.tau_max, node.tick + params_.eta_tau * std::abs(q));
    changed_this_cycle_[static_cast<std::size_t>(index)] = true;

    if (candidate.delta_eff <= 0.0f) {
        ++downhill;
    } else {
        ++uphill;
    }
}

void GraphV01::relax_tick_and_reservoir() {
    for (NodeV01& node : nodes_) {
        node.tick = std::max(1.0f, (1.0f - params_.tau_decay) * node.tick + params_.tau_decay);
        node.reservoir *= (1.0f - params_.reservoir_decay);
    }
}

void GraphV01::update_age() {
    for (std::size_t i = 0; i < nodes_.size(); ++i) {
        NodeV01& node = nodes_[i];
        if (changed_this_cycle_[i]) {
            node.age_since_change = 0;
        } else if (node.age_since_change < std::numeric_limits<std::uint8_t>::max()) {
            ++node.age_since_change;
        }
    }
}

CycleMetrics GraphV01::collect_metrics(
    int cycle,
    int downhill,
    int uphill,
    int rejected,
    int skipped) const {
    double disagreement_sum = 0.0;
    double tick_sum = 0.0;
    double abs_reservoir_sum = 0.0;
    int changed = 0;

    for (std::size_t i = 0; i < nodes_.size(); ++i) {
        disagreement_sum += static_cast<double>(disagreement(static_cast<int>(i)));
        tick_sum += static_cast<double>(nodes_[i].tick);
        abs_reservoir_sum += static_cast<double>(std::abs(nodes_[i].reservoir));
        changed += changed_this_cycle_[i] ? 1 : 0;
    }

    CycleMetrics metrics;
    metrics.cycle = cycle;
    metrics.H = total_energy();
    metrics.mean_disagreement = disagreement_sum / static_cast<double>(params_.N);
    metrics.mean_tick = tick_sum / static_cast<double>(params_.N);
    metrics.mean_abs_reservoir = abs_reservoir_sum / static_cast<double>(params_.N);
    metrics.changed = changed;
    metrics.downhill_accepts = downhill;
    metrics.uphill_accepts = uphill;
    metrics.rejected = rejected;
    metrics.skipped = skipped;
    return metrics;
}

double GraphV01::total_energy() const {
    double total = 0.0;
    for (int i = 0; i < params_.N; ++i) {
        const NodeV01& node = nodes_[static_cast<std::size_t>(i)];
        total += -static_cast<double>(params_.lambda_u) *
                 static_cast<double>(node.h_table[static_cast<std::size_t>(node.state)]);
        total += 0.5 * static_cast<double>(params_.lambda_v) *
                 static_cast<double>(disagreement(i));
    }
    return total;
}

}  // namespace dle
