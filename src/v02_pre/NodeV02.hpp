#pragma once

#include <array>
#include <cstdint>

namespace dle {

struct NodeV02 {
    std::array<std::uint8_t, 2> state{0, 0};
    std::uint8_t input_byte = 0;
    std::uint8_t target_byte = 0;
    float mass = 1.0f;
    float reservoir = 0.0f;
    float tick = 1.0f;
    std::uint8_t age_since_change = 0;
    std::array<int, 8> neighbors{};
};

}  // namespace dle
