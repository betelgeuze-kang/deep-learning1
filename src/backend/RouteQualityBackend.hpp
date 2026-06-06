#pragma once

#include <cstddef>
#include <string>
#include <vector>

#include "common/Params.hpp"

namespace dle {

struct BackendRuntimeStats {
    bool backend_active = false;
    bool hip_enabled = false;
    int hip_device = 0;
    int hip_kernel_calls = 0;
    int hip_fallback_count = 0;
};

bool hip_backend_compiled();
void configure_numeric_backend(const V02PreParams& params);
void reset_numeric_backend_epoch_stats();
BackendRuntimeStats numeric_backend_stats();

float route_quality_candidate_weight_factor_cpu(
    float base_weight,
    float mean_base_weight,
    float beta,
    float min_factor,
    float max_factor);

void route_quality_candidate_weight_factors(
    const V02PreParams& params,
    const float* base_weights,
    std::size_t count,
    float mean_base_weight,
    float* out_factors);

float route_quality_candidate_weight_factor_backend(
    const V02PreParams& params,
    float base_weight,
    float mean_base_weight);

float route_proposal_energy_score_cpu(
    float high_score,
    float low_score,
    float coupling_score,
    float lambda_u,
    float lambda_b);

void route_proposal_energy_scores(
    const V02PreParams& params,
    const float* high_scores,
    const float* low_scores,
    const float* coupling_scores,
    float lambda_u,
    float lambda_b,
    float* out_scores);

}  // namespace dle
