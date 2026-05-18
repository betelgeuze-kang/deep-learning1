#include <algorithm>
#include <array>
#include <cmath>
#include <exception>
#include <iostream>
#include <vector>

#include "backend/RouteQualityBackend.hpp"
#include "common/Params.hpp"

int main(int argc, char** argv) {
    try {
        int device = 0;
        for (int i = 1; i < argc; ++i) {
            const std::string arg = argv[i];
            if (arg == "--hip-device" && i + 1 < argc) {
                device = std::stoi(argv[++i]);
            } else {
                std::cerr << "usage: hip_candidate_weight_parity [--hip-device <int>]\n";
                return 2;
            }
        }

        dle::V02PreParams params;
        params.backend = "hip";
        params.hip_device = device;
        params.route_quality_candidate_weight_beta = 8.0f;
        params.route_quality_candidate_weight_min = 0.5f;
        params.route_quality_candidate_weight_max = 8.0f;
        dle::configure_numeric_backend(params);

        const std::vector<float> base_weights{
            0.0f, 0.25f, 0.5f, 1.0f, 1.75f, 2.5f, 4.0f, 8.0f};
        const float mean_base_weight = 1.75f;
        std::vector<float> hip_factors(base_weights.size(), 0.0f);
        std::vector<float> cpu_factors(base_weights.size(), 0.0f);

        dle::route_quality_candidate_weight_factors(
            params,
            base_weights.data(),
            base_weights.size(),
            mean_base_weight,
            hip_factors.data());
        for (std::size_t i = 0; i < base_weights.size(); ++i) {
            cpu_factors[i] = dle::route_quality_candidate_weight_factor_cpu(
                base_weights[i],
                mean_base_weight,
                params.route_quality_candidate_weight_beta,
                params.route_quality_candidate_weight_min,
                params.route_quality_candidate_weight_max);
        }

        double max_abs_delta = 0.0;
        for (std::size_t i = 0; i < base_weights.size(); ++i) {
            max_abs_delta = std::max(
                max_abs_delta,
                std::fabs(static_cast<double>(hip_factors[i] - cpu_factors[i])));
        }
        const auto stats = dle::numeric_backend_stats();
        std::array<float, 16> high_scores{};
        std::array<float, 16> low_scores{};
        std::array<float, 256> coupling_scores{};
        for (int i = 0; i < 16; ++i) {
            high_scores[static_cast<std::size_t>(i)] =
                static_cast<float>((i % 5) - 2) * 0.125f;
            low_scores[static_cast<std::size_t>(i)] =
                static_cast<float>((i % 7) - 3) * 0.075f;
        }
        for (int high = 0; high < 16; ++high) {
            for (int low = 0; low < 16; ++low) {
                coupling_scores[static_cast<std::size_t>(high * 16 + low)] =
                    static_cast<float>(((high * 17 + low * 11) % 9) - 4) * 0.05f;
            }
        }
        std::array<float, 256> hip_scores{};
        std::array<float, 256> cpu_scores{};
        dle::route_proposal_energy_scores(
            params,
            high_scores.data(),
            low_scores.data(),
            coupling_scores.data(),
            1.3f,
            0.4f,
            hip_scores.data());
        for (int high = 0; high < 16; ++high) {
            for (int low = 0; low < 16; ++low) {
                const int idx = high * 16 + low;
                cpu_scores[static_cast<std::size_t>(idx)] =
                    dle::route_proposal_energy_score_cpu(
                        high_scores[static_cast<std::size_t>(high)],
                        low_scores[static_cast<std::size_t>(low)],
                        coupling_scores[static_cast<std::size_t>(idx)],
                        1.3f,
                        0.4f);
            }
        }
        double proposal_max_abs_delta = 0.0;
        int hip_best = 0;
        int cpu_best = 0;
        for (std::size_t i = 0; i < hip_scores.size(); ++i) {
            proposal_max_abs_delta = std::max(
                proposal_max_abs_delta,
                std::fabs(static_cast<double>(hip_scores[i] - cpu_scores[i])));
            if (hip_scores[i] < hip_scores[static_cast<std::size_t>(hip_best)]) {
                hip_best = static_cast<int>(i);
            }
            if (cpu_scores[i] < cpu_scores[static_cast<std::size_t>(cpu_best)]) {
                cpu_best = static_cast<int>(i);
            }
        }
        const auto final_stats = dle::numeric_backend_stats();
        std::cout << "hip_enabled=" << (stats.hip_enabled ? 1 : 0)
                  << ",backend_active=" << (stats.backend_active ? 1 : 0)
                  << ",hip_kernel_calls=" << final_stats.hip_kernel_calls
                  << ",hip_fallback_count=" << final_stats.hip_fallback_count
                  << ",max_abs_delta=" << max_abs_delta
                  << ",proposal_max_abs_delta=" << proposal_max_abs_delta
                  << ",cpu_best=" << cpu_best
                  << ",hip_best=" << hip_best << "\n";

        if (!stats.hip_enabled || !stats.backend_active ||
            final_stats.hip_kernel_calls < 2 ||
            final_stats.hip_fallback_count != 0 || max_abs_delta > 1e-5 ||
            proposal_max_abs_delta > 1e-5 || cpu_best != hip_best) {
            return 1;
        }
        return 0;
    } catch (const std::exception& ex) {
        std::cerr << "hip_candidate_weight_parity error: " << ex.what() << '\n';
        return 1;
    }
}
