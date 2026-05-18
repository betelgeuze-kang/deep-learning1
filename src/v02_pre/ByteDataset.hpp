#pragma once

#include <array>
#include <cstdint>
#include <string>
#include <vector>

#include "common/Params.hpp"

namespace dle {

class ByteDataset {
  public:
    struct RouteHint {
        int query_pos = 0;
        int value_pos = -1;
        std::uint8_t value_byte = 0;
        float weight = 1.0f;
        std::vector<int> candidate_value_positions;
    };

    struct KVRecord {
        std::string key;
        int marker_pos = -1;
        int value_pos = -1;
        int value_len = 1;
        std::uint8_t value = 0;
    };

    struct KVQuery {
        std::string key;
        int query_pos = -1;
        int value_pos = -1;
        std::uint8_t value = 0;
        bool hit = false;
    };

    struct Window {
        std::vector<std::uint8_t> inputs;
        std::vector<std::uint8_t> targets;
        std::vector<RouteHint> route_hints;
        std::vector<KVRecord> kv_records;
        std::vector<KVQuery> kv_queries;
        int kv_record_count = 0;
        int kv_duplicate_key_count = 0;
        int kv_query_count = 0;
        int kv_query_hit_count = 0;
        int kv_missing_key_count = 0;
        int route_candidate_query_count = 0;
        int route_candidate_hit_count = 0;
        int route_candidate_top1_hit_count = 0;
        double route_candidate_rank_sum = 0.0;
        int route_bucket_load_sum = 0;
        int route_bucket_load_max = 0;
        int route_bucket_collision_count = 0;
    };

    explicit ByteDataset(const V02PreParams& params);

    Window window_for_epoch(int epoch, int N) const;
    std::uint8_t oracle_next(std::uint8_t x) const;
    const std::array<std::uint8_t, 256>& oracle_table() const { return oracle_next_; }
    const std::string& description() const { return description_; }
    std::size_t size() const { return data_.size(); }

  private:
    void build_counter();
    void build_repeating_text();
    void load_input_file(const std::string& path);
    void build_oracle();
    void build_route_hints();

    std::vector<std::uint8_t> data_;
    std::vector<bool> route_hint_present_;
    std::vector<std::uint8_t> route_hint_values_;
    std::vector<int> route_hint_value_positions_;
    std::vector<std::vector<int>> route_hint_candidate_value_positions_;
    std::vector<float> route_hint_weights_;
    std::vector<bool> kv_record_present_;
    std::vector<bool> kv_duplicate_record_present_;
    std::vector<std::string> kv_record_keys_;
    std::vector<int> kv_record_value_positions_;
    std::vector<int> kv_record_value_lengths_;
    std::vector<std::uint8_t> kv_record_values_;
    std::vector<bool> kv_query_present_;
    std::vector<bool> kv_query_hit_;
    std::vector<std::string> kv_query_keys_;
    std::vector<int> kv_query_value_positions_;
    std::vector<std::uint8_t> kv_query_values_;
    std::vector<bool> route_candidate_query_present_;
    std::vector<bool> route_candidate_hit_;
    std::vector<int> route_candidate_rank_;
    std::vector<int> route_bucket_load_;
    std::vector<bool> route_bucket_collision_;
    std::array<std::array<std::uint32_t, 256>, 256> counts_{};
    std::array<std::uint8_t, 256> oracle_next_{};
    V02PreParams params_;
    std::string description_;
};

}  // namespace dle
