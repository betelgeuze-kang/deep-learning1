#include "backend/RouteQualityBackend.hpp"

#include <hip/hip_runtime.h>

#include <cstddef>
#include <vector>

namespace dle {
namespace {

__device__ float clamp_factor(float value, float lo, float hi) {
    return fminf(fmaxf(value, lo), hi);
}

__global__ void candidate_weight_factor_kernel(
    const float* base_weights,
    std::size_t count,
    float mean_base_weight,
    float beta,
    float min_factor,
    float max_factor,
    float* out_factors) {
    const std::size_t idx =
        static_cast<std::size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
    if (idx >= count) {
        return;
    }

    const float base_weight = base_weights[idx];
    if (mean_base_weight <= 0.0f || base_weight < 0.0f ||
        !isfinite(mean_base_weight) || !isfinite(base_weight)) {
        out_factors[idx] = 1.0f;
        return;
    }

    const float relative = base_weight / mean_base_weight - 1.0f;
    out_factors[idx] = clamp_factor(
        1.0f + beta * relative,
        min_factor,
        max_factor);
}

__global__ void proposal_energy_score_kernel(
    const float* high_scores,
    const float* low_scores,
    const float* coupling_scores,
    float lambda_u,
    float lambda_b,
    float* out_scores) {
    const int idx = static_cast<int>(blockIdx.x) * blockDim.x + threadIdx.x;
    if (idx >= 256) {
        return;
    }
    const int high = idx / 16;
    const int low = idx % 16;
    out_scores[idx] =
        -lambda_u * (high_scores[high] + low_scores[low]) -
        lambda_b * coupling_scores[idx];
}

}  // namespace

bool hip_candidate_weight_factors_impl(
    int device,
    const float* base_weights,
    std::size_t count,
    float mean_base_weight,
    float beta,
    float min_factor,
    float max_factor,
    float* out_factors) {
    if (count == 0) {
        return true;
    }
    if (hipSetDevice(device) != hipSuccess) {
        return false;
    }

    const std::size_t bytes = count * sizeof(float);
    float* d_base = nullptr;
    float* d_out = nullptr;
    if (hipMalloc(&d_base, bytes) != hipSuccess) {
        return false;
    }
    if (hipMalloc(&d_out, bytes) != hipSuccess) {
        hipFree(d_base);
        return false;
    }
    if (hipMemcpy(d_base, base_weights, bytes, hipMemcpyHostToDevice) != hipSuccess) {
        hipFree(d_out);
        hipFree(d_base);
        return false;
    }

    constexpr int block_size = 128;
    const int grid_size = static_cast<int>((count + block_size - 1) / block_size);
    hipLaunchKernelGGL(
        candidate_weight_factor_kernel,
        dim3(grid_size),
        dim3(block_size),
        0,
        0,
        d_base,
        count,
        mean_base_weight,
        beta,
        min_factor,
        max_factor,
        d_out);
    if (hipGetLastError() != hipSuccess || hipDeviceSynchronize() != hipSuccess) {
        hipFree(d_out);
        hipFree(d_base);
        return false;
    }
    if (hipMemcpy(out_factors, d_out, bytes, hipMemcpyDeviceToHost) != hipSuccess) {
        hipFree(d_out);
        hipFree(d_base);
        return false;
    }

    hipFree(d_out);
    hipFree(d_base);
    return true;
}

bool hip_route_proposal_energy_scores_impl(
    int device,
    const float* high_scores,
    const float* low_scores,
    const float* coupling_scores,
    float lambda_u,
    float lambda_b,
    float* out_scores) {
    if (hipSetDevice(device) != hipSuccess) {
        return false;
    }

    float* d_high = nullptr;
    float* d_low = nullptr;
    float* d_coupling = nullptr;
    float* d_out = nullptr;
    if (hipMalloc(&d_high, 16 * sizeof(float)) != hipSuccess) {
        return false;
    }
    if (hipMalloc(&d_low, 16 * sizeof(float)) != hipSuccess) {
        hipFree(d_high);
        return false;
    }
    if (hipMalloc(&d_coupling, 256 * sizeof(float)) != hipSuccess) {
        hipFree(d_low);
        hipFree(d_high);
        return false;
    }
    if (hipMalloc(&d_out, 256 * sizeof(float)) != hipSuccess) {
        hipFree(d_coupling);
        hipFree(d_low);
        hipFree(d_high);
        return false;
    }

    bool ok =
        hipMemcpy(d_high, high_scores, 16 * sizeof(float), hipMemcpyHostToDevice) ==
            hipSuccess &&
        hipMemcpy(d_low, low_scores, 16 * sizeof(float), hipMemcpyHostToDevice) ==
            hipSuccess &&
        hipMemcpy(
            d_coupling,
            coupling_scores,
            256 * sizeof(float),
            hipMemcpyHostToDevice) == hipSuccess;
    if (!ok) {
        hipFree(d_out);
        hipFree(d_coupling);
        hipFree(d_low);
        hipFree(d_high);
        return false;
    }

    hipLaunchKernelGGL(
        proposal_energy_score_kernel,
        dim3(2),
        dim3(128),
        0,
        0,
        d_high,
        d_low,
        d_coupling,
        lambda_u,
        lambda_b,
        d_out);
    ok = hipGetLastError() == hipSuccess && hipDeviceSynchronize() == hipSuccess &&
         hipMemcpy(out_scores, d_out, 256 * sizeof(float), hipMemcpyDeviceToHost) ==
             hipSuccess;

    hipFree(d_out);
    hipFree(d_coupling);
    hipFree(d_low);
    hipFree(d_high);
    return ok;
}

}  // namespace dle
