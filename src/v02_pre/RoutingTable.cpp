#include "v02_pre/RoutingTable.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <stdexcept>

namespace dle {

namespace {

template <typename Score>
double normalized_score(Score score) {
    const double value = static_cast<double>(score);
    if (std::isnan(value)) {
        return -std::numeric_limits<double>::infinity();
    }
    return value;
}

template <typename Score>
bool score_is_better(
    int candidate_index,
    double candidate_score,
    int existing_index,
    const std::vector<Score>& scores) {
    const double existing_score =
        normalized_score(scores[static_cast<std::size_t>(existing_index)]);
    if (candidate_score > existing_score) {
        return true;
    }
    if (candidate_score < existing_score) {
        return false;
    }
    return candidate_index < existing_index;
}

template <typename Score>
void build_from_scored_keys(
    std::array<std::array<int, RoutingTable::MaxJump>, RoutingTable::ByteValues>& candidates,
    std::array<int, RoutingTable::ByteValues>& counts,
    const std::vector<std::uint8_t>& keys,
    const std::vector<Score>& scores,
    int k_jump) {
    if (keys.size() != scores.size()) {
        throw std::invalid_argument("routing score vector size must match keys");
    }

    const int limit = std::clamp(k_jump, 0, RoutingTable::MaxJump);
    if (limit == 0) {
        return;
    }

    for (std::size_t index = 0; index < keys.size(); ++index) {
        const auto byte_index = static_cast<std::size_t>(keys[index]);
        auto& slots = candidates[byte_index];
        int& count = counts[byte_index];
        const int candidate_index = static_cast<int>(index);
        const double candidate_score = normalized_score(scores[index]);

        int insert_at = 0;
        while (insert_at < count &&
               !score_is_better(candidate_index, candidate_score, slots[static_cast<std::size_t>(insert_at)], scores)) {
            ++insert_at;
        }

        if (count < limit) {
            for (int slot = count; slot > insert_at; --slot) {
                slots[static_cast<std::size_t>(slot)] = slots[static_cast<std::size_t>(slot - 1)];
            }
            slots[static_cast<std::size_t>(insert_at)] = candidate_index;
            ++count;
            continue;
        }

        if (insert_at >= limit) {
            continue;
        }

        for (int slot = limit - 1; slot > insert_at; --slot) {
            slots[static_cast<std::size_t>(slot)] = slots[static_cast<std::size_t>(slot - 1)];
        }
        slots[static_cast<std::size_t>(insert_at)] = candidate_index;
    }
}

}  // namespace

RoutingTable::RoutingTable() {
    clear();
}

void RoutingTable::clear() {
    counts_.fill(0);
    for (auto& slots : candidates_) {
        slots.fill(-1);
    }
}

void RoutingTable::build_from_keys(const std::vector<std::uint8_t>& keys, int k_jump) {
    clear();

    const int limit = std::clamp(k_jump, 0, MaxJump);
    if (limit == 0) {
        return;
    }

    for (std::size_t index = 0; index < keys.size(); ++index) {
        const auto key = keys[index];
        int& count = counts_[static_cast<std::size_t>(key)];
        if (count >= limit) {
            continue;
        }
        candidates_[static_cast<std::size_t>(key)][static_cast<std::size_t>(count)] =
            static_cast<int>(index);
        ++count;
    }
}

void RoutingTable::build_from_keys(
    const std::vector<std::uint8_t>& keys,
    const std::vector<float>& scores,
    int k_jump) {
    clear();
    build_from_scored_keys(candidates_, counts_, keys, scores, k_jump);
}

void RoutingTable::build_from_keys(
    const std::vector<std::uint8_t>& keys,
    const std::vector<double>& scores,
    int k_jump) {
    clear();
    build_from_scored_keys(candidates_, counts_, keys, scores, k_jump);
}

int RoutingTable::candidate_count(std::uint8_t key, int self_index) const {
    int count = 0;
    const auto byte_index = static_cast<std::size_t>(key);
    const int limit = counts_[byte_index];
    for (int slot = 0; slot < limit; ++slot) {
        if (candidates_[byte_index][static_cast<std::size_t>(slot)] != self_index) {
            ++count;
        }
    }
    return count;
}

int RoutingTable::stored_count(std::uint8_t key) const {
    return counts_[static_cast<std::size_t>(key)];
}

int RoutingTable::candidate_at(std::uint8_t key, int slot) const {
    const auto byte_index = static_cast<std::size_t>(key);
    if (slot < 0 || slot >= counts_[byte_index]) {
        return -1;
    }
    return candidates_[byte_index][static_cast<std::size_t>(slot)];
}

}  // namespace dle
