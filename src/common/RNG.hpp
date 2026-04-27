#pragma once

#include <algorithm>
#include <cstdint>
#include <random>

namespace dle {

class RNG {
  public:
    explicit RNG(std::uint32_t seed) : engine_(seed) {}

    int uniform_int(int lo, int hi) {
        std::uniform_int_distribution<int> dist(lo, hi);
        return dist(engine_);
    }

    float uniform_float(float lo = 0.0f, float hi = 1.0f) {
        std::uniform_real_distribution<float> dist(lo, hi);
        return dist(engine_);
    }

    bool bernoulli(float p) {
        const float clamped = std::max(0.0f, std::min(1.0f, p));
        std::bernoulli_distribution dist(clamped);
        return dist(engine_);
    }

  private:
    std::mt19937 engine_;
};

}  // namespace dle
