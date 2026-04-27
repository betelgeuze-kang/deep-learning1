#include "v02_pre/CouplingTable.hpp"

namespace dle {

float CouplingTable::score(std::uint8_t x, std::uint8_t high_state, std::uint8_t low_state) const {
    return values_[index(x, high_state, low_state)];
}

void CouplingTable::add(
    std::uint8_t x,
    std::uint8_t high_state,
    std::uint8_t low_state,
    float delta) {
    values_[index(x, high_state, low_state)] += delta;
}

}  // namespace dle
