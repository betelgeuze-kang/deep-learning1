#pragma once

#include <cstdint>
#include <vector>

#include "common/Metrics.hpp"
#include "common/Params.hpp"
#include "common/RNG.hpp"
#include "v01/NodeV01.hpp"

namespace dle {

class GraphV01 {
  public:
    explicit GraphV01(const V01Params& params);

    CycleMetrics run_cycle(int cycle);

  private:
    struct Candidate {
        std::uint8_t state = 0;
        float delta = 0.0f;
        float delta_eff = 0.0f;
        bool valid = false;
    };

    void initialize_graph();
    void validate_params() const;
    Candidate sample_best_candidate(int index);
    float delta_energy(int index, std::uint8_t new_state) const;
    int disagreement(int index) const;
    float local_temperature(int index) const;
    void try_update_node(int index, int& downhill, int& uphill, int& rejected, int& skipped);
    void accept_update(int index, const Candidate& candidate, int& downhill, int& uphill);
    void relax_tick_and_reservoir();
    void update_age();
    CycleMetrics collect_metrics(
        int cycle,
        int downhill,
        int uphill,
        int rejected,
        int skipped) const;
    double total_energy() const;

    V01Params params_;
    RNG rng_;
    std::vector<NodeV01> nodes_;
    std::vector<bool> changed_this_cycle_;
};

}  // namespace dle
