#include "v02_pre/ByteDataset.hpp"

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <fstream>
#include <stdexcept>
#include <unordered_map>

namespace dle {

namespace {

std::uint32_t stable_key_hash(const std::string& key, int hash_bits) {
    std::uint32_t hash = 2166136261u;
    for (const unsigned char byte : key) {
        hash ^= static_cast<std::uint32_t>(byte);
        hash *= 16777619u;
    }
    if (hash_bits >= 32) {
        return hash;
    }
    const auto mask = (1u << static_cast<unsigned>(hash_bits)) - 1u;
    return hash & mask;
}

int digit_count(const std::string& key) {
    int count = 0;
    for (const unsigned char byte : key) {
        if (std::isdigit(byte)) {
            ++count;
        }
    }
    return count;
}

int common_prefix_count(const std::string& lhs, const std::string& rhs) {
    const auto limit = std::min(lhs.size(), rhs.size());
    std::size_t count = 0;
    while (count < limit && lhs[count] == rhs[count]) {
        ++count;
    }
    return static_cast<int>(count);
}

int common_suffix_count(const std::string& lhs, const std::string& rhs) {
    const auto limit = std::min(lhs.size(), rhs.size());
    std::size_t count = 0;
    while (count < limit &&
           lhs[lhs.size() - 1U - count] == rhs[rhs.size() - 1U - count]) {
        ++count;
    }
    return static_cast<int>(count);
}

double key_shape_score(const std::string& query_key, const std::string& record_key) {
    const auto max_len = static_cast<double>(
        std::max<std::size_t>(1U, std::max(query_key.size(), record_key.size())));
    double score = 0.0;
    if (query_key.size() == record_key.size()) {
        score += 4.0;
    }
    if (digit_count(query_key) == digit_count(record_key)) {
        score += 1.0;
    }
    score += static_cast<double>(common_prefix_count(query_key, record_key)) / max_len;
    score += static_cast<double>(common_suffix_count(query_key, record_key)) / max_len;
    return score;
}

}  // namespace

ByteDataset::ByteDataset(const V02PreParams& params) : params_(params) {
    if (!params.input_path.empty()) {
        load_input_file(params.input_path);
        description_ = "input:" + params.input_path;
    } else if (params.dataset == "counter") {
        build_counter();
        description_ = "counter";
    } else if (params.dataset == "repeating-text") {
        build_repeating_text();
        description_ = "repeating-text";
    } else {
        throw std::runtime_error("unknown dataset: " + params.dataset);
    }

    if (data_.empty()) {
        throw std::runtime_error("dataset is empty");
    }

    build_oracle();
    build_route_hints();
}

ByteDataset::Window ByteDataset::window_for_epoch(int epoch, int N) const {
    if (N <= 0) {
        throw std::runtime_error("N must be positive");
    }

    Window window;
    window.inputs.resize(static_cast<std::size_t>(N));
    window.targets.resize(static_cast<std::size_t>(N));

    const std::size_t offset =
        (static_cast<std::size_t>(epoch) * static_cast<std::size_t>(N)) % data_.size();
    const auto local_position = [&](int global_pos) {
        if (global_pos < 0) {
            return -1;
        }
        for (int local = 0; local < N; ++local) {
            const auto local_index =
                (offset + static_cast<std::size_t>(local)) % data_.size();
            if (local_index == static_cast<std::size_t>(global_pos)) {
                return local;
            }
        }
        return -1;
    };
    for (int i = 0; i < N; ++i) {
        const std::size_t input_index = (offset + static_cast<std::size_t>(i)) % data_.size();
        const std::size_t target_index =
            (offset + static_cast<std::size_t>(i) + 1U) % data_.size();
        window.inputs[static_cast<std::size_t>(i)] = data_[input_index];
        window.targets[static_cast<std::size_t>(i)] = data_[target_index];
        if (!route_hint_present_.empty() && route_hint_present_[input_index]) {
            int value_pos = -1;
            const int global_value_pos = route_hint_value_positions_[input_index];
            if (global_value_pos >= 0) {
                value_pos = local_position(global_value_pos);
            }
            std::vector<int> candidate_value_positions;
            for (const int global_candidate_pos :
                 route_hint_candidate_value_positions_[input_index]) {
                if (global_candidate_pos < 0) {
                    continue;
                }
                const int local_candidate_pos = local_position(global_candidate_pos);
                if (local_candidate_pos >= 0) {
                    candidate_value_positions.push_back(local_candidate_pos);
                }
            }
            window.route_hints.push_back(RouteHint{
                i,
                value_pos,
                route_hint_values_[input_index],
                route_hint_weights_[input_index],
                candidate_value_positions,
            });
        }
        if (!kv_record_present_.empty() && kv_record_present_[input_index]) {
            ++window.kv_record_count;
            if (kv_duplicate_record_present_[input_index]) {
                ++window.kv_duplicate_key_count;
            }
            const int local_value_pos =
                local_position(kv_record_value_positions_[input_index]);
            if (local_value_pos >= 0) {
                window.kv_records.push_back(KVRecord{
                    kv_record_keys_[input_index],
                    i,
                    local_value_pos,
                    kv_record_values_[input_index],
                });
            }
        }
        if (!kv_query_present_.empty() && kv_query_present_[input_index]) {
            ++window.kv_query_count;
            if (kv_query_hit_[input_index]) {
                ++window.kv_query_hit_count;
            } else {
                ++window.kv_missing_key_count;
            }
            const int local_value_pos =
                local_position(kv_query_value_positions_[input_index]);
            window.kv_queries.push_back(KVQuery{
                kv_query_keys_[input_index],
                i,
                local_value_pos,
                kv_query_values_[input_index],
                kv_query_hit_[input_index] && local_value_pos >= 0,
            });
        }
        if (!route_candidate_query_present_.empty() &&
            route_candidate_query_present_[input_index]) {
            ++window.route_candidate_query_count;
            window.route_bucket_load_sum += route_bucket_load_[input_index];
            window.route_bucket_load_max =
                std::max(window.route_bucket_load_max, route_bucket_load_[input_index]);
            if (route_bucket_collision_[input_index]) {
                ++window.route_bucket_collision_count;
            }
            if (route_candidate_hit_[input_index]) {
                ++window.route_candidate_hit_count;
                window.route_candidate_rank_sum +=
                    static_cast<double>(route_candidate_rank_[input_index]);
                if (route_candidate_rank_[input_index] == 1) {
                    ++window.route_candidate_top1_hit_count;
                }
            }
        }
    }

    return window;
}

std::uint8_t ByteDataset::oracle_next(std::uint8_t x) const { return oracle_next_[x]; }

void ByteDataset::build_counter() {
    data_.resize(256);
    for (int i = 0; i < 256; ++i) {
        data_[static_cast<std::size_t>(i)] = static_cast<std::uint8_t>(i);
    }
}

void ByteDataset::build_repeating_text() {
    static const char* kText = "the quick brown fox jumps over the lazy dog. ";
    for (const char* ptr = kText; *ptr != '\0'; ++ptr) {
        data_.push_back(static_cast<std::uint8_t>(*ptr));
    }
}

void ByteDataset::load_input_file(const std::string& path) {
    std::ifstream input(path, std::ios::binary);
    if (!input) {
        throw std::runtime_error("failed to open input file: " + path);
    }

    char byte = 0;
    while (input.get(byte)) {
        data_.push_back(static_cast<std::uint8_t>(static_cast<unsigned char>(byte)));
    }

    if (data_.empty()) {
        throw std::runtime_error("input file is empty: " + path);
    }
}

void ByteDataset::build_oracle() {
    for (std::size_t t = 0; t < data_.size(); ++t) {
        const auto x = data_[t];
        const auto y = data_[(t + 1U) % data_.size()];
        ++counts_[x][y];
    }

    for (int x = 0; x < 256; ++x) {
        std::uint32_t best_count = counts_[static_cast<std::size_t>(x)][0];
        int best_y = 0;
        for (int y = 1; y < 256; ++y) {
            const auto candidate = counts_[static_cast<std::size_t>(x)][static_cast<std::size_t>(y)];
            if (candidate > best_count) {
                best_count = candidate;
                best_y = y;
            }
        }
        oracle_next_[static_cast<std::size_t>(x)] = static_cast<std::uint8_t>(best_y);
    }
}

void ByteDataset::build_route_hints() {
    route_hint_present_.assign(data_.size(), false);
    route_hint_values_.assign(data_.size(), 0);
    route_hint_value_positions_.assign(data_.size(), -1);
    route_hint_candidate_value_positions_.assign(data_.size(), {});
    route_hint_weights_.assign(data_.size(), 0.0f);
    kv_record_present_.assign(data_.size(), false);
    kv_duplicate_record_present_.assign(data_.size(), false);
    kv_record_keys_.assign(data_.size(), std::string{});
    kv_record_value_positions_.assign(data_.size(), -1);
    kv_record_values_.assign(data_.size(), 0);
    kv_query_present_.assign(data_.size(), false);
    kv_query_hit_.assign(data_.size(), false);
    kv_query_keys_.assign(data_.size(), std::string{});
    kv_query_value_positions_.assign(data_.size(), -1);
    kv_query_values_.assign(data_.size(), 0);
    route_candidate_query_present_.assign(data_.size(), false);
    route_candidate_hit_.assign(data_.size(), false);
    route_candidate_rank_.assign(data_.size(), 0);
    route_bucket_load_.assign(data_.size(), 0);
    route_bucket_collision_.assign(data_.size(), false);

    struct RecordValue {
        std::uint8_t value = 0;
        int value_pos = -1;
        std::vector<std::uint8_t> span_values;
    };
    struct BucketEntry {
        std::string key;
        std::uint8_t value = 0;
        int value_pos = -1;
        int span_offset = 0;
    };
    std::unordered_map<std::string, RecordValue> record_values;
    std::unordered_map<std::uint32_t, std::vector<BucketEntry>> hash_buckets;
    const auto value_end = [&](std::size_t start) {
        std::size_t end = start;
        while (end < data_.size() &&
               data_[end] != static_cast<std::uint8_t>(';') &&
               data_[end] != static_cast<std::uint8_t>('.') &&
               !std::isspace(static_cast<unsigned char>(data_[end]))) {
            ++end;
        }
        return end;
    };
    const auto apply_hash_candidates =
        [&](std::size_t query_pos,
            const std::string& key,
            int correct_value_pos,
            int span_offset_filter) {
            if (query_pos >= data_.size()) {
                return;
            }
            route_candidate_query_present_[query_pos] = true;
            const auto bucket_key = stable_key_hash(key, params_.route_hash_bits);
            const auto bucket_found = hash_buckets.find(bucket_key);
            if (bucket_found == hash_buckets.end() || bucket_found->second.empty()) {
                return;
            }

            bool has_other_key = false;
            std::vector<const BucketEntry*> ordered_bucket;
            ordered_bucket.reserve(bucket_found->second.size());
            for (const auto& entry : bucket_found->second) {
                if (span_offset_filter >= 0 && entry.span_offset != span_offset_filter) {
                    continue;
                }
                if (entry.key != key) {
                    has_other_key = true;
                }
                ordered_bucket.push_back(&entry);
            }
            if (ordered_bucket.empty()) {
                return;
            }

            route_bucket_load_[query_pos] = static_cast<int>(ordered_bucket.size());
            route_bucket_collision_[query_pos] = has_other_key;

            const int candidate_limit =
                std::min(params_.K_route, static_cast<int>(ordered_bucket.size()));
            std::stable_sort(
                ordered_bucket.begin(),
                ordered_bucket.end(),
                [&](const BucketEntry* lhs, const BucketEntry* rhs) {
                    const auto latest_first = [&]() {
                        return lhs->value_pos > rhs->value_pos;
                    };
                    if (params_.route_candidate_score == "key-shape") {
                        const double lhs_score = key_shape_score(key, lhs->key);
                        const double rhs_score = key_shape_score(key, rhs->key);
                        if (lhs_score != rhs_score) {
                            return lhs_score > rhs_score;
                        }
                    }
                    return latest_first();
                });

            bool selected = false;
            for (int rank = 1; rank <= candidate_limit; ++rank) {
                const auto& entry = *ordered_bucket[static_cast<std::size_t>(rank - 1)];
                if (!selected) {
                    route_hint_present_[query_pos] = true;
                    route_hint_values_[query_pos] = entry.value;
                    route_hint_value_positions_[query_pos] = entry.value_pos;
                    route_hint_weights_[query_pos] = 1.0f;
                    selected = true;
                }
                route_hint_candidate_value_positions_[query_pos].push_back(entry.value_pos);
                if (correct_value_pos >= 0 && entry.value_pos == correct_value_pos) {
                    route_candidate_hit_[query_pos] = true;
                    route_candidate_rank_[query_pos] = rank;
                    break;
                }
            }
        };
    for (std::size_t i = 0; i < data_.size(); ++i) {
        const bool is_record = data_[i] == static_cast<std::uint8_t>('@');
        const bool is_query = data_[i] == static_cast<std::uint8_t>('?');
        if (!is_record && !is_query) {
            continue;
        }

        std::size_t pos = i + 1U;
        std::string key;
        while (pos < data_.size() && data_[pos] != static_cast<std::uint8_t>('=') &&
               !std::isspace(static_cast<unsigned char>(data_[pos])) &&
               data_[pos] != static_cast<std::uint8_t>(';')) {
            key.push_back(static_cast<char>(data_[pos]));
            ++pos;
        }
        if (key.empty() || pos >= data_.size() ||
            data_[pos] != static_cast<std::uint8_t>('=')) {
            continue;
        }

        if (is_record) {
            const std::size_t record_value_start = pos + 1U;
            const std::size_t record_value_end = value_end(record_value_start);
            if (record_value_start >= record_value_end) {
                continue;
            }
            std::vector<std::uint8_t> span_values;
            span_values.reserve(record_value_end - record_value_start);
            for (std::size_t value_index = record_value_start;
                 value_index < record_value_end;
                 ++value_index) {
                span_values.push_back(data_[value_index]);
            }
            kv_record_present_[i] = true;
            if (record_values.find(key) != record_values.end()) {
                kv_duplicate_record_present_[i] = true;
            }
            kv_record_keys_[i] = key;
            kv_record_value_positions_[i] = static_cast<int>(record_value_start);
            kv_record_values_[i] = data_[record_value_start];
            record_values[key] = RecordValue{
                data_[record_value_start],
                static_cast<int>(record_value_start),
                span_values,
            };
            if (params_.route_mode == "hint-kv-hash") {
                const auto bucket_key = stable_key_hash(key, params_.route_hash_bits);
                if (params_.route_span_hints != 0) {
                    for (std::size_t offset = 0; offset < span_values.size(); ++offset) {
                        hash_buckets[bucket_key].push_back(BucketEntry{
                            key,
                            span_values[offset],
                            static_cast<int>(record_value_start + offset),
                            static_cast<int>(offset),
                        });
                    }
                } else {
                    hash_buckets[bucket_key].push_back(BucketEntry{
                        key,
                        data_[record_value_start],
                        static_cast<int>(record_value_start),
                        0,
                    });
                }
            }
            continue;
        }

        const auto found = record_values.find(key);
        const std::size_t query_value_start = pos + 1U;
        const std::size_t query_value_end = value_end(query_value_start);
        const std::size_t query_value_len =
            query_value_end > query_value_start ? query_value_end - query_value_start : 0U;
        const bool span_exact_active =
            params_.route_span_hints != 0 && params_.route_mode == "hint-kv-exact" &&
            found != record_values.end() && query_value_len > 0U;
        if (span_exact_active) {
            const std::size_t span_len =
                std::min(query_value_len, found->second.span_values.size());
            for (std::size_t offset = 0; offset < span_len; ++offset) {
                const std::size_t query_pos = pos + offset;
                const int value_pos = found->second.value_pos + static_cast<int>(offset);
                if (query_pos >= data_.size() || value_pos < 0 ||
                    value_pos >= static_cast<int>(data_.size())) {
                    continue;
                }
                kv_query_present_[query_pos] = true;
                kv_query_keys_[query_pos] = key;
                kv_query_hit_[query_pos] = true;
                kv_query_value_positions_[query_pos] = value_pos;
                kv_query_values_[query_pos] = found->second.span_values[offset];
                route_hint_present_[query_pos] = true;
                route_hint_values_[query_pos] = found->second.span_values[offset];
                route_hint_value_positions_[query_pos] = value_pos;
                route_hint_weights_[query_pos] = 1.0f;
            }
            continue;
        }

        const bool span_hash_active =
            params_.route_span_hints != 0 && params_.route_mode == "hint-kv-hash" &&
            found != record_values.end() && query_value_len > 0U;
        if (span_hash_active) {
            const std::size_t span_len =
                std::min(query_value_len, found->second.span_values.size());
            for (std::size_t offset = 0; offset < span_len; ++offset) {
                const std::size_t query_pos = pos + offset;
                const int value_pos = found->second.value_pos + static_cast<int>(offset);
                if (query_pos >= data_.size() || value_pos < 0 ||
                    value_pos >= static_cast<int>(data_.size())) {
                    continue;
                }
                kv_query_present_[query_pos] = true;
                kv_query_keys_[query_pos] = key;
                kv_query_hit_[query_pos] = true;
                kv_query_value_positions_[query_pos] = value_pos;
                kv_query_values_[query_pos] = found->second.span_values[offset];
                apply_hash_candidates(
                    query_pos,
                    key,
                    value_pos,
                    static_cast<int>(offset));
            }
            continue;
        }

        kv_query_present_[pos] = true;
        kv_query_keys_[pos] = key;
        if (found != record_values.end()) {
            kv_query_hit_[pos] = true;
            kv_query_value_positions_[pos] = found->second.value_pos;
            kv_query_values_[pos] = found->second.value;
        }

        if (params_.route_mode == "hint-kv-hash") {
            apply_hash_candidates(
                pos,
                key,
                found != record_values.end() ? found->second.value_pos : -1,
                -1);
            continue;
        }

        if (found != record_values.end()) {
            route_hint_present_[pos] = true;
            route_hint_values_[pos] = found->second.value;
            route_hint_value_positions_[pos] = found->second.value_pos;
            route_hint_weights_[pos] = 1.0f;
        }
    }
}

}  // namespace dle
