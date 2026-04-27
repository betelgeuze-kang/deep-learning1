#pragma once

#include <array>
#include <cstdint>

namespace dle {

struct NodeV01 {
    std::uint8_t state = 0;
    float mass = 1.0f;
    float reservoir = 0.0f;
    float tick = 1.0f;
    std::uint8_t age_since_change = 0;
    std::array<int, 8> neighbors{};
    std::array<float, 16> h_table{};
};

}  // namespace dle
