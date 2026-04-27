#include "v02_pre/FieldTable.hpp"

#include <algorithm>

#include "common/RNG.hpp"

namespace dle {

void FieldTable::initialize(RNG& rng) {
    for (float& value : values_) {
        value = rng.uniform_float(-0.01f, 0.01f);
    }
}

float FieldTable::score(int ch, std::uint8_t x, std::uint8_t state) const {
    return values_[index(ch, x, state)];
}

void FieldTable::add(int ch, std::uint8_t x, std::uint8_t state, float delta) {
    values_[index(ch, x, state)] += delta;
}

void FieldTable::decay(float eta_h, float lambda_h) {
    const float scale = 1.0f - eta_h * lambda_h;
    for (float& value : values_) {
        value *= scale;
    }
}

void FieldTable::clip(float H_clip) {
    for (float& value : values_) {
        value = std::max(-H_clip, std::min(H_clip, value));
    }
}

int FieldTable::argmax_state(int ch, std::uint8_t x) const {
    int best_state = 0;
    float best_score = score(ch, x, 0);
    for (int state = 1; state < States; ++state) {
        const float candidate = score(ch, x, static_cast<std::uint8_t>(state));
        if (candidate > best_score) {
            best_score = candidate;
            best_state = state;
        }
    }
    return best_state;
}

float FieldTable::positive_margin(int ch, std::uint8_t x, std::uint8_t positive_state) const {
    const float positive_score = score(ch, x, positive_state);
    float best_other = -1.0e30f;
    for (int state = 0; state < States; ++state) {
        if (state == positive_state) {
            continue;
        }
        best_other = std::max(best_other, score(ch, x, static_cast<std::uint8_t>(state)));
    }
    return positive_score - best_other;
}

}  // namespace dle
