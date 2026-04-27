#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace dle {

class CouplingTable {
  public:
    static constexpr int ByteValues = 256;
    static constexpr int States = 16;

    float score(std::uint8_t x, std::uint8_t high_state, std::uint8_t low_state) const;
    void add(std::uint8_t x, std::uint8_t high_state, std::uint8_t low_state, float delta);

  private:
    static constexpr std::size_t kSize = ByteValues * States * States;

    static constexpr std::size_t index(
        std::uint8_t x,
        std::uint8_t high_state,
        std::uint8_t low_state) {
        return static_cast<std::size_t>(x) * States * States +
               static_cast<std::size_t>(high_state) * States +
               static_cast<std::size_t>(low_state);
    }

    std::array<float, kSize> values_{};
};

}  // namespace dle
