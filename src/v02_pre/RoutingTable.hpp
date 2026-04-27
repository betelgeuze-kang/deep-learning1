#pragma once

#include <array>
#include <cstdint>
#include <vector>

namespace dle {

class RoutingTable {
  public:
    static constexpr int ByteValues = 256;
    static constexpr int MaxJump = 8;

    RoutingTable();

    void clear();
    void build_from_keys(const std::vector<std::uint8_t>& keys, int k_jump);
    // Higher scores are better; equal scores prefer lower indices.
    void build_from_keys(
        const std::vector<std::uint8_t>& keys,
        const std::vector<float>& scores,
        int k_jump);
    void build_from_keys(
        const std::vector<std::uint8_t>& keys,
        const std::vector<double>& scores,
        int k_jump);
    int candidate_count(std::uint8_t key, int self_index) const;
    int stored_count(std::uint8_t key) const;
    int candidate_at(std::uint8_t key, int slot) const;

  private:
    std::array<std::array<int, MaxJump>, ByteValues> candidates_{};
    std::array<int, ByteValues> counts_{};
};

}  // namespace dle
