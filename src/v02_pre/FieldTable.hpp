#pragma once

#include <array>
#include <cstdint>

namespace dle {

class RNG;

class FieldTable {
  public:
    static constexpr int Channels = 2;
    static constexpr int ByteValues = 256;
    static constexpr int States = 16;

    void initialize(RNG& rng);
    float score(int ch, std::uint8_t x, std::uint8_t state) const;
    void add(int ch, std::uint8_t x, std::uint8_t state, float delta);
    void decay(float eta_h, float lambda_h);
    void clip(float H_clip);
    int argmax_state(int ch, std::uint8_t x) const;
    float positive_margin(int ch, std::uint8_t x, std::uint8_t positive_state) const;

  private:
    static constexpr std::size_t kSize = Channels * ByteValues * States;

    static constexpr std::size_t index(int ch, std::uint8_t x, std::uint8_t state) {
        return static_cast<std::size_t>(ch) * ByteValues * States +
               static_cast<std::size_t>(x) * States + static_cast<std::size_t>(state);
    }

    std::array<float, kSize> values_{};
};

}  // namespace dle
