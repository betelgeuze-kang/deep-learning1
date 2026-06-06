#include "backend/RouteQualityBackend.hpp"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace dle {
namespace {

BackendRuntimeStats g_stats;

void compute_factors_cpu(
    const float* base_weights,
    std::size_t count,
    float mean_base_weight,
    float beta,
    float min_factor,
    float max_factor,
    float* out_factors) {
    for (std::size_t i = 0; i < count; ++i) {
        out_factors[i] = route_quality_candidate_weight_factor_cpu(
            base_weights[i],
            mean_base_weight,
            beta,
            min_factor,
            max_factor);
    }
}

}  // namespace

#if DLE_ENABLE_HIP
bool hip_candidate_weight_factors_impl(
    int device,
    const float* base_weights,
    std::size_t count,
    float mean_base_weight,
    float beta,
    float min_factor,
    float max_factor,
    float* out_factors);

bool hip_route_proposal_energy_scores_impl(
    int device,
    const float* high_scores,
    const float* low_scores,
    const float* coupling_scores,
    float lambda_u,
    float lambda_b,
    float* out_scores);
#endif

bool hip_backend_compiled() {
#if DLE_ENABLE_HIP
    return true;
#else
    return false;
#endif
}

void configure_numeric_backend(const V02PreParams& params) {
    if (params.backend != "cpu" && params.backend != "hip") {
        throw std::runtime_error("--backend must be one of: cpu, hip");
    }
    if (params.hip_device < 0) {
        throw std::runtime_error("--hip-device must be non-negative");
    }
    if (params.backend == "hip" && !hip_backend_compiled()) {
        throw std::runtime_error(
            "--backend hip requested, but this binary was built without "
            "DLE_ENABLE_HIP=ON");
    }

    g_stats.backend_active = params.backend == "hip";
    g_stats.hip_enabled = hip_backend_compiled();
    g_stats.hip_device = params.hip_device;
    g_stats.hip_kernel_calls = 0;
    g_stats.hip_fallback_count = 0;
}

void reset_numeric_backend_epoch_stats() {
    g_stats.hip_kernel_calls = 0;
    g_stats.hip_fallback_count = 0;
}

BackendRuntimeStats numeric_backend_stats() {
    g_stats.hip_enabled = hip_backend_compiled();
    return g_stats;
}

float route_quality_candidate_weight_factor_cpu(
    float base_weight,
    float mean_base_weight,
    float beta,
    float min_factor,
    float max_factor) {
    if (mean_base_weight <= 0.0f || base_weight < 0.0f ||
        !std::isfinite(mean_base_weight) || !std::isfinite(base_weight)) {
        return 1.0f;
    }
    const double relative =
        static_cast<double>(base_weight / mean_base_weight) - 1.0;
    const double unclamped = 1.0 + static_cast<double>(beta) * relative;
    return static_cast<float>(
        std::clamp(
            unclamped,
            static_cast<double>(min_factor),
            static_cast<double>(max_factor)));
}

void route_quality_candidate_weight_factors(
    const V02PreParams& params,
    const float* base_weights,
    std::size_t count,
    float mean_base_weight,
    float* out_factors) {
    if (count == 0) {
        return;
    }
    if (base_weights == nullptr || out_factors == nullptr) {
        throw std::runtime_error("candidate-weight factor buffers must be non-null");
    }

    if (params.backend == "hip") {
#if DLE_ENABLE_HIP
        const bool ok = hip_candidate_weight_factors_impl(
            params.hip_device,
            base_weights,
            count,
            mean_base_weight,
            params.route_quality_candidate_weight_beta,
            params.route_quality_candidate_weight_min,
            params.route_quality_candidate_weight_max,
            out_factors);
        if (ok) {
            ++g_stats.hip_kernel_calls;
            return;
        }
        ++g_stats.hip_fallback_count;
#else
        ++g_stats.hip_fallback_count;
#endif
    }

    compute_factors_cpu(
        base_weights,
        count,
        mean_base_weight,
        params.route_quality_candidate_weight_beta,
        params.route_quality_candidate_weight_min,
        params.route_quality_candidate_weight_max,
        out_factors);
}

float route_quality_candidate_weight_factor_backend(
    const V02PreParams& params,
    float base_weight,
    float mean_base_weight) {
    float factor = 1.0f;
    route_quality_candidate_weight_factors(
        params,
        &base_weight,
        1,
        mean_base_weight,
        &factor);
    return factor;
}

float route_proposal_energy_score_cpu(
    float high_score,
    float low_score,
    float coupling_score,
    float lambda_u,
    float lambda_b) {
    return -lambda_u * (high_score + low_score) - lambda_b * coupling_score;
}

void route_proposal_energy_scores(
    const V02PreParams& params,
    const float* high_scores,
    const float* low_scores,
    const float* coupling_scores,
    float lambda_u,
    float lambda_b,
    float* out_scores) {
    if (high_scores == nullptr || low_scores == nullptr ||
        coupling_scores == nullptr || out_scores == nullptr) {
        throw std::runtime_error("proposal-score buffers must be non-null");
    }

    if (params.backend == "hip") {
#if DLE_ENABLE_HIP
        const bool ok = hip_route_proposal_energy_scores_impl(
            params.hip_device,
            high_scores,
            low_scores,
            coupling_scores,
            lambda_u,
            lambda_b,
            out_scores);
        if (ok) {
            ++g_stats.hip_kernel_calls;
            return;
        }
        ++g_stats.hip_fallback_count;
#else
        ++g_stats.hip_fallback_count;
#endif
    }

    for (int high = 0; high < 16; ++high) {
        for (int low = 0; low < 16; ++low) {
            const int idx = high * 16 + low;
            out_scores[idx] = route_proposal_energy_score_cpu(
                high_scores[high],
                low_scores[low],
                coupling_scores[idx],
                lambda_u,
                lambda_b);
        }
    }
}

}  // namespace dle
