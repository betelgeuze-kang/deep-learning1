#pragma once

#include <array>
#include <cmath>
#include <cstdint>

#include "v02_pre/CouplingTable.hpp"
#include "v02_pre/FieldTable.hpp"

namespace dle {

class EnergyCoreV02 {
  public:
    static double pair_energy(
        float lambda_u,
        float lambda_b,
        const FieldTable& field,
        const CouplingTable& coupling,
        std::uint8_t input_byte,
        std::uint8_t high_state,
        std::uint8_t low_state) {
        return field_energy(lambda_u, field, input_byte, high_state, low_state) +
               coupling_energy(lambda_b, coupling, input_byte, high_state, low_state);
    }

    static double field_energy(
        float lambda_u,
        const FieldTable& field,
        std::uint8_t input_byte,
        std::uint8_t high_state,
        std::uint8_t low_state) {
        return -static_cast<double>(lambda_u) *
               static_cast<double>(
                   field.score(0, input_byte, high_state) +
                   field.score(1, input_byte, low_state));
    }

    static double coupling_energy(
        float lambda_b,
        const CouplingTable& coupling,
        std::uint8_t input_byte,
        std::uint8_t high_state,
        std::uint8_t low_state) {
        return -static_cast<double>(lambda_b) *
               static_cast<double>(coupling.score(input_byte, high_state, low_state));
    }

    static float pair_delta(
        float lambda_u,
        float lambda_b,
        const FieldTable& field,
        const CouplingTable& coupling,
        std::uint8_t input_byte,
        const std::array<std::uint8_t, FieldTable::Channels>& old_state,
        std::uint8_t new_high,
        std::uint8_t new_low) {
        const double new_energy =
            pair_energy(lambda_u, lambda_b, field, coupling, input_byte, new_high, new_low);
        const double old_energy = pair_energy(
            lambda_u,
            lambda_b,
            field,
            coupling,
            input_byte,
            old_state[0],
            old_state[1]);
        return static_cast<float>(new_energy - old_energy);
    }

    static float neighbor_disagreement(
        std::uint8_t high_state,
        std::uint8_t low_state,
        const std::array<std::uint8_t, FieldTable::Channels>& neighbor_state) {
        return (high_state != neighbor_state[0] ? 1.0f : 0.0f) +
               (low_state != neighbor_state[1] ? 1.0f : 0.0f);
    }

    static float neighbor_disagreement_energy(
        float lambda_v,
        std::uint8_t high_state,
        std::uint8_t low_state,
        const std::array<std::uint8_t, FieldTable::Channels>& neighbor_state) {
        return lambda_v * neighbor_disagreement(high_state, low_state, neighbor_state);
    }

    static float neighbor_disagreement_delta(
        float lambda_v,
        const std::array<std::uint8_t, FieldTable::Channels>& old_state,
        std::uint8_t new_high,
        std::uint8_t new_low,
        const std::array<std::uint8_t, FieldTable::Channels>& neighbor_state) {
        const float new_disagreement =
            neighbor_disagreement(new_high, new_low, neighbor_state);
        const float old_disagreement =
            neighbor_disagreement(old_state[0], old_state[1], neighbor_state);
        return lambda_v * (new_disagreement - old_disagreement);
    }

    static float local_temperature(
        float t0,
        float alpha_t,
        float eps_t,
        float reservoir,
        float tick) {
        return t0 + alpha_t * std::abs(reservoir) / (tick + eps_t);
    }
};

}  // namespace dle
