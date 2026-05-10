#include "v02_pre/GraphV02.hpp"

#include <algorithm>
#include <array>
#include <cctype>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace dle {

namespace {

int wrap_index(int index, int n) {
    const int mod = index % n;
    return mod < 0 ? mod + n : mod;
}

int byte_nibble_hamming(std::uint8_t lhs, std::uint8_t rhs) {
    const int high_mismatch = (lhs / FieldTable::States) != (rhs / FieldTable::States) ? 1 : 0;
    const int low_mismatch = (lhs % FieldTable::States) != (rhs % FieldTable::States) ? 1 : 0;
    return high_mismatch + low_mismatch;
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

bool valid_retry_source_name(const std::string& source) {
    return source == "raw-key" ||
           source == "key-shape" ||
           source == "joint-code-key" ||
           source == "noisy-route-code";
}

std::string trim_ascii(const std::string& value) {
    std::size_t begin = 0;
    while (begin < value.size() &&
           std::isspace(static_cast<unsigned char>(value[begin]))) {
        ++begin;
    }
    std::size_t end = value.size();
    while (end > begin &&
           std::isspace(static_cast<unsigned char>(value[end - 1U]))) {
        --end;
    }
    return value.substr(begin, end - begin);
}

std::vector<std::string> split_source_list(const std::string& csv) {
    std::vector<std::string> sources;
    std::size_t begin = 0;
    while (begin <= csv.size()) {
        const std::size_t comma = csv.find(',', begin);
        const std::size_t end = comma == std::string::npos ? csv.size() : comma;
        std::string source = trim_ascii(csv.substr(begin, end - begin));
        if (!source.empty()) {
            sources.push_back(source);
        }
        if (comma == std::string::npos) {
            break;
        }
        begin = comma + 1U;
    }
    return sources;
}

struct QualityGramStats {
    double logdet = 0.0;
    double logdet_norm = 0.0;
    double condition = 0.0;
};

QualityGramStats candidate_value_gram_stats(
    const std::vector<std::uint8_t>& values,
    double eps) {
    QualityGramStats stats;
    const int k = static_cast<int>(values.size());
    if (k <= 0) {
        return stats;
    }
    std::vector<double> matrix(static_cast<std::size_t>(k * k), 0.0);
    for (int row = 0; row < k; ++row) {
        for (int col = 0; col < k; ++col) {
            const bool hi_match =
                (values[static_cast<std::size_t>(row)] / FieldTable::States) ==
                (values[static_cast<std::size_t>(col)] / FieldTable::States);
            const bool lo_match =
                (values[static_cast<std::size_t>(row)] % FieldTable::States) ==
                (values[static_cast<std::size_t>(col)] % FieldTable::States);
            matrix[static_cast<std::size_t>(row * k + col)] =
                (static_cast<double>(hi_match) + static_cast<double>(lo_match)) / 32.0;
        }
        matrix[static_cast<std::size_t>(row * k + row)] += eps;
    }

    double logdet = 0.0;
    double min_pivot = std::numeric_limits<double>::infinity();
    double max_pivot = 0.0;
    for (int pivot_index = 0; pivot_index < k; ++pivot_index) {
        int best = pivot_index;
        double best_abs =
            std::abs(matrix[static_cast<std::size_t>(pivot_index * k + pivot_index)]);
        for (int row = pivot_index + 1; row < k; ++row) {
            const double candidate =
                std::abs(matrix[static_cast<std::size_t>(row * k + pivot_index)]);
            if (candidate > best_abs) {
                best = row;
                best_abs = candidate;
            }
        }
        if (best != pivot_index) {
            for (int col = 0; col < k; ++col) {
                std::swap(matrix[static_cast<std::size_t>(pivot_index * k + col)],
                          matrix[static_cast<std::size_t>(best * k + col)]);
            }
        }
        const double pivot =
            std::max(std::abs(matrix[static_cast<std::size_t>(pivot_index * k + pivot_index)]),
                     std::numeric_limits<double>::min());
        logdet += std::log(pivot);
        min_pivot = std::min(min_pivot, pivot);
        max_pivot = std::max(max_pivot, pivot);
        for (int row = pivot_index + 1; row < k; ++row) {
            const double factor =
                matrix[static_cast<std::size_t>(row * k + pivot_index)] /
                matrix[static_cast<std::size_t>(pivot_index * k + pivot_index)];
            for (int col = pivot_index + 1; col < k; ++col) {
                matrix[static_cast<std::size_t>(row * k + col)] -=
                    factor * matrix[static_cast<std::size_t>(pivot_index * k + col)];
            }
        }
    }
    stats.logdet = logdet;
    stats.logdet_norm = logdet / static_cast<double>(k);
    if (std::isfinite(min_pivot) && min_pivot > 0.0) {
        stats.condition = max_pivot / min_pivot;
    }
    return stats;
}

std::unordered_map<std::string, float> parse_retry_source_priorities(
    const std::string& csv) {
    std::unordered_map<std::string, float> priorities;
    if (trim_ascii(csv).empty()) {
        return priorities;
    }
    std::size_t begin = 0;
    while (begin <= csv.size()) {
        const std::size_t comma = csv.find(',', begin);
        const std::size_t end = comma == std::string::npos ? csv.size() : comma;
        const std::string entry = trim_ascii(csv.substr(begin, end - begin));
        if (entry.empty()) {
            throw std::runtime_error(
                "route-source-retry-priorities entries must be source:float");
        }
        const std::size_t colon = entry.find(':');
        if (colon == std::string::npos || entry.find(':', colon + 1U) != std::string::npos) {
            throw std::runtime_error(
                "route-source-retry-priorities entries must be source:float");
        }
        const std::string source = trim_ascii(entry.substr(0, colon));
        const std::string value = trim_ascii(entry.substr(colon + 1U));
        if (!valid_retry_source_name(source) || value.empty()) {
            throw std::runtime_error(
                "route-source-retry-priorities entries must use raw-key, key-shape, joint-code-key, or noisy-route-code");
        }
        std::size_t parsed = 0;
        float prior = 0.0f;
        try {
            prior = std::stof(value, &parsed);
        } catch (const std::exception&) {
            throw std::runtime_error(
                "route-source-retry-priorities entries must have finite float values");
        }
        if (parsed != value.size() || !std::isfinite(prior)) {
            throw std::runtime_error(
                "route-source-retry-priorities entries must have finite float values");
        }
        priorities[source] = prior;
        if (comma == std::string::npos) {
            break;
        }
        begin = comma + 1U;
    }
    return priorities;
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

double nearest_rank_quantile(std::vector<double> values, double quantile) {
    if (values.empty()) {
        return 0.0;
    }
    std::sort(values.begin(), values.end());
    const auto rank =
        static_cast<std::size_t>(std::ceil(quantile * static_cast<double>(values.size())));
    return values[std::min(rank > 0 ? rank - 1 : 0, values.size() - 1)];
}

bool route_quality_source_ranking_apply_active(const V02PreParams& params) {
    return (params.route_quality_apply == "source-ranking" ||
            params.route_quality_apply == "source-candidate") &&
           params.route_quality_source_ranking_beta > 0.0f;
}

bool route_quality_candidate_weight_apply_active(const V02PreParams& params) {
    return (params.route_quality_apply == "candidate-weight" ||
            params.route_quality_apply == "source-candidate") &&
           params.route_quality_candidate_weight_beta > 0.0f;
}

bool route_quality_source_proxy_diagnostics_active(const V02PreParams& params) {
    return params.route_quality_diagnostics != 0 ||
           params.route_quality_score != 0 ||
           route_quality_source_ranking_apply_active(params) ||
           route_quality_candidate_weight_apply_active(params);
}

float route_quality_source_ranking_proxy(
    const V02PreParams& params,
    const std::vector<NodeV02>& nodes,
    const std::vector<int>& positions) {
    std::array<int, FieldTable::ByteValues> value_counts{};
    std::array<int, FieldTable::States> hi_counts{};
    std::array<int, FieldTable::States> lo_counts{};
    std::vector<std::uint8_t> values;
    values.reserve(positions.size());
    for (const int value_pos : positions) {
        if (value_pos < 0 || value_pos >= params.N) {
            continue;
        }
        const auto value = nodes[static_cast<std::size_t>(value_pos)].input_byte;
        values.push_back(value);
        ++value_counts[static_cast<std::size_t>(value)];
        ++hi_counts[static_cast<std::size_t>(value / FieldTable::States)];
        ++lo_counts[static_cast<std::size_t>(value % FieldTable::States)];
    }
    const int count = static_cast<int>(values.size());
    if (count <= 0) {
        return 0.0f;
    }
    int top_count = 0;
    int second_count = 0;
    double entropy = 0.0;
    for (const int bucket_count : value_counts) {
        if (bucket_count <= 0) {
            continue;
        }
        if (bucket_count > top_count) {
            second_count = top_count;
            top_count = bucket_count;
        } else if (bucket_count > second_count) {
            second_count = bucket_count;
        }
        const double p = static_cast<double>(bucket_count) / static_cast<double>(count);
        entropy -= p * (std::log(p) / std::log(2.0));
    }
    const int hi_top_count =
        *std::max_element(hi_counts.begin(), hi_counts.end());
    const int lo_top_count =
        *std::max_element(lo_counts.begin(), lo_counts.end());
    const double top_share =
        static_cast<double>(top_count) / static_cast<double>(count);
    const double vote_margin =
        static_cast<double>(top_count - second_count) / static_cast<double>(count);
    const double channel_offdiag =
        std::abs(static_cast<double>(hi_top_count - lo_top_count)) /
        static_cast<double>(count);
    const QualityGramStats gram = candidate_value_gram_stats(
        values,
        static_cast<double>(params.route_quality_eps));
    const double score =
        static_cast<double>(params.route_quality_vote_margin_weight) *
            vote_margin +
        static_cast<double>(params.route_quality_top_share_weight) *
            top_share -
        static_cast<double>(params.route_quality_entropy_weight) *
            entropy -
        static_cast<double>(params.route_quality_logdet_weight) *
            gram.logdet_norm -
        static_cast<double>(params.route_quality_channel_weight) *
            channel_offdiag;
    return static_cast<float>(score);
}

float route_channel_delta(
    const std::string& mode,
    float pull_scale,
    float push_scale,
    std::uint8_t old_state,
    std::uint8_t new_state,
    std::uint8_t target_state) {
    if (mode == "target-only") {
        const float old_match = old_state == target_state ? 1.0f : 0.0f;
        const float new_match = new_state == target_state ? 1.0f : 0.0f;
        return -(new_match - old_match);
    }

    if (new_state == target_state && old_state != target_state) {
        return -pull_scale;
    }
    if (old_state == target_state && new_state != target_state) {
        return push_scale;
    }
    return 0.0f;
}

std::uint32_t fnv1a_update(std::uint32_t hash, std::uint8_t byte) {
    hash ^= static_cast<std::uint32_t>(byte);
    hash *= 16777619u;
    return hash;
}

std::uint32_t mask_hash(std::uint32_t hash, int hash_bits) {
    if (hash_bits >= 32) {
        return hash;
    }
    const auto mask = (1u << static_cast<unsigned>(hash_bits)) - 1u;
    return hash & mask;
}

std::uint32_t hash_string_bucket(const std::string& text, int hash_bits) {
    std::uint32_t hash = 2166136261u;
    for (const unsigned char byte : text) {
        hash = fnv1a_update(hash, static_cast<std::uint8_t>(byte));
    }
    return mask_hash(hash, hash_bits);
}

std::uint32_t deterministic_route_code_hash(
    int seed,
    int index,
    std::uint8_t key_byte,
    std::uint8_t salt) {
    std::uint32_t hash = 2166136261u;
    hash = fnv1a_update(hash, static_cast<std::uint8_t>(seed & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>((seed >> 8) & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>((seed >> 16) & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>((seed >> 24) & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>(index & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>((index >> 8) & 0xff));
    hash = fnv1a_update(hash, key_byte);
    hash = fnv1a_update(hash, salt);
    return hash;
}

double deterministic_route_code_unit(
    int seed,
    int index,
    std::uint8_t key_byte,
    std::uint8_t salt) {
    return static_cast<double>(
               deterministic_route_code_hash(seed, index, key_byte, salt)) /
           4294967296.0;
}

std::uint8_t deterministic_corrupt_byte(
    int seed,
    int index,
    std::uint8_t key_byte,
    std::uint8_t target_byte) {
    const auto hash = deterministic_route_code_hash(seed, index, key_byte, 0xa7U);
    const auto wrong_target =
        static_cast<std::uint8_t>((hash & 1U) == 0U ? 0x00U : 0x0fU);
    if (wrong_target != target_byte) {
        return wrong_target;
    }
    return static_cast<std::uint8_t>(wrong_target ^ 0xf0U);
}

}  // namespace

GraphV02::GraphV02(const V02PreParams& params)
    : params_(params), rng_(static_cast<std::uint32_t>(params.seed)) {
    validate_params();
    field_.initialize(rng_);
    route_field_.initialize(rng_);
    refresh_route_confidence_cache();
    refresh_route_anchor_cache();
}

void GraphV02::begin_epoch(int epoch, const ByteDataset::Window& window) {
    current_epoch_ = epoch;
    if (window.inputs.size() != static_cast<std::size_t>(params_.N) ||
        window.targets.size() != static_cast<std::size_t>(params_.N)) {
        throw std::runtime_error("dataset window size does not match N");
    }

    nodes_.assign(static_cast<std::size_t>(params_.N), {});
    route_keys_.assign(static_cast<std::size_t>(params_.N), 0);
    route_hint_values_.assign(static_cast<std::size_t>(params_.N), 0);
    route_hint_value_positions_.assign(static_cast<std::size_t>(params_.N), -1);
    route_hint_candidate_value_positions_.assign(static_cast<std::size_t>(params_.N), {});
    route_hint_weights_.assign(static_cast<std::size_t>(params_.N), 0.0f);
    route_strength_cache_.assign(static_cast<std::size_t>(params_.N), 0.0f);
    route_hint_correct_value_positions_.assign(static_cast<std::size_t>(params_.N), -1);
    route_hint_corrupted_.assign(static_cast<std::size_t>(params_.N), false);
    route_hint_primary_has_correct_.assign(static_cast<std::size_t>(params_.N), false);
    route_hint_fallback_used_.assign(static_cast<std::size_t>(params_.N), false);
    route_hint_fallback_recovered_.assign(static_cast<std::size_t>(params_.N), false);
    route_hint_retry_used_.assign(static_cast<std::size_t>(params_.N), false);
    route_hint_retry_recovered_.assign(static_cast<std::size_t>(params_.N), false);
    route_hint_quality_source_ranking_delta_.assign(
        static_cast<std::size_t>(params_.N),
        0.0f);
    const float nan = std::numeric_limits<float>::quiet_NaN();
    route_quality_retry_raw_proxy_.assign(static_cast<std::size_t>(params_.N), nan);
    route_quality_retry_keyshape_proxy_.assign(static_cast<std::size_t>(params_.N), nan);
    route_quality_retry_noisy_proxy_.assign(static_cast<std::size_t>(params_.N), nan);
    route_quality_retry_raw_norm_proxy_.assign(
        static_cast<std::size_t>(params_.N),
        nan);
    route_quality_retry_keyshape_norm_proxy_.assign(
        static_cast<std::size_t>(params_.N),
        nan);
    route_quality_retry_noisy_norm_proxy_.assign(
        static_cast<std::size_t>(params_.N),
        nan);
    route_quality_retry_raw_delta_.assign(static_cast<std::size_t>(params_.N), nan);
    route_quality_retry_keyshape_delta_.assign(static_cast<std::size_t>(params_.N), nan);
    route_quality_retry_noisy_delta_.assign(static_cast<std::size_t>(params_.N), nan);
    route_fallback_persist_remaining_.assign(static_cast<std::size_t>(params_.N), 0);
    route_fallback_persist_visits_.assign(static_cast<std::size_t>(params_.N), 0);
    if (route_credit_by_value_pos_.size() != static_cast<std::size_t>(params_.N)) {
        route_credit_by_value_pos_.assign(static_cast<std::size_t>(params_.N), 0.0f);
    }
    route_value_positions_.clear();
    route_value_position_keys_.assign(static_cast<std::size_t>(params_.N), {});
    route_hint_query_keys_.assign(static_cast<std::size_t>(params_.N), {});
    route_hint_candidate_keys_.assign(static_cast<std::size_t>(params_.N), {});
    route_hint_candidate_source_ids_.assign(static_cast<std::size_t>(params_.N), {});
    key_region_mask_.assign(static_cast<std::size_t>(params_.N), false);
    kv_record_count_ = window.kv_record_count;
    kv_duplicate_key_count_ = window.kv_duplicate_key_count;
    kv_query_count_ = window.kv_query_count;
    kv_query_hit_count_ = window.kv_query_hit_count;
    kv_missing_key_count_ = window.kv_missing_key_count;
    route_candidate_query_count_ = window.route_candidate_query_count;
    route_candidate_hit_count_ = window.route_candidate_hit_count;
    route_candidate_top1_hit_count_ = window.route_candidate_top1_hit_count;
    route_candidate_rank_sum_ = window.route_candidate_rank_sum;
    route_bucket_load_sum_ = window.route_bucket_load_sum;
    route_bucket_load_max_ = window.route_bucket_load_max;
    route_bucket_collision_count_ = window.route_bucket_collision_count;
    changed_this_cycle_.assign(static_cast<std::size_t>(params_.N), false);

    for (int i = 0; i < params_.N; ++i) {
        NodeV02& node = nodes_[static_cast<std::size_t>(i)];
        node.input_byte = window.inputs[static_cast<std::size_t>(i)];
        node.target_byte = window.targets[static_cast<std::size_t>(i)];
        node.state[0] = static_cast<std::uint8_t>(node.input_byte / 16U);
        node.state[1] = static_cast<std::uint8_t>(node.input_byte % 16U);
        node.mass = params_.mass_init;
        node.reservoir = 0.0f;
        node.tick = 1.0f;
        node.age_since_change = 0;

        node.neighbors.fill(i);
        int slot = 0;
        for (int offset = -params_.R; offset <= params_.R; ++offset) {
            if (offset == 0) {
                continue;
            }
            node.neighbors[static_cast<std::size_t>(slot++)] = wrap_index(i + offset, params_.N);
        }
    }

    for (const auto& hint : window.route_hints) {
        if (hint.query_pos < 0 || hint.query_pos >= params_.N) {
            continue;
        }
        route_hint_values_[static_cast<std::size_t>(hint.query_pos)] = hint.value_byte;
        route_hint_value_positions_[static_cast<std::size_t>(hint.query_pos)] = hint.value_pos;
        route_hint_candidate_value_positions_[static_cast<std::size_t>(hint.query_pos)] =
            hint.candidate_value_positions;
        route_hint_weights_[static_cast<std::size_t>(hint.query_pos)] = hint.weight;
    }
    for (const auto& record : window.kv_records) {
        if (record.value_pos >= 0 && record.value_pos < params_.N) {
            route_value_positions_.push_back(record.value_pos);
            route_value_position_keys_[static_cast<std::size_t>(record.value_pos)] =
                record.key;
        }
        for (int offset = 0; offset < static_cast<int>(record.key.size()); ++offset) {
            const int pos = record.marker_pos + 1 + offset;
            if (pos >= 0 && pos < params_.N) {
                key_region_mask_[static_cast<std::size_t>(pos)] = true;
            }
        }
    }
    for (const auto& query : window.kv_queries) {
        if (query.query_pos >= 0 && query.query_pos < params_.N && query.hit) {
            route_hint_correct_value_positions_[static_cast<std::size_t>(query.query_pos)] =
                query.value_pos;
        }
        if (query.query_pos >= 0 && query.query_pos < params_.N) {
            route_hint_query_keys_[static_cast<std::size_t>(query.query_pos)] = query.key;
        }
        const int key_start = query.query_pos - static_cast<int>(query.key.size());
        for (int offset = 0; offset < static_cast<int>(query.key.size()); ++offset) {
            const int pos = key_start + offset;
            if (pos >= 0 && pos < params_.N) {
                key_region_mask_[static_cast<std::size_t>(pos)] = true;
            }
        }
    }
    refresh_key_region_diagnostics(window);
    if (learned_code_key_hash_active()) {
        rebuild_learned_code_key_route_hints(window);
    }
    refresh_route_hint_candidate_keys();
    apply_route_candidate_corruption();
    refresh_route_hint_candidate_sources();
    apply_route_fallback_source(window);
    apply_route_noisy_source(window);
    if (params_.route_fallback_persist_cycles > 0) {
        for (int index = 0; index < params_.N; ++index) {
            if (route_hint_fallback_used_[static_cast<std::size_t>(index)]) {
                route_fallback_persist_remaining_[static_cast<std::size_t>(index)] =
                    params_.route_fallback_persist_cycles;
            }
        }
    }

    refresh_route_confidence_cache();
    refresh_route_anchor_cache();

    if (params_.route_refresh == "epoch") {
        rebuild_routing_table();
    } else {
        std::fill(route_keys_.begin(), route_keys_.end(), 0);
        routing_.clear();
    }
}

EpochMetricsV02 GraphV02::run_epoch(
    int epoch,
    const std::array<std::uint8_t, FieldTable::ByteValues>& oracle_next) {
    int accepted = 0;
    int downhill = 0;
    int uphill = 0;
    int rejected = 0;
    int skipped = 0;

    for (int cycle = 0; cycle < params_.cycles_per_epoch; ++cycle) {
        std::fill(changed_this_cycle_.begin(), changed_this_cycle_.end(), false);
        if (params_.route_refresh == "cycle") {
            rebuild_routing_table();
        }
        refresh_route_strength_cache();

        for (int color = 0; color < params_.C_colors; ++color) {
            for (int index = color; index < params_.N; index += params_.C_colors) {
                try_update_node(index, accepted, downhill, uphill, rejected, skipped);
            }
        }

        for (int& remaining : route_fallback_persist_remaining_) {
            if (remaining > 0) {
                --remaining;
            }
        }

        relax_tick_and_reservoir();
        update_age();
    }

    if (route_credit_learn_active() || route_source_credit_active()) {
        apply_route_credit_learning();
    }

    return collect_metrics(epoch, oracle_next, accepted, downhill, uphill, rejected, skipped);
}

void GraphV02::apply_contrastive_learning() {
    for (int index = 0; index < params_.N; ++index) {
        const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
        for (int channel = 0; channel < params_.channels; ++channel) {
            const auto pos = positive_state(index, channel);
            const auto neg = node.state[static_cast<std::size_t>(channel)];
            if (pos == neg) {
                continue;
            }
            field_.add(channel, node.input_byte, pos, params_.eta_h);
            field_.add(channel, node.input_byte, neg, -params_.eta_h);
        }

        const auto pos_high = positive_state(index, 0);
        const auto pos_low = positive_state(index, 1);
        const auto neg_high = node.state[0];
        const auto neg_low = node.state[1];
        if (pos_high != neg_high || pos_low != neg_low) {
            coupling_.add(node.input_byte, pos_high, pos_low, params_.eta_b);
            coupling_.add(node.input_byte, neg_high, neg_low, -params_.eta_b);
            coupling_has_signal_ = true;
        }
        if (params_.route_code_aux != 0 &&
            (params_.route_code_key_region_only == 0 ||
             key_region_mask_[static_cast<std::size_t>(index)]) &&
            route_code_aux_kept(index, node.input_byte)) {
            const auto target =
                route_code_aux_target(index, node.input_byte, node.input_byte);
            const auto id_high = static_cast<std::uint8_t>(target / FieldTable::States);
            const auto id_low = static_cast<std::uint8_t>(target % FieldTable::States);
            const float delta = params_.eta_route_code * params_.lambda_route_code_id;
            route_field_.add(0, node.input_byte, id_high, delta);
            route_field_.add(1, node.input_byte, id_low, delta);
        }
    }

    field_.decay(params_.eta_h, params_.lambda_h);
    field_.clip(params_.H_clip);
    route_field_.clip(params_.H_clip);
    refresh_route_confidence_cache();
    refresh_route_anchor_cache();
}

void GraphV02::validate_params() const {
    const auto valid_hint_agg = [](const std::string& agg) {
        return agg == "top1" || agg == "vote" || agg == "weighted-vote";
    };

    if (params_.N <= 0) {
        throw std::runtime_error("N must be positive");
    }
    if (params_.S != FieldTable::States) {
        throw std::runtime_error("v0.2-pre reference requires S = 16");
    }
    if (params_.channels != FieldTable::Channels) {
        throw std::runtime_error("v0.2-pre reference requires channels = 2");
    }
    if (params_.R < 1 || params_.R > 4) {
        throw std::runtime_error("R must be in [1, 4] for the reference ring graph");
    }
    if (params_.K != 2 * params_.R) {
        throw std::runtime_error("K must equal 2 * R in the reference ring graph");
    }
    if (params_.K < 2 || params_.K > 8) {
        throw std::runtime_error("K must be in [2, 8]");
    }
    if (params_.C_colors <= 2 * params_.R) {
        throw std::runtime_error("C_colors must be greater than 2 * R for a safe color schedule");
    }
    if (params_.proposal_count <= 0) {
        throw std::runtime_error("proposal_count must be positive");
    }
    if (params_.K_jump < 0 || params_.K_jump > RoutingTable::MaxJump) {
        throw std::runtime_error("K-jump must be in [0, 8]");
    }
    if (params_.route_reservoir_threshold < 0.0f) {
        throw std::runtime_error("route-reservoir-threshold must be non-negative");
    }
    if (params_.route_min_anchor_gap < 0.0f && params_.route_min_anchor_gap != -1.0f) {
        throw std::runtime_error(
            "route-min-anchor-gap must be non-negative, or -1 to follow lambda_u");
    }
    if (params_.route_adaptive_gap_scale < 0.0f) {
        throw std::runtime_error("route-adaptive-gap-scale must be non-negative");
    }
    if (params_.route_confidence_gap_scale < 0.0f) {
        throw std::runtime_error("route-confidence-gap-scale must be non-negative");
    }
    if (params_.route_accept_confidence_gain < 0.0f) {
        throw std::runtime_error("route-accept-confidence-gain must be non-negative");
    }
    if (params_.lambda_route < 0.0f) {
        throw std::runtime_error("lambda-route must be non-negative");
    }
    if (params_.route_strength_mode != "fixed" && params_.route_strength_mode != "margin") {
        throw std::runtime_error("route-strength-mode must be one of: fixed, margin");
    }
    if (params_.lambda_route_base < 0.0f) {
        throw std::runtime_error("lambda-route-base must be non-negative");
    }
    if (params_.lambda_route_max < 0.0f) {
        throw std::runtime_error("lambda-route-max must be non-negative");
    }
    if (params_.route_margin_alpha < 0.0f) {
        throw std::runtime_error("route-margin-alpha must be non-negative");
    }
    if (params_.route_confidence_power < 0.0f) {
        throw std::runtime_error("route-confidence-power must be non-negative");
    }
    if (params_.route_min_confidence < 0.0f || params_.route_min_confidence > 1.0f) {
        throw std::runtime_error("route-min-confidence must be in [0, 1]");
    }
    if (params_.route_corrupt_candidate_rate < 0.0f ||
        params_.route_corrupt_candidate_rate > 1.0f) {
        throw std::runtime_error("route-corrupt-candidate-rate must be in [0, 1]");
    }
    if (params_.route_noisy_source_rate < 0.0f ||
        params_.route_noisy_source_rate > 1.0f) {
        throw std::runtime_error("route-noisy-source-rate must be in [0, 1]");
    }
    if (params_.route_corrupt_confidence != "keep" &&
        params_.route_corrupt_confidence != "low") {
        throw std::runtime_error("route-corrupt-confidence must be one of: keep, low");
    }
    if (params_.route_corrupt_confidence_value < 0.0f ||
        params_.route_corrupt_confidence_value > 1.0f) {
        throw std::runtime_error("route-corrupt-confidence-value must be in [0, 1]");
    }
    if (params_.route_corrupt_preserve_correct < 0 ||
        params_.route_corrupt_preserve_correct > 1) {
        throw std::runtime_error("route-corrupt-preserve-correct must be 0 or 1");
    }
    if (params_.route_strength_confidence != "weight" &&
        params_.route_strength_confidence != "value-support" &&
        params_.route_strength_confidence != "agreement") {
        throw std::runtime_error(
            "route-strength-confidence must be one of: weight, value-support, agreement");
    }
    if (params_.route_confidence_threshold < 0.0f ||
        params_.route_confidence_threshold > 1.0f) {
        throw std::runtime_error("route-confidence-threshold must be in [0, 1]");
    }
    if (params_.route_lowconf_policy != "aggregate" &&
        params_.route_lowconf_policy != "none" &&
        params_.route_lowconf_policy != "weak-vote") {
        throw std::runtime_error(
            "route-lowconf-policy must be one of: aggregate, none, weak-vote");
    }
    if (params_.route_lowconf_weak_scale < 0.0f ||
        params_.route_lowconf_weak_scale > 1.0f) {
        throw std::runtime_error("route-lowconf-weak-scale must be in [0, 1]");
    }
    if (!valid_hint_agg(params_.route_lowconf_agg)) {
        throw std::runtime_error("route-lowconf-agg must be one of: top1, vote, weighted-vote");
    }
    if (!valid_hint_agg(params_.route_highconf_agg)) {
        throw std::runtime_error("route-highconf-agg must be one of: top1, vote, weighted-vote");
    }
    if (params_.route_aggregation_confidence != "value-support" &&
        params_.route_aggregation_confidence != "agreement") {
        throw std::runtime_error(
            "route-aggregation-confidence must be one of: value-support, agreement");
    }
    if (params_.route_fallback_source != "off" &&
        params_.route_fallback_source != "raw-key" &&
        params_.route_fallback_source != "key-shape" &&
        params_.route_fallback_source != "joint-code-key" &&
        params_.route_fallback_source != "noisy-route-code") {
        throw std::runtime_error(
            "route-fallback-source must be one of: off, raw-key, key-shape, joint-code-key, noisy-route-code");
    }
    if (params_.route_fallback_strength_mode != "fixed" &&
        params_.route_fallback_strength_mode != "margin") {
        throw std::runtime_error(
            "route-fallback-strength-mode must be one of: fixed, margin");
    }
    if (params_.route_fallback_strength_mult < 0.0f) {
        throw std::runtime_error("route-fallback-strength-mult must be non-negative");
    }
    if (params_.route_fallback_hi_strength_mult < 0.0f) {
        throw std::runtime_error("route-fallback-hi-strength-mult must be non-negative");
    }
    if (params_.route_fallback_lo_strength_mult < 0.0f) {
        throw std::runtime_error("route-fallback-lo-strength-mult must be non-negative");
    }
    if (params_.route_fallback_channel_strength_mode != "fixed" &&
        params_.route_fallback_channel_strength_mode != "margin") {
        throw std::runtime_error(
            "route-fallback-channel-strength-mode must be one of: fixed, margin");
    }
    if (params_.route_fallback_lambda_base < 0.0f) {
        throw std::runtime_error("route-fallback-lambda-base must be non-negative");
    }
    if (params_.route_fallback_lambda_max < 0.0f) {
        throw std::runtime_error("route-fallback-lambda-max must be non-negative");
    }
    if (params_.route_fallback_margin_alpha < 0.0f) {
        throw std::runtime_error("route-fallback-margin-alpha must be non-negative");
    }
    if (params_.route_fallback_hi_lambda_base < 0.0f ||
        params_.route_fallback_lo_lambda_base < 0.0f) {
        throw std::runtime_error("route-fallback channel lambda bases must be non-negative");
    }
    if (params_.route_fallback_hi_lambda_max < 0.0f ||
        params_.route_fallback_lo_lambda_max < 0.0f) {
        throw std::runtime_error("route-fallback channel lambda max values must be non-negative");
    }
    if (params_.route_fallback_hi_margin_alpha < 0.0f ||
        params_.route_fallback_lo_margin_alpha < 0.0f) {
        throw std::runtime_error("route-fallback channel margin alphas must be non-negative");
    }
    if (params_.route_fallback_persist_cycles < 0) {
        throw std::runtime_error("route-fallback-persist-cycles must be non-negative");
    }
    if (params_.route_credit_learning < 0 || params_.route_credit_learning > 1) {
        throw std::runtime_error("route-credit-learning must be 0 or 1");
    }
    if (params_.route_credit_mode != "off" &&
        params_.route_credit_mode != "value-pos" &&
        params_.route_credit_mode != "query-value") {
        throw std::runtime_error(
            "route-credit-mode must be one of: off, value-pos, query-value");
    }
    if (params_.route_credit_score_weight < 0.0f) {
        throw std::runtime_error("route-credit-score-weight must be non-negative");
    }
    if (params_.route_credit_eta_reward < 0.0f ||
        params_.route_credit_eta_slash < 0.0f) {
        throw std::runtime_error("route-credit eta values must be non-negative");
    }
    if (params_.route_credit_decay < 0.0f || params_.route_credit_decay > 1.0f) {
        throw std::runtime_error("route-credit-decay must be in [0, 1]");
    }
    if (params_.route_credit_clip < 0.0f) {
        throw std::runtime_error("route-credit-clip must be non-negative");
    }
    if (params_.route_source_credit_learning < 0 ||
        params_.route_source_credit_learning > 1) {
        throw std::runtime_error("route-source-credit-learning must be 0 or 1");
    }
    if (params_.route_source_credit_apply_mode != "off" &&
        params_.route_source_credit_apply_mode != "ranking" &&
        params_.route_source_credit_apply_mode != "strength" &&
        params_.route_source_credit_apply_mode != "ranking-strength") {
        throw std::runtime_error(
            "route-source-credit-apply-mode must be one of: off, ranking, strength, ranking-strength");
    }
    if (params_.route_source_credit_score_weight < 0.0f) {
        throw std::runtime_error("route-source-credit-score-weight must be non-negative");
    }
    if (params_.route_source_credit_eta_reward < 0.0f ||
        params_.route_source_credit_eta_slash < 0.0f) {
        throw std::runtime_error("route-source-credit eta values must be non-negative");
    }
    if (params_.route_source_credit_decay < 0.0f ||
        params_.route_source_credit_decay > 1.0f) {
        throw std::runtime_error("route-source-credit-decay must be in [0, 1]");
    }
    if (params_.route_source_credit_clip < 0.0f) {
        throw std::runtime_error("route-source-credit-clip must be non-negative");
    }
    if (params_.route_source_filter_mode != "off" &&
        params_.route_source_filter_mode != "negative-credit") {
        throw std::runtime_error(
            "route-source-filter-mode must be one of: off, negative-credit");
    }
    if (params_.route_source_retry_source != "off" &&
        !valid_retry_source_name(params_.route_source_retry_source)) {
        throw std::runtime_error(
            "route-source-retry-source must be one of: off, raw-key, key-shape, joint-code-key, noisy-route-code");
    }
    if (params_.route_source_retry_policy != "fixed" &&
        params_.route_source_retry_policy != "source-credit") {
        throw std::runtime_error(
            "route-source-retry-policy must be one of: fixed, source-credit");
    }
    if (params_.route_source_retry_tiebreak != "source-order" &&
        params_.route_source_retry_tiebreak != "source-prior") {
        throw std::runtime_error(
            "route-source-retry-tiebreak must be one of: source-order, source-prior");
    }
    parse_retry_source_priorities(params_.route_source_retry_priorities);
    if (params_.route_source_retry_prior_mode != "none" &&
        params_.route_source_retry_prior_mode != "static" &&
        params_.route_source_retry_prior_mode != "decay" &&
        params_.route_source_retry_prior_mode != "warmup") {
        throw std::runtime_error(
            "route-source-retry-prior-mode must be one of: none, static, decay, warmup");
    }
    if (params_.route_source_retry_prior_decay < 0.0f ||
        params_.route_source_retry_prior_decay > 1.0f) {
        throw std::runtime_error("route-source-retry-prior-decay must be in [0, 1]");
    }
    if (params_.route_source_retry_prior_warmup_epochs < 0) {
        throw std::runtime_error(
            "route-source-retry-prior-warmup-epochs must be non-negative");
    }
    if (params_.route_source_retry_per_source_limit <= 0) {
        throw std::runtime_error("route-source-retry-per-source-limit must be positive");
    }
    for (const std::string& source :
         split_source_list(params_.route_source_retry_candidates)) {
        if (!valid_retry_source_name(source)) {
            throw std::runtime_error(
                "route-source-retry-candidates entries must be one of: raw-key, key-shape, joint-code-key, noisy-route-code");
        }
    }
    if (params_.route_source_retry_policy == "source-credit" &&
        split_source_list(params_.route_source_retry_candidates).empty()) {
        throw std::runtime_error(
            "route-source-retry-candidates must be non-empty when route-source-retry-policy=source-credit");
    }
    if (params_.route_quality_diagnostics < 0 ||
        params_.route_quality_diagnostics > 1) {
        throw std::runtime_error("route-quality-diagnostics must be 0 or 1");
    }
    if (params_.route_quality_feature_set != "value-only" &&
        params_.route_quality_feature_set != "dynamics" &&
        params_.route_quality_feature_set != "full") {
        throw std::runtime_error(
            "route-quality-feature-set must be one of: value-only, dynamics, full");
    }
    if (params_.route_quality_feature_set != "value-only") {
        throw std::runtime_error(
            "h5-u only supports route-quality-feature-set=value-only");
    }
    if (params_.route_quality_apply != "none" &&
        params_.route_quality_apply != "candidate-weight" &&
        params_.route_quality_apply != "source-ranking" &&
        params_.route_quality_apply != "source-candidate" &&
        params_.route_quality_apply != "strength") {
        throw std::runtime_error(
            "route-quality-apply must be one of: none, candidate-weight, source-ranking, source-candidate, strength");
    }
    if (params_.route_quality_apply == "strength") {
        throw std::runtime_error(
            "route-quality-apply=strength is reserved; use none, candidate-weight, or source-ranking");
    }
    if ((params_.route_quality_apply == "source-ranking" ||
         params_.route_quality_apply == "source-candidate") &&
        params_.route_source_retry_policy != "source-credit") {
        throw std::runtime_error(
            "route-quality-apply=source-ranking/source-candidate requires route-source-retry-policy=source-credit");
    }
    if (!std::isfinite(params_.route_quality_source_ranking_beta) ||
        params_.route_quality_source_ranking_beta < 0.0f) {
        throw std::runtime_error(
            "route-quality-source-ranking-beta must be finite and non-negative");
    }
    if (!std::isfinite(params_.route_quality_candidate_weight_beta) ||
        params_.route_quality_candidate_weight_beta < 0.0f) {
        throw std::runtime_error(
            "route-quality-candidate-weight-beta must be finite and non-negative");
    }
    if (!std::isfinite(params_.route_quality_candidate_weight_min) ||
        params_.route_quality_candidate_weight_min <= 0.0f) {
        throw std::runtime_error(
            "route-quality-candidate-weight-min must be finite and positive");
    }
    if (!std::isfinite(params_.route_quality_candidate_weight_max) ||
        params_.route_quality_candidate_weight_max <
            params_.route_quality_candidate_weight_min) {
        throw std::runtime_error(
            "route-quality-candidate-weight-max must be finite and >= min");
    }
    if (params_.route_quality_candidate_weight_basis != "base" &&
        params_.route_quality_candidate_weight_basis != "quality-score") {
        throw std::runtime_error(
            "route-quality-candidate-weight-basis must be one of: base, quality-score");
    }
    if (params_.route_quality_source_normalization != "none" &&
        params_.route_quality_source_normalization != "center" &&
        params_.route_quality_source_normalization != "zscore") {
        throw std::runtime_error(
            "route-quality-source-normalization must be one of: none, center, zscore");
    }
    if (!std::isfinite(params_.route_quality_source_norm_eps) ||
        params_.route_quality_source_norm_eps <= 0.0f) {
        throw std::runtime_error(
            "route-quality-source-norm-eps must be finite and positive");
    }
    if (params_.route_quality_eps <= 0.0f) {
        throw std::runtime_error("route-quality-eps must be positive");
    }
    if (params_.route_channel_tension_diagnostics < 0 ||
        params_.route_channel_tension_diagnostics > 1) {
        throw std::runtime_error("route-channel-tension-diagnostics must be 0 or 1");
    }
    if (params_.route_channel_tension_mode != "margin") {
        throw std::runtime_error("route-channel-tension-mode must be margin");
    }
    if (params_.route_quality_score < 0 || params_.route_quality_score > 1) {
        throw std::runtime_error("route-quality-score must be 0 or 1");
    }
    if (params_.route_plasticity_ledger < 0 ||
        params_.route_plasticity_ledger > 1) {
        throw std::runtime_error("route-plasticity-ledger must be 0 or 1");
    }
    if (params_.route_plasticity_ledger_decay < 0.0f ||
        params_.route_plasticity_ledger_decay > 1.0f) {
        throw std::runtime_error("route-plasticity-ledger-decay must be in [0, 1]");
    }
    if (params_.route_credit_learn_after_epoch < 0 ||
        params_.route_credit_apply_after_epoch < 0) {
        throw std::runtime_error("route-credit epoch gates must be non-negative");
    }
    if (params_.K_route <= 0) {
        throw std::runtime_error("K-route must be positive");
    }
    if (params_.route_hash_bits < 1 || params_.route_hash_bits > 30) {
        throw std::runtime_error("route-hash-bits must be in [1, 30]");
    }
    if (params_.route_hash_source != "raw-key" &&
        params_.route_hash_source != "joint-code-key" &&
        params_.route_hash_source != "route-code-key") {
        throw std::runtime_error(
            "route-hash-source must be one of: raw-key, joint-code-key, route-code-key");
    }
    if (params_.route_code_aux < 0 || params_.route_code_aux > 1) {
        throw std::runtime_error("route-code-aux must be 0 or 1");
    }
    if (params_.route_code_key_region_only < 0 ||
        params_.route_code_key_region_only > 1) {
        throw std::runtime_error("route-code-key-region-only must be 0 or 1");
    }
    if (params_.route_code_key_region_keep_prob < 0.0f ||
        params_.route_code_key_region_keep_prob > 1.0f) {
        throw std::runtime_error("route-code-key-region-keep-prob must be in [0, 1]");
    }
    if (params_.route_code_aux_noise_rate < 0.0f ||
        params_.route_code_aux_noise_rate > 1.0f) {
        throw std::runtime_error("route-code-aux-noise-rate must be in [0, 1]");
    }
    if (params_.eta_route_code < 0.0f) {
        throw std::runtime_error("eta-route-code must be non-negative");
    }
    if (params_.lambda_route_code_id < 0.0f) {
        throw std::runtime_error("lambda-route-code-id must be non-negative");
    }
    if (params_.route_target_proposals < 0 || params_.route_target_proposals > 1) {
        throw std::runtime_error("route-target-proposals must be 0 or 1");
    }
    if (!valid_hint_agg(params_.route_hint_agg) &&
        params_.route_hint_agg != "confidence-gated") {
        throw std::runtime_error(
            "route-hint-agg must be one of: top1, vote, weighted-vote, confidence-gated");
    }
    if (params_.route_delta_mode != "target-only" &&
        params_.route_delta_mode != "projected") {
        throw std::runtime_error("route-delta-mode must be one of: target-only, projected");
    }
    if (params_.route_pull_scale < 0.0f) {
        throw std::runtime_error("route-pull-scale must be non-negative");
    }
    if (params_.route_push_scale < 0.0f) {
        throw std::runtime_error("route-push-scale must be non-negative");
    }
    if (params_.route_candidate_score != "insertion" &&
        params_.route_candidate_score != "recency" &&
        params_.route_candidate_score != "value-vote" &&
        params_.route_candidate_score != "key-shape") {
        throw std::runtime_error(
            "route-candidate-score must be one of: insertion, recency, value-vote, key-shape");
    }
    if (params_.routing_source != "none" && params_.routing_source != "input-byte" &&
        params_.routing_source != "joint-code" && params_.routing_source != "state-code") {
        throw std::runtime_error(
            "route-source must be one of: none, input-byte, joint-code, state-code");
    }
    if (params_.route_mode != "off" && params_.route_mode != "probe" &&
        params_.route_mode != "jump-neighbors" && params_.route_mode != "hint-oracle" &&
        params_.route_mode != "hint-parsed" && params_.route_mode != "hint-kv-exact" &&
        params_.route_mode != "hint-kv-hash") {
        throw std::runtime_error(
            "route-mode must be one of: off, probe, jump-neighbors, hint-oracle, hint-parsed, hint-kv-exact, hint-kv-hash");
    }
    if (params_.route_refresh != "epoch" && params_.route_refresh != "cycle") {
        throw std::runtime_error("route-refresh must be one of: epoch, cycle");
    }
    if (params_.K_jump > params_.K) {
        throw std::runtime_error("K-jump must be less than or equal to K");
    }
}

GraphV02::Candidate GraphV02::sample_best_candidate(int index) {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    Candidate best;
    const int total_possible = params_.channels * (params_.S - 1);
    const auto consider_candidate = [&best](const Candidate& candidate) {
        if (!candidate.valid) {
            return;
        }
        if (!best.valid || candidate.delta_eff < best.delta_eff ||
            (candidate.delta_eff == best.delta_eff &&
             candidate.changed_channels < best.changed_channels)) {
            best = candidate;
        }
    };

    if (params_.proposal_count >= total_possible) {
        for (int channel = 0; channel < params_.channels; ++channel) {
            const auto current = node.state[static_cast<std::size_t>(channel)];
            for (int state = 0; state < params_.S; ++state) {
                if (state == current) {
                    continue;
                }
                consider_candidate(make_candidate(
                    index,
                    channel == 0 ? static_cast<std::uint8_t>(state) : node.state[0],
                    channel == 1 ? static_cast<std::uint8_t>(state) : node.state[1]));
            }
        }
    } else {
        std::array<std::array<bool, FieldTable::States>, FieldTable::Channels> seen{};
        int sampled = 0;
        while (sampled < params_.proposal_count) {
            const int channel = rng_.uniform_int(0, params_.channels - 1);
            const int state = rng_.uniform_int(0, params_.S - 1);
            if (state == node.state[static_cast<std::size_t>(channel)] ||
                seen[static_cast<std::size_t>(channel)][static_cast<std::size_t>(state)]) {
                continue;
            }
            seen[static_cast<std::size_t>(channel)][static_cast<std::size_t>(state)] = true;
            ++sampled;

            consider_candidate(make_candidate(
                index,
                channel == 0 ? static_cast<std::uint8_t>(state) : node.state[0],
                channel == 1 ? static_cast<std::uint8_t>(state) : node.state[1]));
        }
    }

    if (pair_proposals_enabled()) {
        consider_candidate(best_block_candidate(index));
    }
    if (params_.route_target_proposals != 0 && route_hint_active()) {
        std::uint8_t route_value = 0;
        if (route_hint_proposal_value_for_node(index, route_value)) {
            const auto route_high =
                static_cast<std::uint8_t>(route_value / FieldTable::States);
            const auto route_low =
                static_cast<std::uint8_t>(route_value % FieldTable::States);
            consider_candidate(make_candidate(index, route_high, node.state[1]));
            consider_candidate(make_candidate(index, node.state[0], route_low));
        }
    }

    return best;
}

GraphV02::Candidate GraphV02::best_block_candidate(int index) const {
    Candidate best;
    const auto consider_candidate = [&best](const Candidate& candidate) {
        if (!candidate.valid) {
            return;
        }
        if (!best.valid || candidate.delta_eff < best.delta_eff ||
            (candidate.delta_eff == best.delta_eff &&
             candidate.changed_channels < best.changed_channels)) {
            best = candidate;
        }
    };

    for (int high_state = 0; high_state < params_.S; ++high_state) {
        for (int low_state = 0; low_state < params_.S; ++low_state) {
            consider_candidate(make_candidate(
                index,
                static_cast<std::uint8_t>(high_state),
                static_cast<std::uint8_t>(low_state)));
        }
    }

    return best;
}

GraphV02::Candidate GraphV02::make_candidate(
    int index,
    std::uint8_t new_high,
    std::uint8_t new_low) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];

    Candidate candidate;
    candidate.state[0] = new_high;
    candidate.state[1] = new_low;
    candidate.changed_channels = static_cast<int>(new_high != node.state[0]) +
                                 static_cast<int>(new_low != node.state[1]);
    if (candidate.changed_channels == 0) {
        return candidate;
    }

    candidate.delta = delta_energy(index, new_high, new_low);
    candidate.delta_eff =
        candidate.delta + static_cast<float>(candidate.changed_channels) * params_.lambda_m * node.mass;
    candidate.valid = true;
    return candidate;
}

bool GraphV02::pair_proposals_enabled() const {
    return coupling_has_signal_ && params_.lambda_b > 0.0f && params_.eta_b > 0.0f;
}

bool GraphV02::routing_enabled() const {
    return params_.K_jump > 0 && params_.routing_source != "none" &&
           params_.route_mode != "off" && params_.route_mode != "hint-oracle" &&
           params_.route_mode != "hint-parsed" && params_.route_mode != "hint-kv-exact" &&
           params_.route_mode != "hint-kv-hash";
}

bool GraphV02::jump_neighbors_active() const {
    return routing_enabled() && params_.route_mode == "jump-neighbors";
}

bool GraphV02::route_hint_oracle_active() const {
    return params_.route_mode == "hint-oracle" && params_.lambda_route > 0.0f;
}

bool GraphV02::route_hint_parsed_active() const {
    return params_.route_mode == "hint-parsed" && params_.lambda_route > 0.0f;
}

bool GraphV02::route_hint_kv_exact_active() const {
    return params_.route_mode == "hint-kv-exact" && params_.lambda_route > 0.0f;
}

bool GraphV02::route_hint_kv_hash_active() const {
    return params_.route_mode == "hint-kv-hash" && params_.lambda_route > 0.0f;
}

bool GraphV02::joint_code_key_hash_active() const {
    return route_hint_kv_hash_active() && params_.route_hash_source == "joint-code-key";
}

bool GraphV02::route_code_key_hash_active() const {
    return route_hint_kv_hash_active() && params_.route_hash_source == "route-code-key";
}

bool GraphV02::learned_code_key_hash_active() const {
    return joint_code_key_hash_active() || route_code_key_hash_active();
}

bool GraphV02::route_hint_active() const {
    return route_hint_oracle_active() || route_hint_parsed_active() ||
           route_hint_kv_exact_active() || route_hint_kv_hash_active();
}

bool GraphV02::route_hint_value_for_node(int index, std::uint8_t& out_value) const {
    if (route_hint_weights_[static_cast<std::size_t>(index)] <= 0.0f) {
        return false;
    }
    if (route_hint_parsed_active() || route_hint_kv_exact_active() ||
        route_hint_kv_hash_active()) {
        const int value_pos = route_hint_value_positions_[static_cast<std::size_t>(index)];
        if (value_pos < 0 || value_pos >= params_.N) {
            return false;
        }
        if (!route_source_candidate_allowed(index, value_pos)) {
            return false;
        }
        out_value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
        return true;
    }
    out_value = route_hint_values_[static_cast<std::size_t>(index)];
    return true;
}

bool GraphV02::route_hint_proposal_value_for_node(int index, std::uint8_t& out_value) const {
    if (route_hint_weights_[static_cast<std::size_t>(index)] <= 0.0f) {
        return false;
    }
    const auto& vote_positions =
        route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
    std::uint8_t policy_value = 0;
    const bool has_policy_value = route_hint_value_for_node(index, policy_value);
    const std::string effective_agg =
        has_policy_value ? route_effective_hint_agg_for_node(index, policy_value)
                         : params_.route_hint_agg;
    if (effective_agg == "none") {
        return false;
    }
    if (route_hint_active() &&
        (effective_agg == "vote" || effective_agg == "weighted-vote") &&
        !vote_positions.empty()) {
        std::array<int, FieldTable::ByteValues> value_counts{};
        for (const int value_pos : vote_positions) {
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            ++value_counts[static_cast<std::size_t>(value)];
        }

        std::array<float, FieldTable::ByteValues> value_votes{};
        const float mean_base_weight = route_candidate_mean_base_weight_for_vote(
            index, vote_positions, value_counts, effective_agg);
        for (std::size_t rank_index = 0; rank_index < vote_positions.size(); ++rank_index) {
            const int value_pos = vote_positions[rank_index];
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            if (!route_source_candidate_allowed(index, value_pos)) {
                continue;
            }
            const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            const float candidate_weight = route_candidate_effective_weight_for_vote(
                index,
                value_pos,
                rank_index,
                vote_positions.size(),
                value_counts,
                effective_agg,
                mean_base_weight);
            value_votes[static_cast<std::size_t>(value)] += candidate_weight;
        }

        float best_vote = 0.0f;
        int best_value = -1;
        for (int value = 0; value < FieldTable::ByteValues; ++value) {
            const float vote = value_votes[static_cast<std::size_t>(value)];
            if (vote > best_vote) {
                best_vote = vote;
                best_value = value;
            }
        }
        if (best_value >= 0) {
            out_value = static_cast<std::uint8_t>(best_value);
            return true;
        }
    }

    return route_hint_value_for_node(index, out_value);
}

double GraphV02::route_hint_margin_for_node(int index, std::uint8_t target_value) const {
    if (route_hint_weights_[static_cast<std::size_t>(index)] <= 0.0f) {
        return 0.0;
    }

    std::array<float, FieldTable::States> high_votes{};
    std::array<float, FieldTable::States> low_votes{};
    float vote_weight_sum = 0.0f;
    const auto& vote_positions =
        route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
    std::uint8_t policy_value = 0;
    const bool has_policy_value = route_hint_value_for_node(index, policy_value);
    const std::string effective_agg =
        has_policy_value ? route_effective_hint_agg_for_node(index, policy_value)
                         : params_.route_hint_agg;
    if (effective_agg == "none") {
        return 0.0;
    }
    if (route_hint_active() &&
        (effective_agg == "vote" || effective_agg == "weighted-vote") &&
        !vote_positions.empty()) {
        std::array<int, FieldTable::ByteValues> value_counts{};
        for (const int value_pos : vote_positions) {
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            ++value_counts[static_cast<std::size_t>(value)];
        }

        const float mean_base_weight = route_candidate_mean_base_weight_for_vote(
            index, vote_positions, value_counts, effective_agg);
        for (std::size_t rank_index = 0; rank_index < vote_positions.size(); ++rank_index) {
            const int value_pos = vote_positions[rank_index];
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            if (!route_source_candidate_allowed(index, value_pos)) {
                continue;
            }
            const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            const float candidate_weight = route_candidate_effective_weight_for_vote(
                index,
                value_pos,
                rank_index,
                vote_positions.size(),
                value_counts,
                effective_agg,
                mean_base_weight);
            high_votes[static_cast<std::size_t>(value / FieldTable::States)] +=
                candidate_weight;
            low_votes[static_cast<std::size_t>(value % FieldTable::States)] +=
                candidate_weight;
            vote_weight_sum += candidate_weight;
        }
    } else {
        std::uint8_t value = 0;
        if (!route_hint_value_for_node(index, value)) {
            return 0.0;
        }
        high_votes[static_cast<std::size_t>(value / FieldTable::States)] = 1.0f;
        low_votes[static_cast<std::size_t>(value % FieldTable::States)] = 1.0f;
        vote_weight_sum = 1.0f;
    }

    if (vote_weight_sum <= 0.0f) {
        return 0.0;
    }

    const auto target_high =
        static_cast<std::uint8_t>(target_value / FieldTable::States);
    const auto target_low =
        static_cast<std::uint8_t>(target_value % FieldTable::States);
    float high_other = 0.0f;
    float low_other = 0.0f;
    for (int state = 0; state < FieldTable::States; ++state) {
        if (state != target_high) {
            high_other =
                std::max(high_other, high_votes[static_cast<std::size_t>(state)]);
        }
        if (state != target_low) {
            low_other =
                std::max(low_other, low_votes[static_cast<std::size_t>(state)]);
        }
    }

    return 0.5 * static_cast<double>(
                     (high_votes[static_cast<std::size_t>(target_high)] - high_other +
                      low_votes[static_cast<std::size_t>(target_low)] - low_other) /
                     vote_weight_sum);
}

double GraphV02::route_value_support_confidence_for_node(
    int index,
    std::uint8_t target_value) const {
    if (route_hint_weights_[static_cast<std::size_t>(index)] <= 0.0f) {
        return 0.0;
    }

    std::array<float, FieldTable::ByteValues> value_votes{};
    float vote_weight_sum = 0.0f;
    const auto& vote_positions =
        route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
    if (!vote_positions.empty()) {
        std::array<int, FieldTable::ByteValues> value_counts{};
        for (const int value_pos : vote_positions) {
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            ++value_counts[static_cast<std::size_t>(value)];
        }
        const float mean_base_weight = route_candidate_mean_base_weight_for_vote(
            index, vote_positions, value_counts, params_.route_hint_agg);
        for (std::size_t rank_index = 0; rank_index < vote_positions.size(); ++rank_index) {
            const int value_pos = vote_positions[rank_index];
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            if (!route_source_candidate_allowed(index, value_pos)) {
                continue;
            }
            const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            const float candidate_weight = route_candidate_effective_weight_for_vote(
                index,
                value_pos,
                rank_index,
                vote_positions.size(),
                value_counts,
                params_.route_hint_agg,
                mean_base_weight);
            value_votes[static_cast<std::size_t>(value)] += candidate_weight;
            vote_weight_sum += candidate_weight;
        }
    } else {
        std::uint8_t value = 0;
        if (!route_hint_value_for_node(index, value)) {
            return 0.0;
        }
        value_votes[static_cast<std::size_t>(value)] = 1.0f;
        vote_weight_sum = 1.0f;
    }

    if (vote_weight_sum <= 0.0f) {
        return 0.0;
    }
    return static_cast<double>(
        value_votes[static_cast<std::size_t>(target_value)] / vote_weight_sum);
}

double GraphV02::route_top_value_confidence_for_node(int index) const {
    if (route_hint_weights_[static_cast<std::size_t>(index)] <= 0.0f) {
        return 0.0;
    }

    std::array<float, FieldTable::ByteValues> value_votes{};
    float vote_weight_sum = 0.0f;
    const auto& vote_positions =
        route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
    if (!vote_positions.empty()) {
        for (const int value_pos : vote_positions) {
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            value_votes[static_cast<std::size_t>(value)] += 1.0f;
            vote_weight_sum += 1.0f;
        }
    } else {
        std::uint8_t value = 0;
        if (!route_hint_value_for_node(index, value)) {
            return 0.0;
        }
        value_votes[static_cast<std::size_t>(value)] = 1.0f;
        vote_weight_sum = 1.0f;
    }

    if (vote_weight_sum <= 0.0f) {
        return 0.0;
    }
    float best_vote = 0.0f;
    for (float vote : value_votes) {
        best_vote = std::max(best_vote, vote);
    }
    return static_cast<double>(best_vote / vote_weight_sum);
}

double GraphV02::route_top_value_is_target(int index, std::uint8_t target_value) const {
    if (route_hint_weights_[static_cast<std::size_t>(index)] <= 0.0f) {
        return 0.0;
    }

    std::array<float, FieldTable::ByteValues> value_votes{};
    const auto& vote_positions =
        route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
    if (!vote_positions.empty()) {
        for (const int value_pos : vote_positions) {
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            value_votes[static_cast<std::size_t>(value)] += 1.0f;
        }
    } else {
        std::uint8_t value = 0;
        if (!route_hint_value_for_node(index, value)) {
            return 0.0;
        }
        value_votes[static_cast<std::size_t>(value)] = 1.0f;
    }

    int best_value = 0;
    float best_vote = value_votes[0];
    for (int value = 1; value < FieldTable::ByteValues; ++value) {
        const float vote = value_votes[static_cast<std::size_t>(value)];
        if (vote > best_vote) {
            best_vote = vote;
            best_value = value;
        }
    }
    return best_value == static_cast<int>(target_value) ? 1.0 : 0.0;
}

bool GraphV02::route_agreement_votes_for_node(
    int index,
    std::array<int, FieldTable::ByteValues>& votes,
    std::array<int, FieldTable::ByteValues>& first_seen,
    int& scorer_count) const {
    votes.fill(0);
    first_seen.fill(std::numeric_limits<int>::max());
    scorer_count = 0;
    if (route_hint_weights_[static_cast<std::size_t>(index)] <= 0.0f) {
        return false;
    }

    const auto& vote_positions =
        route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
    const auto& candidate_keys =
        route_hint_candidate_keys_[static_cast<std::size_t>(index)];

    const auto value_at_position = [&](int value_pos, std::uint8_t& out_value) {
        if (value_pos < 0 || value_pos >= params_.N) {
            return false;
        }
        out_value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
        return true;
    };
    const auto add_vote = [&](std::uint8_t value) {
        const auto value_index = static_cast<std::size_t>(value);
        ++votes[value_index];
        if (first_seen[value_index] == std::numeric_limits<int>::max()) {
            first_seen[value_index] = scorer_count;
        }
        ++scorer_count;
    };

    if (vote_positions.empty()) {
        std::uint8_t value = 0;
        if (!route_hint_value_for_node(index, value)) {
            return false;
        }
        add_vote(value);
        return true;
    }

    std::uint8_t insertion_value = 0;
    if (value_at_position(vote_positions.front(), insertion_value)) {
        add_vote(insertion_value);
    }

    std::array<int, FieldTable::ByteValues> value_counts{};
    for (const int value_pos : vote_positions) {
        std::uint8_t value = 0;
        if (value_at_position(value_pos, value)) {
            ++value_counts[static_cast<std::size_t>(value)];
        }
    }
    int best_value_vote = -1;
    int best_value_count = 0;
    for (int value = 0; value < FieldTable::ByteValues; ++value) {
        const int count = value_counts[static_cast<std::size_t>(value)];
        if (count > best_value_count) {
            best_value_count = count;
            best_value_vote = value;
        }
    }
    if (best_value_vote >= 0) {
        add_vote(static_cast<std::uint8_t>(best_value_vote));
    }

    int best_recency_pos = -1;
    for (const int value_pos : vote_positions) {
        if (value_pos >= 0 && value_pos < params_.N && value_pos > best_recency_pos) {
            best_recency_pos = value_pos;
        }
    }
    std::uint8_t recency_value = 0;
    if (value_at_position(best_recency_pos, recency_value)) {
        add_vote(recency_value);
    }

    const std::string& query_key =
        route_hint_query_keys_[static_cast<std::size_t>(index)];
    if (!query_key.empty() && candidate_keys.size() == vote_positions.size()) {
        double best_shape_score = -std::numeric_limits<double>::infinity();
        int best_shape_pos = -1;
        for (std::size_t candidate_index = 0; candidate_index < vote_positions.size();
             ++candidate_index) {
            const std::string& candidate_key = candidate_keys[candidate_index];
            if (candidate_key.empty()) {
                continue;
            }
            const int value_pos = vote_positions[candidate_index];
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            const double score = key_shape_score(query_key, candidate_key);
            if (score > best_shape_score ||
                (score == best_shape_score && value_pos > best_shape_pos)) {
                best_shape_score = score;
                best_shape_pos = value_pos;
            }
        }
        std::uint8_t shape_value = 0;
        if (value_at_position(best_shape_pos, shape_value)) {
            add_vote(shape_value);
        }
    }

    return scorer_count > 0;
}

double GraphV02::route_agreement_confidence_for_node(
    int index,
    std::uint8_t target_value) const {
    std::array<int, FieldTable::ByteValues> votes{};
    std::array<int, FieldTable::ByteValues> first_seen{};
    int scorer_count = 0;
    if (!route_agreement_votes_for_node(index, votes, first_seen, scorer_count) ||
        scorer_count <= 0) {
        return 0.0;
    }
    return static_cast<double>(votes[static_cast<std::size_t>(target_value)]) /
           static_cast<double>(scorer_count);
}

double GraphV02::route_agreement_top_confidence_for_node(int index) const {
    std::array<int, FieldTable::ByteValues> votes{};
    std::array<int, FieldTable::ByteValues> first_seen{};
    int scorer_count = 0;
    if (!route_agreement_votes_for_node(index, votes, first_seen, scorer_count) ||
        scorer_count <= 0) {
        return 0.0;
    }

    int best_vote = 0;
    int best_first_seen = std::numeric_limits<int>::max();
    for (int value = 0; value < FieldTable::ByteValues; ++value) {
        const int vote = votes[static_cast<std::size_t>(value)];
        const int seen = first_seen[static_cast<std::size_t>(value)];
        if (vote > best_vote || (vote == best_vote && seen < best_first_seen)) {
            best_vote = vote;
            best_first_seen = seen;
        }
    }
    return static_cast<double>(best_vote) / static_cast<double>(scorer_count);
}

double GraphV02::route_agreement_top_value_is_target(
    int index,
    std::uint8_t target_value) const {
    std::array<int, FieldTable::ByteValues> votes{};
    std::array<int, FieldTable::ByteValues> first_seen{};
    int scorer_count = 0;
    if (!route_agreement_votes_for_node(index, votes, first_seen, scorer_count) ||
        scorer_count <= 0) {
        return 0.0;
    }

    int best_value = -1;
    int best_vote = 0;
    int best_first_seen = std::numeric_limits<int>::max();
    for (int value = 0; value < FieldTable::ByteValues; ++value) {
        const int vote = votes[static_cast<std::size_t>(value)];
        const int seen = first_seen[static_cast<std::size_t>(value)];
        if (vote > best_vote || (vote == best_vote && seen < best_first_seen)) {
            best_value = value;
            best_vote = vote;
            best_first_seen = seen;
        }
    }
    return best_value == static_cast<int>(target_value) ? 1.0 : 0.0;
}

double GraphV02::route_aggregation_confidence_for_node(
    int index,
    std::uint8_t target_value) const {
    if (params_.route_aggregation_confidence == "value-support") {
        return route_value_support_confidence_for_node(index, target_value);
    }
    return route_agreement_confidence_for_node(index, target_value);
}

std::string GraphV02::route_effective_hint_agg_for_node(
    int index,
    std::uint8_t target_value) const {
    (void)target_value;
    if (route_source_filter_active() && !route_source_node_has_allowed_candidate(index)) {
        return "none";
    }
    if (params_.route_hint_agg != "confidence-gated") {
        return params_.route_hint_agg;
    }
    if (!route_low_confidence_for_node(index, target_value)) {
        return params_.route_highconf_agg;
    }
    if (params_.route_lowconf_policy == "none") {
        return "none";
    }
    if (params_.route_lowconf_policy == "weak-vote") {
        return "vote";
    }
    return params_.route_lowconf_agg;
}

bool GraphV02::route_low_confidence_for_node(
    int index,
    std::uint8_t target_value) const {
    if (params_.route_hint_agg != "confidence-gated") {
        return false;
    }
    const double confidence = route_aggregation_confidence_for_node(index, target_value);
    return confidence < static_cast<double>(params_.route_confidence_threshold);
}

float GraphV02::route_effective_policy_scale_for_node(
    int index,
    std::uint8_t target_value) const {
    if (!route_low_confidence_for_node(index, target_value)) {
        return 1.0f;
    }
    if (params_.route_lowconf_policy == "none") {
        return 0.0f;
    }
    if (params_.route_lowconf_policy == "weak-vote") {
        return params_.route_lowconf_weak_scale;
    }
    return 1.0f;
}

double GraphV02::local_energy_without_route(
    int index,
    std::uint8_t high,
    std::uint8_t low) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    double energy = -params_.lambda_u *
                    static_cast<double>(field_.score(0, node.input_byte, high));
    energy += -params_.lambda_u *
              static_cast<double>(field_.score(1, node.input_byte, low));

    std::array<int, 8> effective_neighbors{};
    const int neighbor_count = fill_effective_neighbors(index, effective_neighbors);
    for (int n = 0; n < neighbor_count; ++n) {
        const NodeV02& neighbor =
            nodes_[static_cast<std::size_t>(effective_neighbors[static_cast<std::size_t>(n)])];
        energy += params_.lambda_v *
                  static_cast<double>((high != neighbor.state[0] ? 1.0f : 0.0f) +
                                      (low != neighbor.state[1] ? 1.0f : 0.0f));
    }

    energy += -params_.lambda_b *
              static_cast<double>(coupling_.score(node.input_byte, high, low));
    return energy;
}

double GraphV02::local_margin_against_route(int index, std::uint8_t target_value) const {
    const auto target_high =
        static_cast<std::uint8_t>(target_value / FieldTable::States);
    const auto target_low =
        static_cast<std::uint8_t>(target_value % FieldTable::States);
    const double target_energy =
        local_energy_without_route(index, target_high, target_low);
    double best_other_energy = std::numeric_limits<double>::infinity();
    for (int high = 0; high < FieldTable::States; ++high) {
        for (int low = 0; low < FieldTable::States; ++low) {
            if (high == target_high && low == target_low) {
                continue;
            }
            best_other_energy = std::min(
                best_other_energy,
                local_energy_without_route(
                    index,
                    static_cast<std::uint8_t>(high),
                    static_cast<std::uint8_t>(low)));
        }
    }
    return target_energy - best_other_energy;
}

double GraphV02::local_channel_margin_against_route(
    int index,
    int channel,
    std::uint8_t target_state) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    const auto current_high = node.state[0];
    const auto current_low = node.state[1];
    const double target_energy =
        channel == 0
            ? local_energy_without_route(index, target_state, current_low)
            : local_energy_without_route(index, current_high, target_state);
    double best_other_energy = std::numeric_limits<double>::infinity();
    for (int state = 0; state < FieldTable::States; ++state) {
        if (state == target_state) {
            continue;
        }
        const double candidate_energy =
            channel == 0
                ? local_energy_without_route(
                      index,
                      static_cast<std::uint8_t>(state),
                      current_low)
                : local_energy_without_route(
                      index,
                      current_high,
                      static_cast<std::uint8_t>(state));
        best_other_energy = std::min(best_other_energy, candidate_energy);
    }
    return target_energy - best_other_energy;
}

float GraphV02::compute_route_effective_strength_for_node(
    int index,
    std::uint8_t target_value) const {
    const float policy_scale = route_effective_policy_scale_for_node(index, target_value);
    if (policy_scale <= 0.0f) {
        return 0.0f;
    }
    const bool fallback_used =
        index >= 0 && index < static_cast<int>(route_hint_fallback_used_.size()) &&
        route_hint_fallback_used_[static_cast<std::size_t>(index)];
    const bool fallback_margin_mode =
        fallback_used && params_.route_fallback_strength_mode == "margin";
    float fallback_scale = 1.0f;
    if (fallback_used && !fallback_margin_mode) {
        fallback_scale = params_.route_fallback_strength_mult;
    }
    if (params_.route_strength_mode == "fixed" && !fallback_margin_mode) {
        return params_.lambda_route * policy_scale * fallback_scale *
               route_source_credit_strength_scale_for_node(index);
    }

    const float confidence = route_hint_weights_[static_cast<std::size_t>(index)];
    if (confidence < params_.route_min_confidence) {
        return 0.0f;
    }
    double strength_confidence = static_cast<double>(confidence);
    if (params_.route_strength_confidence == "value-support") {
        strength_confidence = route_value_support_confidence_for_node(index, target_value);
    } else if (params_.route_strength_confidence == "agreement") {
        strength_confidence = route_agreement_confidence_for_node(index, target_value);
    }
    if (strength_confidence < static_cast<double>(params_.route_min_confidence)) {
        return 0.0f;
    }

    const double local_margin = local_margin_against_route(index, target_value);
    double strength = 0.0;
    if (fallback_margin_mode) {
        strength =
            static_cast<double>(params_.route_fallback_lambda_base) +
            static_cast<double>(params_.route_fallback_margin_alpha) *
                std::max(0.0, local_margin);
        if (params_.route_fallback_lambda_max > 0.0f) {
            strength =
                std::min(strength, static_cast<double>(params_.route_fallback_lambda_max));
        }
        strength *= static_cast<double>(params_.route_fallback_strength_mult);
    } else {
        strength =
            static_cast<double>(params_.lambda_route_base) +
            static_cast<double>(params_.route_margin_alpha) * std::max(0.0, local_margin);
        if (params_.lambda_route_max > 0.0f) {
            strength = std::min(strength, static_cast<double>(params_.lambda_route_max));
        }
    }
    if (params_.route_confidence_power > 0.0f) {
        strength *= std::pow(
            std::max(strength_confidence, 0.0),
            static_cast<double>(params_.route_confidence_power));
    }
    return static_cast<float>(std::max(0.0, strength)) * policy_scale * fallback_scale *
           route_source_credit_strength_scale_for_node(index);
}

float GraphV02::route_effective_strength_for_node(
    int index,
    std::uint8_t target_value) const {
    if (index >= 0 && index < static_cast<int>(route_strength_cache_.size())) {
        return route_strength_cache_[static_cast<std::size_t>(index)];
    }
    return compute_route_effective_strength_for_node(index, target_value);
}

float GraphV02::route_fallback_channel_strength_scale_for_node(
    int index,
    int channel) const {
    if (index < 0 || index >= static_cast<int>(route_hint_fallback_used_.size()) ||
        !route_hint_fallback_used_[static_cast<std::size_t>(index)]) {
        return 1.0f;
    }
    return channel == 0 ? params_.route_fallback_hi_strength_mult
                        : params_.route_fallback_lo_strength_mult;
}

float GraphV02::route_fallback_channel_effective_strength_for_node(
    int index,
    int channel,
    std::uint8_t target_value,
    float base_strength) const {
    if (index < 0 || index >= static_cast<int>(route_hint_fallback_used_.size()) ||
        !route_hint_fallback_used_[static_cast<std::size_t>(index)]) {
        return base_strength;
    }
    if (params_.route_fallback_channel_strength_mode != "margin") {
        return base_strength * route_fallback_channel_strength_scale_for_node(index, channel);
    }

    const auto target_state =
        channel == 0 ? static_cast<std::uint8_t>(target_value / FieldTable::States)
                     : static_cast<std::uint8_t>(target_value % FieldTable::States);
    const double local_margin =
        std::max(0.0, local_channel_margin_against_route(index, channel, target_state));
    const double base =
        channel == 0 ? params_.route_fallback_hi_lambda_base
                     : params_.route_fallback_lo_lambda_base;
    const double alpha =
        channel == 0 ? params_.route_fallback_hi_margin_alpha
                     : params_.route_fallback_lo_margin_alpha;
    const double cap =
        channel == 0 ? params_.route_fallback_hi_lambda_max
                     : params_.route_fallback_lo_lambda_max;
    double strength = base + alpha * local_margin;
    if (cap > 0.0) {
        strength = std::min(strength, cap);
    }
    strength *= static_cast<double>(params_.route_fallback_strength_mult);
    return static_cast<float>(std::max(0.0, strength));
}

void GraphV02::refresh_route_hint_candidate_keys() {
    if (route_hint_candidate_keys_.size() != static_cast<std::size_t>(params_.N)) {
        route_hint_candidate_keys_.assign(static_cast<std::size_t>(params_.N), {});
    }
    for (int index = 0; index < params_.N; ++index) {
        auto& keys = route_hint_candidate_keys_[static_cast<std::size_t>(index)];
        keys.clear();
        const auto& positions =
            route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
        keys.reserve(positions.size());
        for (const int value_pos : positions) {
            if (value_pos >= 0 && value_pos < params_.N) {
                keys.push_back(route_value_position_keys_[static_cast<std::size_t>(value_pos)]);
            } else {
                keys.push_back({});
            }
        }
    }
}

void GraphV02::refresh_route_hint_candidate_sources() {
    if (route_hint_candidate_source_ids_.size() !=
        static_cast<std::size_t>(params_.N)) {
        route_hint_candidate_source_ids_.assign(static_cast<std::size_t>(params_.N), {});
    }
    const std::string primary_source = primary_route_source_id();
    for (int index = 0; index < params_.N; ++index) {
        const auto& positions =
            route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
        route_hint_candidate_source_ids_[static_cast<std::size_t>(index)].assign(
            positions.size(),
            primary_source);
    }
}

void GraphV02::refresh_route_strength_cache() {
    if (route_strength_cache_.size() != static_cast<std::size_t>(params_.N)) {
        route_strength_cache_.assign(static_cast<std::size_t>(params_.N), 0.0f);
    }
    for (int index = 0; index < params_.N; ++index) {
        std::uint8_t value = 0;
        route_strength_cache_[static_cast<std::size_t>(index)] =
            route_hint_proposal_value_for_node(index, value)
                ? compute_route_effective_strength_for_node(index, value)
                : 0.0f;
    }
}

bool GraphV02::should_corrupt_route_candidate(int index) const {
    if (params_.route_corrupt_candidate_rate <= 0.0f) {
        return false;
    }
    if (params_.route_corrupt_candidate_rate >= 1.0f) {
        return true;
    }
    std::uint32_t hash = 2166136261u;
    hash = fnv1a_update(hash, static_cast<std::uint8_t>(index & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>((index >> 8) & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>(params_.seed & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>((params_.seed >> 8) & 0xff));
    const double sample =
        static_cast<double>(hash % 1000000u) / 1000000.0;
    return sample < static_cast<double>(params_.route_corrupt_candidate_rate);
}

bool GraphV02::should_inject_noisy_route_source(int index) const {
    if (params_.route_noisy_source_rate <= 0.0f) {
        return false;
    }
    if (params_.route_noisy_source_rate >= 1.0f) {
        return true;
    }
    std::uint32_t hash = 2166136261u;
    hash = fnv1a_update(hash, static_cast<std::uint8_t>(index & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>((index >> 8) & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>(params_.seed & 0xff));
    hash = fnv1a_update(hash, static_cast<std::uint8_t>((params_.seed >> 8) & 0xff));
    hash = fnv1a_update(hash, 0x9du);
    const double sample =
        static_cast<double>(hash % 1000000u) / 1000000.0;
    return sample < static_cast<double>(params_.route_noisy_source_rate);
}

int GraphV02::wrong_route_value_position_for_node(int index) const {
    const int correct =
        route_hint_correct_value_positions_[static_cast<std::size_t>(index)];
    if (route_value_positions_.size() < 2U) {
        return -1;
    }
    const std::size_t start =
        (static_cast<std::size_t>(index) + static_cast<std::size_t>(params_.seed)) %
        route_value_positions_.size();
    for (std::size_t offset = 0; offset < route_value_positions_.size(); ++offset) {
        const int candidate =
            route_value_positions_[(start + offset) % route_value_positions_.size()];
        if (candidate != correct) {
            return candidate;
        }
    }
    return -1;
}

void GraphV02::apply_route_candidate_corruption() {
    if (params_.route_corrupt_candidate_rate <= 0.0f || !route_hint_active()) {
        return;
    }
    for (int index = 0; index < params_.N; ++index) {
        if (route_hint_weights_[static_cast<std::size_t>(index)] <= 0.0f) {
            continue;
        }
        if (route_hint_correct_value_positions_[static_cast<std::size_t>(index)] < 0) {
            continue;
        }
        if (!should_corrupt_route_candidate(index)) {
            continue;
        }
        const int wrong_pos = wrong_route_value_position_for_node(index);
        if (wrong_pos < 0 || wrong_pos >= params_.N) {
            continue;
        }
        route_hint_corrupted_[static_cast<std::size_t>(index)] = true;
        route_hint_value_positions_[static_cast<std::size_t>(index)] = wrong_pos;
        route_hint_values_[static_cast<std::size_t>(index)] =
            nodes_[static_cast<std::size_t>(wrong_pos)].input_byte;
        auto& candidates =
            route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
        auto& candidate_keys =
            route_hint_candidate_keys_[static_cast<std::size_t>(index)];
        candidates.clear();
        candidates.push_back(wrong_pos);
        candidate_keys.clear();
        candidate_keys.push_back(
            route_value_position_keys_[static_cast<std::size_t>(wrong_pos)]);
        const int correct_pos =
            route_hint_correct_value_positions_[static_cast<std::size_t>(index)];
        if (params_.route_corrupt_preserve_correct != 0 && correct_pos >= 0 &&
            correct_pos < params_.N && correct_pos != wrong_pos) {
            candidates.push_back(correct_pos);
            candidate_keys.push_back(
                route_value_position_keys_[static_cast<std::size_t>(correct_pos)]);
        }
        if (params_.route_corrupt_confidence == "low") {
            route_hint_weights_[static_cast<std::size_t>(index)] =
                params_.route_corrupt_confidence_value;
        }
    }
}

bool GraphV02::candidate_positions_contain_correct(int index) const {
    const int correct =
        route_hint_correct_value_positions_[static_cast<std::size_t>(index)];
    if (correct < 0) {
        return false;
    }
    const auto& candidates =
        route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
    if (std::find(candidates.begin(), candidates.end(), correct) != candidates.end()) {
        return true;
    }
    return route_hint_value_positions_[static_cast<std::size_t>(index)] == correct;
}

bool GraphV02::route_fallback_persistence_active(int index) const {
    if (index < 0 ||
        index >= static_cast<int>(route_fallback_persist_remaining_.size())) {
        return false;
    }
    return route_fallback_persist_remaining_[static_cast<std::size_t>(index)] > 0;
}

std::string GraphV02::route_credit_query_signature(int query_index) const {
    if (query_index >= 0 &&
        query_index < static_cast<int>(route_hint_query_keys_.size())) {
        const std::string& key =
            route_hint_query_keys_[static_cast<std::size_t>(query_index)];
        if (!key.empty()) {
            return "key:" + key + "@pos:" + std::to_string(query_index);
        }
    }
    return "pos:" + std::to_string(query_index);
}

std::string GraphV02::route_credit_edge_key(int query_index, int value_pos) const {
    return route_credit_query_signature(query_index) +
           "|value-pos:" + std::to_string(value_pos);
}

std::string GraphV02::route_plasticity_ledger_key(int query_index, int value_pos) const {
    std::string query_key = route_credit_query_signature(query_index);
    if (query_index >= 0 &&
        query_index < static_cast<int>(route_hint_query_keys_.size()) &&
        !route_hint_query_keys_[static_cast<std::size_t>(query_index)].empty()) {
        query_key =
            "key:" + route_hint_query_keys_[static_cast<std::size_t>(query_index)];
    }

    std::string value_key = "value-pos:" + std::to_string(value_pos);
    if (value_pos >= 0 &&
        value_pos < static_cast<int>(route_value_position_keys_.size()) &&
        !route_value_position_keys_[static_cast<std::size_t>(value_pos)].empty()) {
        value_key =
            "value-key:" + route_value_position_keys_[static_cast<std::size_t>(value_pos)];
    }
    const auto value_byte = value_pos >= 0 && value_pos < params_.N
                                ? nodes_[static_cast<std::size_t>(value_pos)].input_byte
                                : 0;
    return query_key + "|" + value_key +
           "|value-byte:" + std::to_string(static_cast<int>(value_byte));
}

std::string GraphV02::primary_route_source_id() const {
    return "primary-" + params_.route_hash_source;
}

std::string GraphV02::fallback_route_source_id() const {
    return "fallback-" + params_.route_fallback_source;
}

std::string GraphV02::retry_route_source_id() const {
    return retry_route_source_id_for_source(params_.route_source_retry_source);
}

std::string GraphV02::retry_route_source_id_for_source(
    const std::string& source) const {
    return "retry-" + source;
}

std::string GraphV02::noisy_route_source_id() const {
    return "noisy-route-code";
}

std::string GraphV02::route_source_credit_bucket_for_query(
    int query_index,
    const std::string& source_id) const {
    std::string query_key;
    if (query_index >= 0 &&
        query_index < static_cast<int>(route_hint_query_keys_.size())) {
        query_key = route_hint_query_keys_[static_cast<std::size_t>(query_index)];
    }
    if (query_key.empty()) {
        return "query-pos:" + std::to_string(query_index);
    }

    if (source_id.rfind("primary-", 0) == 0) {
        std::uint32_t bucket = 0;
        if (params_.route_hash_source == "route-code-key") {
            bucket = route_code_hash_for_key(query_key);
        } else if (params_.route_hash_source == "joint-code-key") {
            bucket = joint_code_hash_for_key(query_key);
        } else {
            bucket = hash_string_bucket(query_key, params_.route_hash_bits);
        }
        return "hash-source:" + params_.route_hash_source +
               "|bits:" + std::to_string(params_.route_hash_bits) +
               "|bucket:" + std::to_string(bucket);
    }

    if (source_id == noisy_route_source_id()) {
        return "noisy-source:route-code-key|bits:" +
               std::to_string(params_.route_hash_bits) +
               "|bucket:" + std::to_string(route_code_hash_for_key(query_key));
    }

    if (source_id.rfind("retry-", 0) == 0) {
        const std::string retry_source = source_id.substr(std::string("retry-").size());
        if (retry_source == "key-shape") {
            return "retry-source:key-shape|len:" +
                   std::to_string(query_key.size()) +
                   "|digits:" + std::to_string(digit_count(query_key));
        }
        if (retry_source == "joint-code-key") {
            return "retry-source:joint-code-key|bits:" +
                   std::to_string(params_.route_hash_bits) +
                   "|bucket:" +
                   std::to_string(joint_code_hash_for_key(query_key));
        }
        if (retry_source == "noisy-route-code") {
            return "retry-source:noisy-route-code|bits:" +
                   std::to_string(params_.route_hash_bits) +
                   "|bucket:" +
                   std::to_string(route_code_hash_for_key(query_key)) +
                   "|rate:" + std::to_string(params_.route_noisy_source_rate);
        }
        if (retry_source == "raw-key") {
            return "retry-source:raw-key|bits:" +
                   std::to_string(params_.route_hash_bits) +
                   "|bucket:" +
                   std::to_string(hash_string_bucket(query_key, params_.route_hash_bits));
        }
        return "retry-source:" + retry_source;
    }

    if (params_.route_fallback_source == "key-shape") {
        return "fallback-source:key-shape|len:" +
               std::to_string(query_key.size()) +
               "|digits:" + std::to_string(digit_count(query_key));
    }
    if (params_.route_fallback_source == "joint-code-key") {
        return "fallback-source:joint-code-key|bits:" +
               std::to_string(params_.route_hash_bits) +
               "|bucket:" +
               std::to_string(joint_code_hash_for_key(query_key));
    }
    if (params_.route_fallback_source == "noisy-route-code") {
        return "fallback-source:noisy-route-code|bits:" +
               std::to_string(params_.route_hash_bits) +
               "|bucket:" +
               std::to_string(route_code_hash_for_key(query_key)) +
               "|rate:" + std::to_string(params_.route_noisy_source_rate);
    }
    if (params_.route_fallback_source == "raw-key") {
        return "fallback-source:raw-key|bits:" +
               std::to_string(params_.route_hash_bits) +
               "|bucket:" +
               std::to_string(hash_string_bucket(query_key, params_.route_hash_bits));
    }
    return "fallback-source:" + params_.route_fallback_source;
}

std::string GraphV02::route_source_credit_key(
    int query_index,
    const std::string& source_id) const {
    return route_credit_query_signature(query_index) +
           "|source:" + source_id +
           "|bucket:" + route_source_credit_bucket_for_query(query_index, source_id);
}

std::string GraphV02::route_source_id_for_candidate(
    int query_index,
    int value_pos) const {
    if (query_index >= 0 &&
        query_index < static_cast<int>(route_hint_candidate_value_positions_.size()) &&
        query_index < static_cast<int>(route_hint_candidate_source_ids_.size())) {
        const auto& positions =
            route_hint_candidate_value_positions_[static_cast<std::size_t>(query_index)];
        const auto& sources =
            route_hint_candidate_source_ids_[static_cast<std::size_t>(query_index)];
        for (std::size_t rank = 0; rank < positions.size(); ++rank) {
            if (positions[rank] == value_pos && rank < sources.size() &&
                !sources[rank].empty()) {
                return sources[rank];
            }
        }
    }
    return primary_route_source_id();
}

float GraphV02::route_credit_for_candidate(int query_index, int value_pos) const {
    if (value_pos < 0 || value_pos >= params_.N) {
        return 0.0f;
    }
    if (params_.route_credit_mode == "off") {
        return 0.0f;
    }
    if (params_.route_plasticity_ledger != 0) {
        const auto found =
            route_plasticity_ledger_.find(route_plasticity_ledger_key(query_index, value_pos));
        return found == route_plasticity_ledger_.end() ? 0.0f : found->second;
    }
    if (params_.route_credit_mode == "query-value") {
        const auto found =
            route_credit_by_query_value_.find(route_credit_edge_key(query_index, value_pos));
        return found == route_credit_by_query_value_.end() ? 0.0f : found->second;
    }
    if (value_pos >= static_cast<int>(route_credit_by_value_pos_.size())) {
        return 0.0f;
    }
    return route_credit_by_value_pos_[static_cast<std::size_t>(value_pos)];
}

float GraphV02::route_source_credit_for_candidate(int query_index, int value_pos) const {
    if (value_pos < 0 || value_pos >= params_.N) {
        return 0.0f;
    }
    const std::string source_id = route_source_id_for_candidate(query_index, value_pos);
    return route_source_credit_for_source(query_index, source_id);
}

float GraphV02::route_source_credit_for_source(
    int query_index,
    const std::string& source_id) const {
    if (!route_source_credit_active()) {
        return 0.0f;
    }
    const auto found =
        route_source_credit_by_bucket_.find(route_source_credit_key(query_index, source_id));
    return found == route_source_credit_by_bucket_.end() ? 0.0f : found->second;
}

float GraphV02::route_source_retry_prior_scale() const {
    if (params_.route_source_retry_prior_mode == "none") {
        return 0.0f;
    }
    if (params_.route_source_retry_prior_mode == "decay") {
        return static_cast<float>(
            std::pow(params_.route_source_retry_prior_decay, current_epoch_));
    }
    if (params_.route_source_retry_prior_mode == "warmup") {
        return current_epoch_ < params_.route_source_retry_prior_warmup_epochs ? 1.0f
                                                                               : 0.0f;
    }
    return 1.0f;
}

float GraphV02::route_source_retry_prior_for_source(
    const std::string& source) const {
    if (params_.route_source_retry_policy != "source-credit" ||
        params_.route_source_retry_tiebreak != "source-prior") {
        return 0.0f;
    }
    const float prior_scale = route_source_retry_prior_scale();
    if (prior_scale == 0.0f) {
        return 0.0f;
    }
    const auto priorities =
        parse_retry_source_priorities(params_.route_source_retry_priorities);
    const auto found = priorities.find(source);
    return found == priorities.end() ? 0.0f : found->second * prior_scale;
}

float GraphV02::route_credit_weight_for_candidate(int query_index, int value_pos) const {
    if (!route_credit_apply_active() || params_.route_credit_score_weight <= 0.0f) {
        return 1.0f;
    }
    const double scaled =
        static_cast<double>(params_.route_credit_score_weight) *
        static_cast<double>(route_credit_for_candidate(query_index, value_pos));
    return static_cast<float>(std::exp(std::clamp(scaled, -8.0, 8.0)));
}

float GraphV02::route_source_credit_weight_for_candidate(
    int query_index,
    int value_pos) const {
    if (!route_source_credit_ranking_apply_active() ||
        params_.route_source_credit_score_weight <= 0.0f) {
        return 1.0f;
    }
    const double scaled =
        static_cast<double>(params_.route_source_credit_score_weight) *
        static_cast<double>(route_source_credit_for_candidate(query_index, value_pos));
    return static_cast<float>(std::exp(std::clamp(scaled, -8.0, 8.0)));
}

float GraphV02::route_candidate_base_weight_for_vote(
    int query_index,
    int value_pos,
    std::size_t rank_index,
    std::size_t candidate_count,
    const std::array<int, FieldTable::ByteValues>& value_counts,
    const std::string& effective_agg,
    bool include_source_credit) const {
    float candidate_weight = 1.0f;
    if (effective_agg == "weighted-vote") {
        if (params_.route_candidate_score == "recency") {
            candidate_weight = static_cast<float>(candidate_count - rank_index);
        } else if (params_.route_candidate_score == "value-vote" &&
                   value_pos >= 0 && value_pos < params_.N) {
            const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            candidate_weight =
                static_cast<float>(value_counts[static_cast<std::size_t>(value)]);
        }
        candidate_weight *= route_credit_weight_for_candidate(query_index, value_pos);
        if (include_source_credit) {
            candidate_weight *=
                route_source_credit_weight_for_candidate(query_index, value_pos);
        }
    }
    return candidate_weight;
}

float GraphV02::route_quality_candidate_weight_basis_for_vote(
    int query_index,
    int value_pos,
    std::size_t rank_index,
    std::size_t candidate_count,
    const std::array<int, FieldTable::ByteValues>& value_counts,
    float base_weight) const {
    if (params_.route_quality_candidate_weight_basis == "base" ||
        !route_quality_candidate_weight_apply_active(params_)) {
        return base_weight;
    }
    if (params_.route_quality_candidate_weight_basis != "quality-score" ||
        value_pos < 0 ||
        value_pos >= params_.N ||
        candidate_count == 0) {
        return base_weight;
    }

    const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
    const int value_count =
        value_counts[static_cast<std::size_t>(value)];
    int best_other_count = 0;
    for (std::size_t candidate_value = 0;
         candidate_value < value_counts.size();
         ++candidate_value) {
        if (candidate_value == static_cast<std::size_t>(value)) {
            continue;
        }
        best_other_count =
            std::max(best_other_count, value_counts[candidate_value]);
    }
    const double denom =
        static_cast<double>(std::max<std::size_t>(1U, candidate_count));
    const double value_share =
        static_cast<double>(value_count) / denom;
    const double value_margin =
        static_cast<double>(value_count - best_other_count) / denom;
    const double rank_share =
        candidate_count <= 1
            ? 1.0
            : 1.0 -
                  static_cast<double>(rank_index) /
                      static_cast<double>(candidate_count - 1);
    const double source_delta =
        static_cast<double>(
            route_source_credit_weight_for_candidate(query_index, value_pos)) -
        1.0;
    const double edge_delta =
        static_cast<double>(
            route_credit_weight_for_candidate(query_index, value_pos)) -
        1.0;
    const double score =
        1.0 +
        static_cast<double>(params_.route_quality_vote_margin_weight) *
            value_margin +
        static_cast<double>(params_.route_quality_top_share_weight) *
            value_share +
        static_cast<double>(params_.route_quality_source_credit_weight) *
            source_delta +
        static_cast<double>(params_.route_quality_edge_credit_weight) *
            edge_delta +
        0.25 * rank_share;
    if (!std::isfinite(score)) {
        return 0.0f;
    }
    return static_cast<float>(std::max(0.0, score));
}

float GraphV02::route_quality_candidate_weight_factor(
    float base_weight,
    float mean_base_weight) const {
    if (!route_quality_candidate_weight_apply_active(params_) ||
        mean_base_weight <= 0.0f ||
        base_weight < 0.0f) {
        return 1.0f;
    }
    const double relative =
        static_cast<double>(base_weight / mean_base_weight) - 1.0;
    const double unclamped =
        1.0 +
        static_cast<double>(params_.route_quality_candidate_weight_beta) *
            relative;
    return static_cast<float>(
        std::clamp(
            unclamped,
            static_cast<double>(params_.route_quality_candidate_weight_min),
            static_cast<double>(params_.route_quality_candidate_weight_max)));
}

float GraphV02::route_candidate_mean_base_weight_for_vote(
    int query_index,
    const std::vector<int>& vote_positions,
    const std::array<int, FieldTable::ByteValues>& value_counts,
    const std::string& effective_agg,
    bool include_source_credit) const {
    double sum = 0.0;
    int count = 0;
    for (std::size_t rank_index = 0; rank_index < vote_positions.size(); ++rank_index) {
        const int value_pos = vote_positions[rank_index];
        if (value_pos < 0 || value_pos >= params_.N) {
            continue;
        }
        if (!route_source_candidate_allowed(query_index, value_pos)) {
            continue;
        }
        sum += static_cast<double>(
            route_quality_candidate_weight_basis_for_vote(
                query_index,
                value_pos,
                rank_index,
                vote_positions.size(),
                value_counts,
                route_candidate_base_weight_for_vote(
                    query_index,
                    value_pos,
                    rank_index,
                    vote_positions.size(),
                    value_counts,
                    effective_agg,
                    include_source_credit)));
        ++count;
    }
    return count > 0 ? static_cast<float>(sum / static_cast<double>(count)) : 0.0f;
}

float GraphV02::route_candidate_effective_weight_for_vote(
    int query_index,
    int value_pos,
    std::size_t rank_index,
    std::size_t candidate_count,
    const std::array<int, FieldTable::ByteValues>& value_counts,
    const std::string& effective_agg,
    float mean_base_weight,
    bool include_source_credit) const {
    const float base_weight = route_candidate_base_weight_for_vote(
        query_index,
        value_pos,
        rank_index,
        candidate_count,
        value_counts,
        effective_agg,
        include_source_credit);
    const float basis_weight = route_quality_candidate_weight_basis_for_vote(
        query_index,
        value_pos,
        rank_index,
        candidate_count,
        value_counts,
        base_weight);
    return base_weight *
           route_quality_candidate_weight_factor(basis_weight, mean_base_weight);
}

float GraphV02::route_source_credit_strength_scale_for_node(int index) const {
    if (!route_source_credit_strength_apply_active() ||
        index < 0 ||
        index >= static_cast<int>(route_hint_fallback_used_.size()) ||
        !route_hint_fallback_used_[static_cast<std::size_t>(index)] ||
        params_.route_source_credit_score_weight <= 0.0f) {
        return 1.0f;
    }
    if (params_.route_fallback_source == "noisy-route-code") {
        return 1.0f;
    }
    const float primary_credit =
        route_source_credit_for_source(index, primary_route_source_id());
    const float fallback_credit =
        route_source_credit_for_source(index, fallback_route_source_id());
    const double positive_signal =
        std::max(0.0, static_cast<double>(fallback_credit - primary_credit));
    const double bounded_signal = std::clamp(
        positive_signal * static_cast<double>(params_.route_source_credit_score_weight),
        0.0,
        1.0);
    return static_cast<float>(1.0 + bounded_signal);
}

bool GraphV02::route_source_filter_active() const {
    return route_source_credit_apply_active() &&
           params_.route_source_filter_mode != "off";
}

bool GraphV02::route_source_candidate_allowed(int query_index, int value_pos) const {
    if (!route_source_filter_active()) {
        return true;
    }
    if (value_pos < 0 || value_pos >= params_.N) {
        return false;
    }
    if (params_.route_source_filter_mode == "negative-credit") {
        const float credit = route_source_credit_for_candidate(query_index, value_pos);
        return credit >= params_.route_source_filter_threshold;
    }
    return true;
}

bool GraphV02::route_source_node_has_allowed_candidate(int index) const {
    if (!route_source_filter_active()) {
        return true;
    }
    if (index < 0 ||
        index >= static_cast<int>(route_hint_candidate_value_positions_.size())) {
        return true;
    }
    const auto& candidates =
        route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
    bool saw_candidate = false;
    for (const int value_pos : candidates) {
        if (value_pos < 0 || value_pos >= params_.N) {
            continue;
        }
        saw_candidate = true;
        if (route_source_candidate_allowed(index, value_pos)) {
            return true;
        }
    }
    if (!saw_candidate &&
        index < static_cast<int>(route_hint_value_positions_.size())) {
        const int value_pos = route_hint_value_positions_[static_cast<std::size_t>(index)];
        if (value_pos >= 0 && value_pos < params_.N) {
            saw_candidate = true;
            if (route_source_candidate_allowed(index, value_pos)) {
                return true;
            }
        }
    }
    return !saw_candidate;
}

bool GraphV02::route_credit_learn_active() const {
    return params_.route_credit_learning != 0 &&
           params_.route_credit_mode != "off" &&
           current_epoch_ >= params_.route_credit_learn_after_epoch;
}

bool GraphV02::route_credit_apply_active() const {
    return params_.route_credit_learning != 0 &&
           params_.route_credit_mode != "off" &&
           current_epoch_ >= params_.route_credit_apply_after_epoch;
}

bool GraphV02::route_source_credit_active() const {
    return params_.route_source_credit_learning != 0;
}

bool GraphV02::route_source_credit_apply_active() const {
    return route_source_credit_active() &&
           params_.route_source_credit_apply_mode != "off" &&
           current_epoch_ >= params_.route_credit_apply_after_epoch;
}

bool GraphV02::route_source_credit_ranking_apply_active() const {
    return route_source_credit_apply_active() &&
           (params_.route_source_credit_apply_mode == "ranking" ||
            params_.route_source_credit_apply_mode == "ranking-strength");
}

bool GraphV02::route_source_credit_strength_apply_active() const {
    return route_source_credit_apply_active() &&
           (params_.route_source_credit_apply_mode == "strength" ||
            params_.route_source_credit_apply_mode == "ranking-strength");
}

void GraphV02::apply_route_credit_learning() {
    const float decay_scale = 1.0f - params_.route_credit_decay;
    if (route_credit_learn_active()) {
        if (params_.route_plasticity_ledger != 0) {
            const float ledger_decay_scale =
                1.0f - params_.route_plasticity_ledger_decay;
            for (auto& entry : route_plasticity_ledger_) {
                entry.second *= ledger_decay_scale;
            }
        } else if (params_.route_credit_mode == "query-value") {
            for (auto& entry : route_credit_by_query_value_) {
                entry.second *= decay_scale;
            }
        } else {
            if (route_credit_by_value_pos_.empty()) {
                return;
            }
            for (float& credit : route_credit_by_value_pos_) {
                credit *= decay_scale;
            }
        }
    }
    if (route_source_credit_active()) {
        const float source_decay_scale = 1.0f - params_.route_source_credit_decay;
        for (auto& entry : route_source_credit_by_bucket_) {
            entry.second *= source_decay_scale;
        }
    }

    for (int index = 0; index < params_.N; ++index) {
        if (route_hint_weights_[static_cast<std::size_t>(index)] <= 0.0f) {
            continue;
        }
        const auto target_value = nodes_[static_cast<std::size_t>(index)].target_byte;

        if (route_source_credit_active() &&
            route_hint_correct_value_positions_[static_cast<std::size_t>(index)] >= 0) {
            auto update_source_credit = [this, index](const std::string& source_id,
                                                       float delta) {
                float& credit =
                    route_source_credit_by_bucket_[route_source_credit_key(index, source_id)];
                credit += delta;
                credit = std::clamp(
                    credit,
                    -params_.route_source_credit_clip,
                    params_.route_source_credit_clip);
            };

            const bool primary_has_correct =
                !route_hint_primary_has_correct_.empty() &&
                route_hint_primary_has_correct_[static_cast<std::size_t>(index)];
            if (primary_has_correct) {
                update_source_credit(
                    primary_route_source_id(),
                    params_.route_source_credit_eta_reward);
            } else {
                update_source_credit(
                    primary_route_source_id(),
                    -params_.route_source_credit_eta_slash);
            }

            const auto& candidates =
                route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
            const auto& candidate_sources =
                route_hint_candidate_source_ids_[static_cast<std::size_t>(index)];
            std::unordered_map<std::string, bool> source_seen;
            std::unordered_map<std::string, bool> source_has_correct;
            for (std::size_t rank = 0; rank < candidates.size(); ++rank) {
                if (rank >= candidate_sources.size()) {
                    continue;
                }
                const std::string& source_id = candidate_sources[rank];
                if (source_id.empty() || source_id == primary_route_source_id()) {
                    continue;
                }
                const int value_pos = candidates[rank];
                if (value_pos < 0 || value_pos >= params_.N) {
                    continue;
                }
                source_seen[source_id] = true;
                if (value_pos ==
                    route_hint_correct_value_positions_[static_cast<std::size_t>(index)]) {
                    source_has_correct[source_id] = true;
                }
            }
            for (const auto& entry : source_seen) {
                const std::string& source_id = entry.first;
                const bool recovered =
                    source_has_correct.find(source_id) != source_has_correct.end() &&
                    source_has_correct[source_id];
                update_source_credit(
                    source_id,
                    recovered ? params_.route_source_credit_eta_reward
                              : -params_.route_source_credit_eta_slash);
            }
        }

        if (!route_credit_learn_active()) {
            continue;
        }

        std::vector<int> candidates =
            route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
        if (candidates.empty()) {
            const int selected_pos =
                route_hint_value_positions_[static_cast<std::size_t>(index)];
            if (selected_pos >= 0) {
                candidates.push_back(selected_pos);
            }
        }
        for (const int value_pos : candidates) {
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            const auto value = nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            float& credit = params_.route_plasticity_ledger != 0
                                ? route_plasticity_ledger_[
                                      route_plasticity_ledger_key(index, value_pos)]
                            : params_.route_credit_mode == "query-value"
                                ? route_credit_by_query_value_[
                                      route_credit_edge_key(index, value_pos)]
                                : route_credit_by_value_pos_[
                                      static_cast<std::size_t>(value_pos)];
            if (value == target_value) {
                credit += params_.route_credit_eta_reward;
            } else {
                credit -= params_.route_credit_eta_slash;
            }
            credit = std::clamp(
                credit,
                -params_.route_credit_clip,
                params_.route_credit_clip);
        }
    }
}

void GraphV02::apply_route_fallback_source(const ByteDataset::Window& window) {
    if (!route_hint_active()) {
        return;
    }

    for (const auto& query : window.kv_queries) {
        if (query.query_pos < 0 || query.query_pos >= params_.N) {
            continue;
        }
        route_hint_primary_has_correct_[static_cast<std::size_t>(query.query_pos)] =
            candidate_positions_contain_correct(query.query_pos);
    }

    if (params_.route_fallback_source == "off" &&
        params_.route_source_retry_source == "off") {
        return;
    }

    std::unordered_map<int, std::vector<int>> raw_candidates_by_query;
    for (const auto& hint : window.route_hints) {
        if (hint.query_pos >= 0 && hint.query_pos < params_.N) {
            raw_candidates_by_query[hint.query_pos] = hint.candidate_value_positions;
        }
    }
    std::vector<std::string> retry_sources;
    if (params_.route_source_retry_policy == "source-credit") {
        retry_sources = split_source_list(params_.route_source_retry_candidates);
    } else if (params_.route_source_retry_source != "off") {
        retry_sources.push_back(params_.route_source_retry_source);
    }
    const bool retry_uses_joint =
        std::find(retry_sources.begin(), retry_sources.end(), "joint-code-key") !=
        retry_sources.end();
    std::unordered_map<std::uint32_t, std::vector<const ByteDataset::KVRecord*>>
        joint_records_by_bucket;
    if (params_.route_fallback_source == "joint-code-key" ||
        retry_uses_joint) {
        for (const auto& record : window.kv_records) {
            if (record.marker_pos < 0 || record.value_pos < 0) {
                continue;
            }
            joint_records_by_bucket[joint_code_hash_for_key(record.key)].push_back(&record);
        }
    }
    const auto noisy_source_uses_wrong = [this](int query_pos) {
        if (params_.route_noisy_source_rate <= 0.0f) {
            return false;
        }
        if (params_.route_noisy_source_rate >= 1.0f) {
            return true;
        }
        std::uint32_t hash = 2166136261u;
        hash = fnv1a_update(hash, static_cast<std::uint8_t>(query_pos & 0xff));
        hash = fnv1a_update(hash, static_cast<std::uint8_t>((query_pos >> 8) & 0xff));
        hash = fnv1a_update(hash, static_cast<std::uint8_t>(params_.seed & 0xff));
        hash = fnv1a_update(hash, static_cast<std::uint8_t>((params_.seed >> 8) & 0xff));
        hash = fnv1a_update(hash, 0x9du);
        const double sample =
            static_cast<double>(hash % 1000000u) / 1000000.0;
        return sample < static_cast<double>(params_.route_noisy_source_rate);
    };
    const auto collect_source_positions =
        [this,
         &window,
         &raw_candidates_by_query,
         &joint_records_by_bucket,
         &noisy_source_uses_wrong](const std::string& source,
                                   const ByteDataset::KVQuery& query) {
            std::vector<int> positions;
            if (source == "off") {
                return positions;
            }
            if (source == "raw-key") {
                const auto found = raw_candidates_by_query.find(query.query_pos);
                if (found != raw_candidates_by_query.end()) {
                    positions = found->second;
                }
                if (positions.empty() && query.hit && query.value_pos >= 0) {
                    positions.push_back(query.value_pos);
                }
            } else if (source == "key-shape") {
                std::vector<const ByteDataset::KVRecord*> scored_records;
                for (const auto& record : window.kv_records) {
                    if (record.marker_pos < 0 || record.value_pos < 0 ||
                        record.marker_pos >= query.query_pos) {
                        continue;
                    }
                    scored_records.push_back(&record);
                }
                std::stable_sort(
                    scored_records.begin(),
                    scored_records.end(),
                    [&query](const ByteDataset::KVRecord* lhs,
                             const ByteDataset::KVRecord* rhs) {
                        const double lhs_score = key_shape_score(query.key, lhs->key);
                        const double rhs_score = key_shape_score(query.key, rhs->key);
                        if (lhs_score != rhs_score) {
                            return lhs_score > rhs_score;
                        }
                        return lhs->marker_pos > rhs->marker_pos;
                    });
                const int limit =
                    std::min(params_.K_route, static_cast<int>(scored_records.size()));
                for (int rank = 0; rank < limit; ++rank) {
                    positions.push_back(
                        scored_records[static_cast<std::size_t>(rank)]->value_pos);
                }
            } else if (source == "joint-code-key") {
                const auto bucket_found =
                    joint_records_by_bucket.find(joint_code_hash_for_key(query.key));
                if (bucket_found != joint_records_by_bucket.end()) {
                    std::vector<const ByteDataset::KVRecord*> joint_records;
                    for (const auto* record : bucket_found->second) {
                        if (record->marker_pos >= 0 && record->marker_pos < query.query_pos) {
                            joint_records.push_back(record);
                        }
                    }
                    std::stable_sort(
                        joint_records.begin(),
                        joint_records.end(),
                        [](const ByteDataset::KVRecord* lhs,
                           const ByteDataset::KVRecord* rhs) {
                            return lhs->marker_pos > rhs->marker_pos;
                        });
                    const int limit =
                        std::min(params_.K_route, static_cast<int>(joint_records.size()));
                    for (int rank = 0; rank < limit; ++rank) {
                        positions.push_back(
                            joint_records[static_cast<std::size_t>(rank)]->value_pos);
                    }
                }
            } else if (source == "noisy-route-code") {
                if (!noisy_source_uses_wrong(query.query_pos) && query.hit &&
                    query.value_pos >= 0) {
                    positions.push_back(query.value_pos);
                } else {
                    std::vector<const ByteDataset::KVRecord*> wrong_records;
                    for (const auto& record : window.kv_records) {
                        if (record.marker_pos < 0 || record.value_pos < 0 ||
                            record.marker_pos >= query.query_pos ||
                            (query.hit && record.value_pos == query.value_pos)) {
                            continue;
                        }
                        wrong_records.push_back(&record);
                    }
                    if (!wrong_records.empty()) {
                        const std::size_t start =
                            (static_cast<std::size_t>(query.query_pos) +
                             static_cast<std::size_t>(params_.seed)) %
                            wrong_records.size();
                        const int limit =
                            std::min(params_.K_route, static_cast<int>(wrong_records.size()));
                        for (int offset = 0; offset < limit; ++offset) {
                            positions.push_back(
                                wrong_records[(start + static_cast<std::size_t>(offset)) %
                                              wrong_records.size()]
                                    ->value_pos);
                        }
                    }
                }
            }
            return positions;
        };

    for (const auto& query : window.kv_queries) {
        if (query.query_pos < 0 || query.query_pos >= params_.N) {
            continue;
        }
        const auto query_index = static_cast<std::size_t>(query.query_pos);
        if (route_hint_primary_has_correct_[query_index]) {
            continue;
        }

        const std::vector<int> fallback_positions =
            collect_source_positions(params_.route_fallback_source, query);
        struct RetryCandidateEntry {
            int value_pos = -1;
            std::string source_id;
            float source_credit = 0.0f;
            float source_prior = 0.0f;
            float quality_delta = 0.0f;
            float source_score = 0.0f;
            int source_order = 0;
            int rank = 0;
        };
        struct RetrySourceSnapshot {
            std::string source_name;
            std::string source_id;
            float source_credit = 0.0f;
            float source_prior = 0.0f;
            std::vector<int> positions;
            float raw_quality_proxy = 0.0f;
            float norm_quality_proxy = 0.0f;
            float quality_delta = 0.0f;
            int source_order = 0;
        };
        std::vector<RetryCandidateEntry> retry_entries;
        auto store_retry_source_quality = [&](const std::string& source_id,
                                              float quality_proxy,
                                              float norm_quality_proxy,
                                              float quality_delta) {
            if (!route_quality_source_proxy_diagnostics_active(params_)) {
                return;
            }
            if (source_id == "retry-raw-key") {
                route_quality_retry_raw_proxy_[query_index] = quality_proxy;
                route_quality_retry_raw_norm_proxy_[query_index] =
                    norm_quality_proxy;
                route_quality_retry_raw_delta_[query_index] = quality_delta;
            } else if (source_id == "retry-key-shape") {
                route_quality_retry_keyshape_proxy_[query_index] = quality_proxy;
                route_quality_retry_keyshape_norm_proxy_[query_index] =
                    norm_quality_proxy;
                route_quality_retry_keyshape_delta_[query_index] = quality_delta;
            } else if (source_id == "retry-noisy-route-code") {
                route_quality_retry_noisy_proxy_[query_index] = quality_proxy;
                route_quality_retry_noisy_norm_proxy_[query_index] =
                    norm_quality_proxy;
                route_quality_retry_noisy_delta_[query_index] = quality_delta;
            }
        };
        if (params_.route_source_retry_policy == "source-credit") {
            std::vector<RetrySourceSnapshot> retry_source_snapshots;
            for (std::size_t source_index = 0; source_index < retry_sources.size();
                 ++source_index) {
                const std::string& retry_source = retry_sources[source_index];
                const std::string retry_source_id =
                    retry_route_source_id_for_source(retry_source);
                const float source_credit =
                    route_source_credit_for_source(query.query_pos, retry_source_id);
                const std::vector<int> positions =
                    collect_source_positions(retry_source, query);
                const float quality_proxy =
                    route_quality_source_proxy_diagnostics_active(params_)
                        ? route_quality_source_ranking_proxy(params_, nodes_, positions)
                        : 0.0f;
                retry_source_snapshots.push_back(
                    {retry_source,
                     retry_source_id,
                     source_credit,
                     route_source_retry_prior_for_source(retry_source),
                     positions,
                     quality_proxy,
                     quality_proxy,
                     0.0f,
                     static_cast<int>(source_index)});
            }
            if (params_.route_quality_source_normalization != "none" &&
                !retry_source_snapshots.empty()) {
                double sum = 0.0;
                double count = 0.0;
                for (const RetrySourceSnapshot& snapshot : retry_source_snapshots) {
                    if (snapshot.positions.empty()) {
                        continue;
                    }
                    sum += static_cast<double>(snapshot.raw_quality_proxy);
                    count += 1.0;
                }
                if (count > 0.0) {
                    const double mean = sum / count;
                    double variance = 0.0;
                    if (params_.route_quality_source_normalization == "zscore") {
                        for (const RetrySourceSnapshot& snapshot :
                             retry_source_snapshots) {
                            if (snapshot.positions.empty()) {
                                continue;
                            }
                            const double diff =
                                static_cast<double>(snapshot.raw_quality_proxy) -
                                mean;
                            variance += diff * diff;
                        }
                        variance /= count;
                    }
                    const double scale =
                        params_.route_quality_source_normalization == "zscore"
                            ? std::sqrt(
                                  variance +
                                  static_cast<double>(
                                      params_.route_quality_source_norm_eps))
                            : 1.0;
                    for (RetrySourceSnapshot& snapshot : retry_source_snapshots) {
                        if (snapshot.positions.empty()) {
                            continue;
                        }
                        const double centered =
                            static_cast<double>(snapshot.raw_quality_proxy) -
                            mean;
                        snapshot.norm_quality_proxy =
                            static_cast<float>(centered / scale);
                    }
                }
            }
            for (RetrySourceSnapshot& snapshot : retry_source_snapshots) {
                const float source_quality_delta =
                    route_quality_source_ranking_apply_active(params_)
                        ? std::clamp(
                              params_.route_quality_source_ranking_beta *
                                  snapshot.norm_quality_proxy,
                              -0.25f,
                              0.25f)
                        : 0.0f;
                snapshot.quality_delta = source_quality_delta;
                store_retry_source_quality(
                    snapshot.source_id,
                    snapshot.raw_quality_proxy,
                    snapshot.norm_quality_proxy,
                    snapshot.quality_delta);
                const int limit = std::min(
                    params_.route_source_retry_per_source_limit,
                    static_cast<int>(snapshot.positions.size()));
                for (int rank = 0; rank < limit; ++rank) {
                    const int value_pos =
                        snapshot.positions[static_cast<std::size_t>(rank)];
                    const float source_score =
                        route_quality_source_ranking_apply_active(params_)
                            ? snapshot.source_credit + snapshot.quality_delta
                            : snapshot.source_credit;
                    retry_entries.push_back(
                        {value_pos,
                         snapshot.source_id,
                         snapshot.source_credit,
                         snapshot.source_prior,
                         snapshot.quality_delta,
                         source_score,
                         snapshot.source_order,
                         rank});
                }
            }
            std::stable_sort(
                retry_entries.begin(),
                retry_entries.end(),
                [](const RetryCandidateEntry& lhs,
                   const RetryCandidateEntry& rhs) {
                    if (lhs.source_score != rhs.source_score) {
                        return lhs.source_score > rhs.source_score;
                    }
                    if (lhs.source_credit != rhs.source_credit) {
                        return lhs.source_credit > rhs.source_credit;
                    }
                    if (lhs.source_prior != rhs.source_prior) {
                        return lhs.source_prior > rhs.source_prior;
                    }
                    if (lhs.source_order != rhs.source_order) {
                        return lhs.source_order < rhs.source_order;
                    }
                    return lhs.rank < rhs.rank;
                });
        } else {
            const std::vector<int> retry_positions =
                collect_source_positions(params_.route_source_retry_source, query);
            const std::string retry_source_id = retry_route_source_id();
            for (int rank = 0; rank < static_cast<int>(retry_positions.size()); ++rank) {
                retry_entries.push_back(
                    {retry_positions[static_cast<std::size_t>(rank)],
                     retry_source_id,
                     route_source_credit_for_source(query.query_pos, retry_source_id),
                     0.0f,
                     0.0f,
                     route_source_credit_for_source(query.query_pos, retry_source_id),
                     0,
                     rank});
            }
        }

        auto& candidates = route_hint_candidate_value_positions_[query_index];
        auto& candidate_keys = route_hint_candidate_keys_[query_index];
        auto& candidate_sources = route_hint_candidate_source_ids_[query_index];
        if (candidate_sources.size() != candidates.size()) {
            candidate_sources.assign(candidates.size(), primary_route_source_id());
        }
        std::vector<int> inserted_positions;
        std::vector<std::string> inserted_keys;
        std::vector<std::string> inserted_sources;
        std::vector<float> inserted_quality_deltas;
        bool retry_inserted = false;
        bool retry_recovered = false;
        auto append_position = [&](int value_pos,
                                   const std::string& source_id,
                                   float quality_delta) {
            if (value_pos < 0 || value_pos >= params_.N) {
                return;
            }
            if (std::find(candidates.begin(), candidates.end(), value_pos) !=
                    candidates.end() ||
                std::find(inserted_positions.begin(), inserted_positions.end(), value_pos) !=
                    inserted_positions.end()) {
                return;
            }
            inserted_positions.push_back(value_pos);
            inserted_keys.push_back(
                route_value_position_keys_[static_cast<std::size_t>(value_pos)]);
            inserted_sources.push_back(source_id);
            inserted_quality_deltas.push_back(quality_delta);
            if (source_id.rfind("retry-", 0) == 0) {
                retry_inserted = true;
                if (query.hit && value_pos == query.value_pos) {
                    retry_recovered = true;
                }
            }
        };
        auto append_positions = [&](const std::vector<int>& positions,
                                    const std::string& source_id) {
            for (const int value_pos : positions) {
                if (value_pos < 0 || value_pos >= params_.N) {
                    continue;
                }
                append_position(value_pos, source_id, 0.0f);
            }
        };
        for (const RetryCandidateEntry& entry : retry_entries) {
            append_position(entry.value_pos, entry.source_id, entry.quality_delta);
        }
        append_positions(fallback_positions, fallback_route_source_id());
        if (inserted_positions.empty()) {
            continue;
        }

        candidates.insert(candidates.begin(), inserted_positions.begin(), inserted_positions.end());
        candidate_keys.insert(candidate_keys.begin(), inserted_keys.begin(), inserted_keys.end());
        candidate_sources.insert(
            candidate_sources.begin(),
            inserted_sources.begin(),
            inserted_sources.end());
        if (static_cast<int>(candidates.size()) > params_.K_route) {
            candidates.resize(static_cast<std::size_t>(params_.K_route));
        }
        if (static_cast<int>(candidate_keys.size()) > params_.K_route) {
            candidate_keys.resize(static_cast<std::size_t>(params_.K_route));
        }
        if (static_cast<int>(candidate_sources.size()) > params_.K_route) {
            candidate_sources.resize(static_cast<std::size_t>(params_.K_route));
        }
        const int selected_pos = candidates.front();
        route_hint_value_positions_[query_index] = selected_pos;
        route_hint_values_[query_index] =
            nodes_[static_cast<std::size_t>(selected_pos)].input_byte;
        route_hint_weights_[query_index] = std::max(route_hint_weights_[query_index], 1.0f);
        route_hint_fallback_used_[query_index] = true;
        route_hint_fallback_recovered_[query_index] =
            candidate_positions_contain_correct(query.query_pos);
        route_hint_retry_used_[query_index] = retry_inserted;
        route_hint_retry_recovered_[query_index] = retry_recovered;
        if (!inserted_quality_deltas.empty()) {
            route_hint_quality_source_ranking_delta_[query_index] =
                inserted_quality_deltas.front();
        }
    }
}

void GraphV02::apply_route_noisy_source(const ByteDataset::Window& window) {
    if (!route_hint_active() || params_.route_noisy_source_rate <= 0.0f) {
        return;
    }

    std::unordered_map<std::uint32_t, std::vector<const ByteDataset::KVRecord*>> buckets;
    for (const auto& record : window.kv_records) {
        if (record.marker_pos < 0 || record.value_pos < 0) {
            continue;
        }
        buckets[route_code_hash_for_key(record.key)].push_back(&record);
    }

    for (const auto& query : window.kv_queries) {
        if (query.query_pos < 0 || query.query_pos >= params_.N ||
            !should_inject_noisy_route_source(query.query_pos)) {
            continue;
        }

        const auto query_index = static_cast<std::size_t>(query.query_pos);
        auto& candidates = route_hint_candidate_value_positions_[query_index];
        auto& candidate_keys = route_hint_candidate_keys_[query_index];
        auto& candidate_sources = route_hint_candidate_source_ids_[query_index];
        if (candidate_sources.size() != candidates.size()) {
            candidate_sources.assign(candidates.size(), primary_route_source_id());
        }

        int noisy_pos = -1;
        const auto bucket_found = buckets.find(route_code_hash_for_key(query.key));
        if (bucket_found != buckets.end()) {
            std::vector<const ByteDataset::KVRecord*> records;
            for (const auto* record : bucket_found->second) {
                if (record->marker_pos < query.query_pos &&
                    record->value_pos != query.value_pos &&
                    std::find(candidates.begin(), candidates.end(), record->value_pos) ==
                        candidates.end()) {
                    records.push_back(record);
                }
            }
            std::stable_sort(
                records.begin(),
                records.end(),
                [](const ByteDataset::KVRecord* lhs, const ByteDataset::KVRecord* rhs) {
                    return lhs->marker_pos > rhs->marker_pos;
                });
            if (!records.empty()) {
                noisy_pos = records.front()->value_pos;
            }
        }
        if (noisy_pos < 0) {
            noisy_pos = wrong_route_value_position_for_node(query.query_pos);
        }
        if (noisy_pos < 0 || noisy_pos >= params_.N ||
            std::find(candidates.begin(), candidates.end(), noisy_pos) !=
                candidates.end()) {
            continue;
        }

        candidates.push_back(noisy_pos);
        candidate_keys.push_back(route_value_position_keys_[static_cast<std::size_t>(noisy_pos)]);
        candidate_sources.push_back(noisy_route_source_id());

        if (route_hint_weights_[query_index] <= 0.0f) {
            route_hint_value_positions_[query_index] = noisy_pos;
            route_hint_values_[query_index] =
                nodes_[static_cast<std::size_t>(noisy_pos)].input_byte;
            route_hint_weights_[query_index] = 1.0f;
        }
    }
}

std::string GraphV02::joint_code_signature_for_key(const std::string& key) const {
    std::string signature;
    signature.reserve(key.size());
    for (const unsigned char byte : key) {
        signature.push_back(static_cast<char>(
            best_joint_byte(static_cast<std::uint8_t>(byte))));
    }
    return signature;
}

std::uint32_t GraphV02::joint_code_hash_for_key(const std::string& key) const {
    std::uint32_t hash = 2166136261u;
    for (const unsigned char byte : joint_code_signature_for_key(key)) {
        hash = fnv1a_update(hash, static_cast<std::uint8_t>(byte));
    }
    return mask_hash(hash, params_.route_hash_bits);
}

bool GraphV02::route_code_aux_kept(int index, std::uint8_t input_byte) const {
    if (params_.route_code_key_region_keep_prob >= 1.0f) {
        return true;
    }
    if (params_.route_code_key_region_keep_prob <= 0.0f) {
        return false;
    }
    return deterministic_route_code_unit(params_.seed, index, input_byte, 0x5bU) <
           static_cast<double>(params_.route_code_key_region_keep_prob);
}

std::uint8_t GraphV02::route_code_aux_target(
    int index,
    std::uint8_t key_byte,
    std::uint8_t target_byte) const {
    if (params_.route_code_aux_noise_rate <= 0.0f) {
        return target_byte;
    }
    if (params_.route_code_aux_noise_rate >= 1.0f ||
        deterministic_route_code_unit(params_.seed, index, key_byte, 0xc3U) <
            static_cast<double>(params_.route_code_aux_noise_rate)) {
        return deterministic_corrupt_byte(params_.seed, index, key_byte, target_byte);
    }
    return target_byte;
}

std::uint8_t GraphV02::route_code_for_byte(std::uint8_t input_byte) const {
    const auto high =
        static_cast<std::uint8_t>(route_field_.argmax_state(0, input_byte));
    const auto low =
        static_cast<std::uint8_t>(route_field_.argmax_state(1, input_byte));
    return static_cast<std::uint8_t>(high * FieldTable::States + low);
}

std::string GraphV02::route_code_signature_for_key(const std::string& key) const {
    std::string signature;
    signature.reserve(key.size());
    for (const unsigned char byte : key) {
        signature.push_back(static_cast<char>(
            route_code_for_byte(static_cast<std::uint8_t>(byte))));
    }
    return signature;
}

std::uint32_t GraphV02::route_code_hash_for_key(const std::string& key) const {
    std::uint32_t hash = 2166136261u;
    for (const unsigned char byte : route_code_signature_for_key(key)) {
        hash = fnv1a_update(hash, static_cast<std::uint8_t>(byte));
    }
    return mask_hash(hash, params_.route_hash_bits);
}

std::uint32_t GraphV02::learned_code_hash_for_key(const std::string& key) const {
    if (route_code_key_hash_active()) {
        return route_code_hash_for_key(key);
    }
    return joint_code_hash_for_key(key);
}

void GraphV02::refresh_key_region_diagnostics(const ByteDataset::Window& window) {
    key_region_count_ = 0;
    key_region_joint_decode_hit_count_ = 0;
    key_region_route_decode_hit_count_ = 0;
    raw_key_unique_count_ = 0;
    joint_key_unique_count_ = 0;
    route_key_unique_count_ = 0;
    joint_vs_raw_candidate_overlap_sum_ = 0.0;
    joint_vs_raw_candidate_overlap_count_ = 0;
    route_vs_raw_candidate_overlap_sum_ = 0.0;
    route_vs_raw_candidate_overlap_count_ = 0;

    std::unordered_set<std::string> raw_keys;
    std::unordered_set<std::string> joint_signatures;
    std::unordered_set<std::string> route_signatures;
    const auto visit_key = [&](const std::string& key) {
        if (key.empty()) {
            return;
        }
        raw_keys.insert(key);
        joint_signatures.insert(joint_code_signature_for_key(key));
        route_signatures.insert(route_code_signature_for_key(key));
        for (const unsigned char byte : key) {
            ++key_region_count_;
            if (best_joint_byte(static_cast<std::uint8_t>(byte)) ==
                static_cast<std::uint8_t>(byte)) {
                ++key_region_joint_decode_hit_count_;
            }
            if (route_code_for_byte(static_cast<std::uint8_t>(byte)) ==
                static_cast<std::uint8_t>(byte)) {
                ++key_region_route_decode_hit_count_;
            }
        }
    };

    for (const auto& record : window.kv_records) {
        visit_key(record.key);
    }
    for (const auto& query : window.kv_queries) {
        visit_key(query.key);
    }

    raw_key_unique_count_ = static_cast<int>(raw_keys.size());
    joint_key_unique_count_ = static_cast<int>(joint_signatures.size());
    route_key_unique_count_ = static_cast<int>(route_signatures.size());
}

void GraphV02::rebuild_learned_code_key_route_hints(const ByteDataset::Window& window) {
    std::unordered_map<int, std::vector<int>> raw_candidates_by_query;
    for (const auto& hint : window.route_hints) {
        raw_candidates_by_query[hint.query_pos] = hint.candidate_value_positions;
    }

    std::fill(route_hint_values_.begin(), route_hint_values_.end(), 0);
    std::fill(route_hint_value_positions_.begin(), route_hint_value_positions_.end(), -1);
    for (auto& candidates : route_hint_candidate_value_positions_) {
        candidates.clear();
    }
    std::fill(route_hint_weights_.begin(), route_hint_weights_.end(), 0.0f);

    route_candidate_query_count_ = 0;
    route_candidate_hit_count_ = 0;
    route_candidate_top1_hit_count_ = 0;
    route_candidate_rank_sum_ = 0.0;
    route_bucket_load_sum_ = 0;
    route_bucket_load_max_ = 0;
    route_bucket_collision_count_ = 0;

    std::unordered_map<std::uint32_t, std::vector<const ByteDataset::KVRecord*>> buckets;
    for (const auto& record : window.kv_records) {
        if (record.marker_pos < 0 || record.value_pos < 0) {
            continue;
        }
        buckets[learned_code_hash_for_key(record.key)].push_back(&record);
    }

    for (const auto& query : window.kv_queries) {
        if (query.query_pos < 0 || query.query_pos >= params_.N) {
            continue;
        }
        ++route_candidate_query_count_;
        const auto bucket_found = buckets.find(learned_code_hash_for_key(query.key));
        if (bucket_found == buckets.end() || bucket_found->second.empty()) {
            continue;
        }

        std::vector<const ByteDataset::KVRecord*> candidates;
        for (const auto* record : bucket_found->second) {
            if (record->marker_pos < query.query_pos) {
                candidates.push_back(record);
            }
        }
        if (candidates.empty()) {
            continue;
        }

        std::stable_sort(
            candidates.begin(),
            candidates.end(),
            [](const ByteDataset::KVRecord* lhs, const ByteDataset::KVRecord* rhs) {
                return lhs->marker_pos > rhs->marker_pos;
            });

        route_bucket_load_sum_ += static_cast<int>(candidates.size());
        route_bucket_load_max_ =
            std::max(route_bucket_load_max_, static_cast<int>(candidates.size()));
        bool has_other_key = false;
        for (const auto* record : candidates) {
            if (record->key != query.key) {
                has_other_key = true;
                break;
            }
        }
        if (has_other_key) {
            ++route_bucket_collision_count_;
        }

        const int candidate_limit =
            std::min(params_.K_route, static_cast<int>(candidates.size()));
        bool selected = false;
        std::vector<int> joint_candidate_positions;
        joint_candidate_positions.reserve(static_cast<std::size_t>(candidate_limit));
        for (int rank = 1; rank <= candidate_limit; ++rank) {
            const auto* entry = candidates[static_cast<std::size_t>(rank - 1)];
            if (!selected) {
                route_hint_values_[static_cast<std::size_t>(query.query_pos)] = entry->value;
                route_hint_value_positions_[static_cast<std::size_t>(query.query_pos)] =
                    entry->value_pos;
                route_hint_weights_[static_cast<std::size_t>(query.query_pos)] = 1.0f;
                selected = true;
            }
            joint_candidate_positions.push_back(entry->value_pos);
            route_hint_candidate_value_positions_[static_cast<std::size_t>(query.query_pos)]
                .push_back(entry->value_pos);
            if (query.hit && entry->value_pos == query.value_pos) {
                ++route_candidate_hit_count_;
                route_candidate_rank_sum_ += static_cast<double>(rank);
                if (rank == 1) {
                    ++route_candidate_top1_hit_count_;
                }
                break;
            }
        }
        const auto raw_found = raw_candidates_by_query.find(query.query_pos);
        if (raw_found != raw_candidates_by_query.end() && !raw_found->second.empty()) {
            int overlap = 0;
            for (const int raw_pos : raw_found->second) {
                if (std::find(
                        joint_candidate_positions.begin(),
                        joint_candidate_positions.end(),
                        raw_pos) != joint_candidate_positions.end()) {
                    ++overlap;
                }
            }
            if (joint_code_key_hash_active()) {
                joint_vs_raw_candidate_overlap_sum_ +=
                    static_cast<double>(overlap) /
                    static_cast<double>(raw_found->second.size());
                ++joint_vs_raw_candidate_overlap_count_;
            } else if (route_code_key_hash_active()) {
                route_vs_raw_candidate_overlap_sum_ +=
                    static_cast<double>(overlap) /
                    static_cast<double>(raw_found->second.size());
                ++route_vs_raw_candidate_overlap_count_;
            }
        }
    }
}

bool GraphV02::routing_triggered(int index) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    if (std::abs(node.reservoir) > params_.route_reservoir_threshold) {
        return true;
    }
    return node.age_since_change >= params_.stagnation_window &&
           local_disagreement(index) >= params_.stagnation_threshold;
}

void GraphV02::rebuild_routing_table() {
    if (!routing_enabled()) {
        std::fill(route_keys_.begin(), route_keys_.end(), 0);
        routing_.clear();
        return;
    }

    std::vector<float> route_scores(static_cast<std::size_t>(params_.N), 0.0f);
    for (int i = 0; i < params_.N; ++i) {
        const NodeV02& node = nodes_[static_cast<std::size_t>(i)];
        route_keys_[static_cast<std::size_t>(i)] = route_key_for_node(node);
        route_scores[static_cast<std::size_t>(i)] = route_score_for_node(node);
    }
    routing_.build_from_keys(route_keys_, route_scores, params_.K_jump);
}

std::uint8_t GraphV02::route_key_for_node(const NodeV02& node) const {
    if (params_.routing_source == "input-byte") {
        return node.input_byte;
    }
    if (params_.routing_source == "joint-code") {
        return best_joint_byte(node.input_byte);
    }
    if (params_.routing_source == "state-code") {
        return static_cast<std::uint8_t>(
            node.state[0] * FieldTable::States + node.state[1]);
    }
    return 0;
}

float GraphV02::route_score_for_node(const NodeV02& node) const {
    // Higher route confidence means the node's current route key is less
    // ambiguous under the current field/coupling state.
    return static_cast<float>(route_confidence_margin(node.input_byte));
}

double GraphV02::route_min_anchor_gap() const {
    if (params_.route_min_anchor_gap >= 0.0f) {
        return static_cast<double>(params_.route_min_anchor_gap);
    }
    return static_cast<double>(params_.lambda_u);
}

double GraphV02::route_stress(int index) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    return static_cast<double>(std::abs(node.reservoir)) /
           std::max(static_cast<double>(node.tick), static_cast<double>(params_.eps_T));
}

double GraphV02::effective_route_min_anchor_gap(int index) const {
    const double base_gap = route_min_anchor_gap();
    const double adaptive_reduction =
        static_cast<double>(params_.route_adaptive_gap_scale) * route_stress(index);
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    const double confidence_reduction =
        static_cast<double>(params_.route_confidence_gap_scale) *
        route_confidence_margin(node.input_byte);
    return std::max(0.0, base_gap - adaptive_reduction - confidence_reduction);
}

double GraphV02::route_anchor_gap(int index) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    const auto anchor_byte = route_anchor_cache_[static_cast<std::size_t>(node.input_byte)];
    const auto anchor_high = static_cast<std::uint8_t>(anchor_byte / FieldTable::States);
    const auto anchor_low = static_cast<std::uint8_t>(anchor_byte % FieldTable::States);
    return pair_energy(node.input_byte, node.state[0], node.state[1]) -
           pair_energy(node.input_byte, anchor_high, anchor_low);
}

void GraphV02::refresh_route_confidence_cache() {
    for (int byte = 0; byte < FieldTable::ByteValues; ++byte) {
        route_confidence_cache_[static_cast<std::size_t>(byte)] =
            compute_route_confidence_margin(static_cast<std::uint8_t>(byte));
    }
}

void GraphV02::refresh_route_anchor_cache() {
    for (int byte = 0; byte < FieldTable::ByteValues; ++byte) {
        route_anchor_cache_[static_cast<std::size_t>(byte)] =
            best_joint_byte(static_cast<std::uint8_t>(byte));
    }
}

int GraphV02::edge_disagreement(int index, int neighbor_index) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    const NodeV02& neighbor = nodes_[static_cast<std::size_t>(neighbor_index)];
    int total = 0;
    for (int channel = 0; channel < params_.channels; ++channel) {
        total += node.state[static_cast<std::size_t>(channel)] !=
                         neighbor.state[static_cast<std::size_t>(channel)]
                     ? 1
                     : 0;
    }
    return total;
}

int GraphV02::local_disagreement(int index) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    int total = 0;
    for (int n = 0; n < params_.K; ++n) {
        total += edge_disagreement(
            index, node.neighbors[static_cast<std::size_t>(n)]);
    }
    return total;
}

int GraphV02::active_jump_neighbor_count(int index) const {
    std::array<int, 8> effective_neighbors{};
    const int neighbor_count = fill_effective_neighbors(index, effective_neighbors);
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    int count = 0;
    for (int n = 0; n < neighbor_count; ++n) {
        bool is_local = false;
        for (int local = 0; local < params_.K; ++local) {
            if (node.neighbors[static_cast<std::size_t>(local)] ==
                effective_neighbors[static_cast<std::size_t>(n)]) {
                is_local = true;
                break;
            }
        }
        if (!is_local) {
            ++count;
        }
    }
    return count;
}

int GraphV02::fill_effective_neighbors(
    int index,
    std::array<int, 8>& out_neighbors,
    JumpNeighborDiagnostics* diagnostics) const {
    if (diagnostics != nullptr) {
        *diagnostics = {};
    }

    std::array<int, 8> local_neighbors{};
    std::array<int, 8> local_scores{};
    int local_count = 0;
    for (int distance = 1; distance <= params_.R && local_count < params_.K; ++distance) {
        local_neighbors[static_cast<std::size_t>(local_count++)] = wrap_index(index - distance, params_.N);
        if (local_count < params_.K) {
            local_neighbors[static_cast<std::size_t>(local_count++)] = wrap_index(index + distance, params_.N);
        }
    }

    for (int n = 0; n < params_.K; ++n) {
        local_scores[static_cast<std::size_t>(n)] =
            edge_disagreement(index, local_neighbors[static_cast<std::size_t>(n)]);
        out_neighbors[static_cast<std::size_t>(n)] = local_neighbors[static_cast<std::size_t>(n)];
    }

    if (!jump_neighbors_active() || !routing_triggered(index)) {
        return params_.K;
    }

    const double node_anchor_gap = route_anchor_gap(index);
    const double min_anchor_gap = effective_route_min_anchor_gap(index);
    // Tiny route-anchor gaps were still noisy on the fixture. Only let jump
    // neighbors displace locals when the current node is meaningfully off its
    // own inferred joint anchor.
    if (node_anchor_gap <= min_anchor_gap) {
        return params_.K;
    }
    const double confidence_gain = static_cast<double>(params_.route_accept_confidence_gain);
    const bool use_confidence_acceptance_slice = confidence_gain != 0.0;
    const double node_conf = use_confidence_acceptance_slice
                                 ? route_confidence_margin(
                                       nodes_[static_cast<std::size_t>(index)].input_byte)
                                 : 0.0;
    std::array<bool, 8> keep_local{};
    keep_local.fill(true);
    std::array<int, 8> selected_jumps{};
    selected_jumps.fill(-1);
    int selected_count = 0;

    const auto key = route_keys_[static_cast<std::size_t>(index)];
    const int limit = routing_.stored_count(key);
    for (int slot = 0; slot < limit && selected_count < params_.K_jump; ++slot) {
        if (diagnostics != nullptr) {
            ++diagnostics->candidate_slots_examined;
        }

        const int candidate = routing_.candidate_at(key, slot);
        if (candidate < 0 || candidate == index) {
            if (diagnostics != nullptr) {
                ++diagnostics->self_rejects;
            }
            continue;
        }
        if ((candidate % params_.C_colors) == (index % params_.C_colors)) {
            if (diagnostics != nullptr) {
                ++diagnostics->color_rejects;
            }
            continue;
        }
        if (route_anchor_gap(candidate) + 1.0e-6 >= node_anchor_gap) {
            if (diagnostics != nullptr) {
                ++diagnostics->anchor_gap_rejects;
            }
            continue;
        }
        if (use_confidence_acceptance_slice) {
            const double cand_conf = route_confidence_margin(
                nodes_[static_cast<std::size_t>(candidate)].input_byte);
            if (cand_conf <= node_conf + confidence_gain) {
                if (diagnostics != nullptr) {
                    ++diagnostics->confidence_gain_rejects;
                }
                continue;
            }
        }

        bool duplicate = false;
        for (int n = 0; n < params_.K; ++n) {
            if (local_neighbors[static_cast<std::size_t>(n)] == candidate) {
                duplicate = true;
                break;
            }
        }
        for (int used = 0; used < selected_count && !duplicate; ++used) {
            if (selected_jumps[static_cast<std::size_t>(used)] == candidate) {
                duplicate = true;
                break;
            }
        }
        if (duplicate) {
            if (diagnostics != nullptr) {
                ++diagnostics->local_duplicate_rejects;
            }
            continue;
        }

        int worst_local = -1;
        int worst_score = -1;
        for (int n = 0; n < params_.K; ++n) {
            if (!keep_local[static_cast<std::size_t>(n)]) {
                continue;
            }
            const int score = local_scores[static_cast<std::size_t>(n)];
            if (score > worst_score) {
                worst_score = score;
                worst_local = n;
            }
        }
        if (worst_local < 0) {
            break;
        }

        const int jump_score = edge_disagreement(index, candidate);
        if (jump_score >= worst_score) {
            if (diagnostics != nullptr) {
                ++diagnostics->local_score_rejects;
            }
            continue;
        }

        keep_local[static_cast<std::size_t>(worst_local)] = false;
        selected_jumps[static_cast<std::size_t>(selected_count++)] = candidate;
    }

    if (diagnostics != nullptr) {
        diagnostics->selected_jumps = selected_count;
        diagnostics->underfilled = selected_count < params_.K_jump;
    }

    int written = 0;
    for (int n = 0; n < params_.K; ++n) {
        if (keep_local[static_cast<std::size_t>(n)]) {
            out_neighbors[static_cast<std::size_t>(written++)] = local_neighbors[static_cast<std::size_t>(n)];
        }
    }
    for (int n = 0; n < selected_count; ++n) {
        out_neighbors[static_cast<std::size_t>(written++)] = selected_jumps[static_cast<std::size_t>(n)];
    }

    return written;
}

int GraphV02::ring_distance(int from, int to) const {
    const int diff = std::abs(from - to);
    return std::min(diff, params_.N - diff);
}

float GraphV02::delta_energy(int index, int channel, std::uint8_t new_state) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    return delta_energy(
        index,
        channel == 0 ? new_state : node.state[0],
        channel == 1 ? new_state : node.state[1]);
}

float GraphV02::delta_energy(int index, std::uint8_t new_high, std::uint8_t new_low) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    std::array<int, 8> effective_neighbors{};
    const int neighbor_count = fill_effective_neighbors(index, effective_neighbors);

    float delta = -params_.lambda_u *
                  (field_.score(0, node.input_byte, new_high) -
                   field_.score(0, node.input_byte, node.state[0]));
    delta += -params_.lambda_u *
             (field_.score(1, node.input_byte, new_low) -
              field_.score(1, node.input_byte, node.state[1]));

    for (int n = 0; n < neighbor_count; ++n) {
        const NodeV02& neighbor =
            nodes_[static_cast<std::size_t>(effective_neighbors[static_cast<std::size_t>(n)])];
        const float new_disagreement =
            (new_high != neighbor.state[0] ? 1.0f : 0.0f) +
            (new_low != neighbor.state[1] ? 1.0f : 0.0f);
        const float old_disagreement =
            (node.state[0] != neighbor.state[0] ? 1.0f : 0.0f) +
            (node.state[1] != neighbor.state[1] ? 1.0f : 0.0f);
        delta += params_.lambda_v * (new_disagreement - old_disagreement);
    }

    delta += -params_.lambda_b *
             (coupling_.score(node.input_byte, new_high, new_low) -
              coupling_.score(node.input_byte, node.state[0], node.state[1]));

    const auto& vote_positions =
        route_hint_candidate_value_positions_[static_cast<std::size_t>(index)];
    std::uint8_t value = 0;
    std::uint8_t policy_value = 0;
    const bool has_policy_value = route_hint_value_for_node(index, policy_value);
    const std::string effective_agg =
        has_policy_value ? route_effective_hint_agg_for_node(index, policy_value)
                         : params_.route_hint_agg;
    if (route_hint_active() &&
        effective_agg != "none" &&
        (effective_agg == "vote" || effective_agg == "weighted-vote") &&
        !vote_positions.empty()) {
        std::array<int, FieldTable::ByteValues> value_counts{};
        for (const int value_pos : vote_positions) {
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            const auto candidate_value =
                nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            ++value_counts[static_cast<std::size_t>(candidate_value)];
        }

        int valid_count = 0;
        float weight_sum = 0.0f;
        float route_vote_delta_high = 0.0f;
        float route_vote_delta_low = 0.0f;
        const float mean_base_weight = route_candidate_mean_base_weight_for_vote(
            index, vote_positions, value_counts, effective_agg);
        for (std::size_t rank_index = 0; rank_index < vote_positions.size(); ++rank_index) {
            const int value_pos = vote_positions[rank_index];
            if (value_pos < 0 || value_pos >= params_.N) {
                continue;
            }
            if (!route_source_candidate_allowed(index, value_pos)) {
                continue;
            }
            const auto candidate_value =
                nodes_[static_cast<std::size_t>(value_pos)].input_byte;
            const float candidate_weight = route_candidate_effective_weight_for_vote(
                index,
                value_pos,
                rank_index,
                vote_positions.size(),
                value_counts,
                effective_agg,
                mean_base_weight);
            const auto value_high =
                static_cast<std::uint8_t>(candidate_value / FieldTable::States);
            const auto value_low =
                static_cast<std::uint8_t>(candidate_value % FieldTable::States);
            route_vote_delta_high += candidate_weight *
                                     route_channel_delta(
                                         params_.route_delta_mode,
                                         params_.route_pull_scale,
                                         params_.route_push_scale,
                                         node.state[0],
                                         new_high,
                                         value_high);
            route_vote_delta_low += candidate_weight *
                                    route_channel_delta(
                                        params_.route_delta_mode,
                                        params_.route_pull_scale,
                                        params_.route_push_scale,
                                        node.state[1],
                                        new_low,
                                        value_low);
            weight_sum += candidate_weight;
            ++valid_count;
        }
        if (valid_count > 0 && weight_sum > 0.0f) {
            const float weight = route_hint_weights_[static_cast<std::size_t>(index)];
            std::uint8_t target_value = 0;
            const float route_strength =
                route_hint_proposal_value_for_node(index, target_value)
                    ? route_effective_strength_for_node(index, target_value)
                    : params_.lambda_route;
            const float high_strength =
                route_fallback_channel_effective_strength_for_node(
                    index,
                    0,
                    target_value,
                    route_strength);
            const float low_strength =
                route_fallback_channel_effective_strength_for_node(
                    index,
                    1,
                    target_value,
                    route_strength);
            const float route_vote_delta =
                high_strength * route_vote_delta_high + low_strength * route_vote_delta_low;
            delta += weight * (route_vote_delta / weight_sum);
        }
    } else if (route_hint_active() && effective_agg != "none" &&
               route_hint_value_for_node(index, value)) {
        const auto value_high = static_cast<std::uint8_t>(value / FieldTable::States);
        const auto value_low = static_cast<std::uint8_t>(value % FieldTable::States);
        const float weight = route_hint_weights_[static_cast<std::size_t>(index)];
        const float route_strength = route_effective_strength_for_node(index, value);
        const float high_delta =
            route_channel_delta(
                params_.route_delta_mode,
                params_.route_pull_scale,
                params_.route_push_scale,
                node.state[0],
                new_high,
                value_high);
        const float low_delta =
            route_channel_delta(
                params_.route_delta_mode,
                params_.route_pull_scale,
                params_.route_push_scale,
                node.state[1],
                new_low,
                value_low);
        const float high_strength =
            route_fallback_channel_effective_strength_for_node(
                index,
                0,
                value,
                route_strength);
        const float low_strength =
            route_fallback_channel_effective_strength_for_node(
                index,
                1,
                value,
                route_strength);
        const float route_delta =
            high_strength * high_delta + low_strength * low_delta;
        delta += weight * route_delta;
    }

    return delta;
}

int GraphV02::disagreement(int index) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    std::array<int, 8> effective_neighbors{};
    const int neighbor_count = fill_effective_neighbors(index, effective_neighbors);
    int total = 0;
    for (int n = 0; n < neighbor_count; ++n) {
        const NodeV02& neighbor =
            nodes_[static_cast<std::size_t>(effective_neighbors[static_cast<std::size_t>(n)])];
        for (int channel = 0; channel < params_.channels; ++channel) {
            total += node.state[static_cast<std::size_t>(channel)] !=
                             neighbor.state[static_cast<std::size_t>(channel)]
                         ? 1
                         : 0;
        }
    }
    return total;
}

float GraphV02::local_temperature(int index) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    return params_.T0 + params_.alpha_T * std::abs(node.reservoir) / (node.tick + params_.eps_T);
}

void GraphV02::try_update_node(
    int index,
    int& accepted,
    int& downhill,
    int& uphill,
    int& rejected,
    int& skipped) {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    const bool fallback_persist_active = route_fallback_persistence_active(index);
    if (fallback_persist_active) {
        ++route_fallback_persist_visits_[static_cast<std::size_t>(index)];
    }
    const float p_try =
        fallback_persist_active ? 1.0f
                                : std::min(1.0f, 1.0f / std::max(1.0f, node.tick));
    if (!rng_.bernoulli(p_try)) {
        ++skipped;
        return;
    }

    const Candidate candidate = sample_best_candidate(index);
    if (!candidate.valid) {
        ++rejected;
        return;
    }

    if (candidate.delta_eff <= 0.0f) {
        accept_update(index, candidate, accepted, downhill, uphill);
        return;
    }

    const bool stagnant =
        node.age_since_change >= params_.stagnation_window &&
        local_disagreement(index) >= params_.stagnation_threshold;
    if (!stagnant) {
        ++rejected;
        return;
    }

    const float temperature = local_temperature(index);
    const float acceptance =
        std::exp(-candidate.delta_eff / std::max(temperature + params_.eps_T, params_.eps_T));
    if (rng_.bernoulli(acceptance)) {
        accept_update(index, candidate, accepted, downhill, uphill);
        return;
    }

    ++rejected;
}

void GraphV02::accept_update(
    int index,
    const Candidate& candidate,
    int& accepted,
    int& downhill,
    int& uphill) {
    NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    node.state = candidate.state;
    std::array<int, 8> effective_neighbors{};
    const int neighbor_count = fill_effective_neighbors(index, effective_neighbors);

    const float q = candidate.delta_eff;
    for (int n = 0; n < neighbor_count; ++n) {
        NodeV02& neighbor =
            nodes_[static_cast<std::size_t>(effective_neighbors[static_cast<std::size_t>(n)])];
        neighbor.reservoir += params_.eta_r * q / static_cast<float>(neighbor_count);
    }
    node.tick = std::min(params_.tau_max, node.tick + params_.eta_tau * std::abs(q));
    changed_this_cycle_[static_cast<std::size_t>(index)] = true;

    ++accepted;
    if (candidate.delta_eff <= 0.0f) {
        ++downhill;
    } else {
        ++uphill;
    }
}

void GraphV02::relax_tick_and_reservoir() {
    for (NodeV02& node : nodes_) {
        node.tick = std::max(1.0f, (1.0f - params_.tau_decay) * node.tick + params_.tau_decay);
        node.reservoir *= (1.0f - params_.reservoir_decay);
    }
}

void GraphV02::update_age() {
    for (std::size_t i = 0; i < nodes_.size(); ++i) {
        NodeV02& node = nodes_[i];
        if (changed_this_cycle_[i]) {
            node.age_since_change = 0;
        } else if (node.age_since_change < std::numeric_limits<std::uint8_t>::max()) {
            ++node.age_since_change;
        }
    }
}

EpochMetricsV02 GraphV02::collect_metrics(
    int epoch,
    const std::array<std::uint8_t, FieldTable::ByteValues>& oracle_next,
    int changed,
    int downhill,
    int uphill,
    int rejected,
    int skipped) const {
    double byte_hits = 0.0;
    double field_byte_hits = 0.0;
    double joint_byte_hits = 0.0;
    double oracle_hits = 0.0;
    double ch0_hits = 0.0;
    double ch1_hits = 0.0;
    double field_ch0_hits = 0.0;
    double field_ch1_hits = 0.0;
    double margin_sum = 0.0;
    double pair_margin_sum = 0.0;
    double disagreement_sum = 0.0;
    double tick_sum = 0.0;
    double abs_reservoir_sum = 0.0;
    double routing_trigger_sum = 0.0;
    double jump_candidate_sum = 0.0;
    double routing_hit_sum = 0.0;
    double active_jump_sum = 0.0;
    double active_jump_node_sum = 0.0;
    double jump_distance_sum = 0.0;
    double jump_distance_count = 0.0;
    double route_gap_pass_sum = 0.0;
    double triggered_route_anchor_gap_sum = 0.0;
    double max_triggered_route_anchor_gap = 0.0;
    double triggered_route_gate_sum = 0.0;
    double triggered_route_stress_sum = 0.0;
    double triggered_route_confidence_sum = 0.0;
    double max_triggered_route_confidence = 0.0;
    double route_diagnostic_count = 0.0;
    double route_key_anchor_match_sum = 0.0;
    double route_state_anchor_match_sum = 0.0;
    double route_key_state_match_sum = 0.0;
    double route_key_anchor_hamming_sum = 0.0;
    double triggered_route_key_anchor_match_sum = 0.0;
    double triggered_route_state_anchor_match_sum = 0.0;
    double triggered_route_key_state_match_sum = 0.0;
    double triggered_route_key_anchor_hamming_sum = 0.0;
    double triggered_anchor_gap_gt_0_sum = 0.0;
    double triggered_anchor_gap_gt_1e_6_sum = 0.0;
    double triggered_anchor_gap_gt_1e_4_sum = 0.0;
    double triggered_anchor_gap_gt_1e_3_sum = 0.0;
    double triggered_anchor_gap_gt_1e_2_sum = 0.0;
    double triggered_anchor_gap_gt_1e_1_sum = 0.0;
    double positive_triggered_anchor_gap_sum = 0.0;
    double positive_triggered_anchor_gap_count = 0.0;
    std::vector<double> triggered_anchor_gaps;
    std::vector<double> triggered_gate_margins;
    double triggered_route_gate_margin_sum = 0.0;
    double max_triggered_route_gate_margin = 0.0;
    double triggered_gap_equal_gate_sum = 0.0;
    double triggered_gap_below_gate_sum = 0.0;
    double triggered_route_state_anchor_hamming_sum = 0.0;
    double triggered_zero_gap_count = 0.0;
    double triggered_zero_gap_state_anchor_mismatch_sum = 0.0;
    double triggered_reservoir_reason_sum = 0.0;
    double triggered_stagnation_reason_sum = 0.0;
    double triggered_both_reasons_sum = 0.0;
    double route_hint_query_count = 0.0;
    double route_hint_applied_count = 0.0;
    double route_hint_applied_weight_sum = 0.0;
    double route_hint_value_match_sum = 0.0;
    double fixture_query_byte_hits = 0.0;
    double fixture_query_hi_hits = 0.0;
    double fixture_query_lo_hits = 0.0;
    double fixture_query_field_hits = 0.0;
    double fixture_query_joint_hits = 0.0;
    double query_route_hint_margin_sum = 0.0;
    double query_local_margin_against_route_sum = 0.0;
    double query_effective_route_margin_sum = 0.0;
    double route_strength_sum = 0.0;
    double route_strength_max = 0.0;
    std::vector<double> route_strength_values;
    double route_candidate_corrupt_count = 0.0;
    double route_correct_candidate_count = 0.0;
    double route_wrong_hint_count = 0.0;
    double route_wrong_hint_strength_sum = 0.0;
    double route_correct_hint_strength_sum = 0.0;
    double route_candidate_conf_correct_sum = 0.0;
    double route_candidate_conf_wrong_sum = 0.0;
    double route_value_top_correct_sum = 0.0;
    double route_value_conf_correct_sum = 0.0;
    double route_value_conf_wrong_sum = 0.0;
    double route_value_conf_correct_count = 0.0;
    double route_value_conf_wrong_count = 0.0;
    double route_agreement_top_correct_sum = 0.0;
    double route_agreement_conf_correct_sum = 0.0;
    double route_agreement_conf_wrong_sum = 0.0;
    double route_agreement_conf_correct_count = 0.0;
    double route_agreement_conf_wrong_count = 0.0;
    double route_gated_query_count = 0.0;
    double route_lowconf_query_count = 0.0;
    double route_highconf_query_count = 0.0;
    double route_lowconf_qacc_sum = 0.0;
    double route_highconf_qacc_sum = 0.0;
    double route_lowconf_wrong_strength_sum = 0.0;
    double route_highconf_wrong_strength_sum = 0.0;
    double route_lowconf_wrong_strength_count = 0.0;
    double route_highconf_wrong_strength_count = 0.0;
    double route_lowconf_candidate_recall_sum = 0.0;
    double route_highconf_candidate_recall_sum = 0.0;
    double route_lowconf_top1_sum = 0.0;
    double route_highconf_top1_sum = 0.0;
    double route_lowconf_correct_value_vote_share_sum = 0.0;
    double route_highconf_correct_value_vote_share_sum = 0.0;
    double route_lowconf_unique_values_sum = 0.0;
    double route_highconf_unique_values_sum = 0.0;
    double route_lowconf_vote_entropy_sum = 0.0;
    double route_highconf_vote_entropy_sum = 0.0;
    double route_lowconf_route_margin_sum = 0.0;
    double route_highconf_route_margin_sum = 0.0;
    double route_lowconf_local_margin_sum = 0.0;
    double route_highconf_local_margin_sum = 0.0;
    double route_lowconf_hi_acc_sum = 0.0;
    double route_highconf_hi_acc_sum = 0.0;
    double route_lowconf_lo_acc_sum = 0.0;
    double route_highconf_lo_acc_sum = 0.0;
    double route_agg_policy_vote_count = 0.0;
    double route_agg_policy_weighted_count = 0.0;
    double route_lowconf_policy_none_count = 0.0;
    double route_lowconf_policy_weak_vote_count = 0.0;
    double route_lowconf_policy_aggregate_count = 0.0;
    double route_lowconf_effective_strength_sum = 0.0;
    double route_highconf_effective_strength_sum = 0.0;
    double route_primary_recall_sum = 0.0;
    double route_primary_lowconf_count = 0.0;
    double route_fallback_used_count = 0.0;
    double route_fallback_recall_sum = 0.0;
    double route_fallback_qacc_sum = 0.0;
    double route_fallback_success_count = 0.0;
    double route_fallback_hi_acc_sum = 0.0;
    double route_fallback_lo_acc_sum = 0.0;
    double route_fallback_route_margin_sum = 0.0;
    double route_fallback_effective_strength_sum = 0.0;
    double route_fallback_hi_effective_strength_sum = 0.0;
    double route_fallback_lo_effective_strength_sum = 0.0;
    double route_fallback_strength_max = 0.0;
    double route_fallback_local_margin_sum = 0.0;
    double route_fallback_hi_local_margin_sum = 0.0;
    double route_fallback_lo_local_margin_sum = 0.0;
    double route_fallback_persist_used_sum = 0.0;
    double route_fallback_persist_cycles_sum = 0.0;
    std::vector<double> route_fallback_strength_values;
    double route_credit_correct_sum = 0.0;
    double route_credit_wrong_sum = 0.0;
    double route_credit_correct_count = 0.0;
    double route_credit_wrong_count = 0.0;
    double route_credit_rewarded_count = 0.0;
    double route_credit_slashed_count = 0.0;
    double route_credit_candidate_count = 0.0;
    double route_credit_top1_sum = 0.0;
    double route_credit_qacc_sum = 0.0;
    double route_credit_query_count = 0.0;
    double route_source_credit_primary_sum = 0.0;
    double route_source_credit_primary_count = 0.0;
    double route_source_credit_fallback_sum = 0.0;
    double route_source_credit_fallback_count = 0.0;
    double route_source_credit_noisy_sum = 0.0;
    double route_source_credit_noisy_count = 0.0;
    double route_source_credit_primary_slashed_count = 0.0;
    double route_source_credit_primary_candidate_count = 0.0;
    double route_source_credit_fallback_rewarded_count = 0.0;
    double route_source_credit_fallback_candidate_count = 0.0;
    double route_source_credit_noisy_slashed_count = 0.0;
    double route_source_credit_noisy_candidate_count = 0.0;
    double route_source_credit_ranking_query_count = 0.0;
    double route_source_credit_override_count = 0.0;
    double route_source_credit_selected_fallback_count = 0.0;
    double route_source_credit_strength_sum = 0.0;
    double route_source_credit_strength_count = 0.0;
    double route_noisy_source_used_count = 0.0;
    double route_noisy_source_selected_count = 0.0;
    double route_abstain_count = 0.0;
    double route_source_filter_candidate_count = 0.0;
    double route_source_filter_filtered_count = 0.0;
    double route_source_filter_query_count = 0.0;
    double route_source_filter_abstain_count = 0.0;
    double route_source_retry_used_count = 0.0;
    double route_source_retry_success_count = 0.0;
    double route_source_retry_raw_selected_count = 0.0;
    double route_source_retry_keyshape_selected_count = 0.0;
    double route_source_retry_noisy_selected_count = 0.0;
    double route_source_retry_raw_sum = 0.0;
    double route_source_retry_raw_count = 0.0;
    double route_source_retry_keyshape_sum = 0.0;
    double route_source_retry_keyshape_count = 0.0;
    double route_source_retry_noisy_sum = 0.0;
    double route_source_retry_noisy_count = 0.0;
    double route_source_retry_raw_rewarded_count = 0.0;
    double route_source_retry_keyshape_rewarded_count = 0.0;
    double route_source_retry_noisy_slashed_count = 0.0;
    double route_hint_candidate_lookup_count = 0.0;
    double route_hint_value_read_distance_sum = 0.0;
    double route_hint_vote_query_count = 0.0;
    double route_hint_vote_candidate_count_sum = 0.0;
    double route_hint_vote_margin_sum = 0.0;
    double route_hint_correct_value_vote_share_sum = 0.0;
    double route_hint_vote_entropy_sum = 0.0;
    double route_hint_unique_values_sum = 0.0;
    double route_quality_query_count = 0.0;
    double route_quality_logdet_sum = 0.0;
    double route_quality_logdet_norm_sum = 0.0;
    double route_quality_condition_sum = 0.0;
    double route_quality_source_ranking_delta_sum = 0.0;
    double route_quality_source_ranking_delta_count = 0.0;
    double route_quality_retry_raw_proxy_sum = 0.0;
    double route_quality_retry_raw_proxy_count = 0.0;
    double route_quality_retry_keyshape_proxy_sum = 0.0;
    double route_quality_retry_keyshape_proxy_count = 0.0;
    double route_quality_retry_noisy_proxy_sum = 0.0;
    double route_quality_retry_noisy_proxy_count = 0.0;
    double route_quality_retry_raw_norm_proxy_sum = 0.0;
    double route_quality_retry_raw_norm_proxy_count = 0.0;
    double route_quality_retry_keyshape_norm_proxy_sum = 0.0;
    double route_quality_retry_keyshape_norm_proxy_count = 0.0;
    double route_quality_retry_noisy_norm_proxy_sum = 0.0;
    double route_quality_retry_noisy_norm_proxy_count = 0.0;
    double route_quality_retry_raw_delta_sum = 0.0;
    double route_quality_retry_raw_delta_count = 0.0;
    double route_quality_retry_keyshape_delta_sum = 0.0;
    double route_quality_retry_keyshape_delta_count = 0.0;
    double route_quality_retry_noisy_delta_sum = 0.0;
    double route_quality_retry_noisy_delta_count = 0.0;
    double route_quality_selected_raw_qacc_sum = 0.0;
    double route_quality_selected_raw_qacc_count = 0.0;
    double route_quality_selected_keyshape_qacc_sum = 0.0;
    double route_quality_selected_keyshape_qacc_count = 0.0;
    double route_quality_selected_noisy_qacc_sum = 0.0;
    double route_quality_selected_noisy_qacc_count = 0.0;
    double route_quality_candidate_weight_correct_sum = 0.0;
    double route_quality_candidate_weight_correct_count = 0.0;
    double route_quality_candidate_weight_wrong_sum = 0.0;
    double route_quality_candidate_weight_wrong_count = 0.0;
    double route_quality_candidate_best_correct_sum = 0.0;
    double route_quality_candidate_best_correct_count = 0.0;
    double route_quality_candidate_factor_sum = 0.0;
    double route_quality_candidate_factor_count = 0.0;
    double route_quality_candidate_factor_correct_sum = 0.0;
    double route_quality_candidate_factor_correct_count = 0.0;
    double route_quality_candidate_factor_wrong_sum = 0.0;
    double route_quality_candidate_factor_wrong_count = 0.0;
    std::vector<double> route_quality_candidate_factors;
    double route_quality_candidate_factor_max = 0.0;
    double route_quality_candidate_weight_entropy_sum = 0.0;
    double route_quality_candidate_weight_top_share_sum = 0.0;
    double route_quality_candidate_weight_concentration_count = 0.0;
    double route_quality_score_sum = 0.0;
    double route_quality_score_correct_sum = 0.0;
    double route_quality_score_correct_count = 0.0;
    double route_quality_score_wrong_sum = 0.0;
    double route_quality_score_wrong_count = 0.0;
    double route_channel_query_count = 0.0;
    double route_channel_tension_det_sum = 0.0;
    double route_channel_tension_trace_sum = 0.0;
    double route_channel_tension_offdiag_sum = 0.0;
    double route_channel_hi_margin_sum = 0.0;
    double route_channel_lo_margin_sum = 0.0;
    double route_channel_margin_imbalance_sum = 0.0;
    auto observe_finite_metric = [](float value, double& sum, double& count) {
        if (std::isfinite(value)) {
            sum += static_cast<double>(value);
            count += 1.0;
        }
    };
    double gate_pass_active_jump_sum = 0.0;
    double jump_filter_node_count = 0.0;
    double jump_candidate_slots_examined_sum = 0.0;
    double jump_self_reject_sum = 0.0;
    double jump_local_duplicate_reject_sum = 0.0;
    double jump_color_reject_sum = 0.0;
    double jump_anchor_gap_reject_sum = 0.0;
    double jump_confidence_gain_reject_sum = 0.0;
    double jump_local_score_reject_sum = 0.0;
    double selected_jump_sum = 0.0;
    double jump_underfilled_sum = 0.0;

    for (int i = 0; i < params_.N; ++i) {
        const NodeV02& node = nodes_[static_cast<std::size_t>(i)];
        const auto pos0 = positive_state(i, 0);
        const auto pos1 = positive_state(i, 1);

        const auto relaxed_byte = static_cast<int>(node.state[0]) * 16 + static_cast<int>(node.state[1]);
        const auto field_state0 = static_cast<std::uint8_t>(field_.argmax_state(0, node.input_byte));
        const auto field_state1 = static_cast<std::uint8_t>(field_.argmax_state(1, node.input_byte));
        const auto field_byte = static_cast<int>(field_state0) * 16 + static_cast<int>(field_state1);
        const auto joint_byte = best_joint_byte(node.input_byte);
        const auto anchor_byte = route_anchor_cache_[static_cast<std::size_t>(node.input_byte)];

        byte_hits += relaxed_byte == static_cast<int>(node.target_byte) ? 1.0 : 0.0;
        field_byte_hits += field_byte == static_cast<int>(node.target_byte) ? 1.0 : 0.0;
        joint_byte_hits += joint_byte == node.target_byte ? 1.0 : 0.0;
        oracle_hits += oracle_next[node.input_byte] == node.target_byte ? 1.0 : 0.0;
        ch0_hits += node.state[0] == pos0 ? 1.0 : 0.0;
        ch1_hits += node.state[1] == pos1 ? 1.0 : 0.0;
        field_ch0_hits += field_state0 == pos0 ? 1.0 : 0.0;
        field_ch1_hits += field_state1 == pos1 ? 1.0 : 0.0;
        margin_sum += field_.positive_margin(0, node.input_byte, pos0);
        margin_sum += field_.positive_margin(1, node.input_byte, pos1);
        pair_margin_sum += positive_pair_margin(node.input_byte, pos0, pos1);
        disagreement_sum += static_cast<double>(disagreement(i));
        tick_sum += static_cast<double>(node.tick);
        abs_reservoir_sum += static_cast<double>(std::abs(node.reservoir));

        const float route_hint_weight = route_hint_weights_.empty()
                                            ? 0.0f
                                            : route_hint_weights_[static_cast<std::size_t>(i)];
        if (route_hint_weight > 0.0f) {
            std::uint8_t route_hint_value =
                route_hint_values_[static_cast<std::size_t>(i)];
            const int route_hint_value_pos =
                route_hint_value_positions_[static_cast<std::size_t>(i)];
            const auto& vote_positions =
                route_hint_candidate_value_positions_[static_cast<std::size_t>(i)];
            if (!vote_positions.empty()) {
                std::array<float, FieldTable::States> high_votes{};
                std::array<float, FieldTable::States> low_votes{};
                std::array<float, FieldTable::ByteValues> value_votes{};
                std::array<int, FieldTable::ByteValues> value_counts{};
                for (const int value_pos : vote_positions) {
                    if (value_pos < 0 || value_pos >= params_.N) {
                        continue;
                    }
                    const auto value =
                        nodes_[static_cast<std::size_t>(value_pos)].input_byte;
                    ++value_counts[static_cast<std::size_t>(value)];
                }
                int valid_vote_count = 0;
                float vote_weight_sum = 0.0f;
                std::vector<std::uint8_t> candidate_values;
                candidate_values.reserve(vote_positions.size());
                struct CandidateQualityWeight {
                    std::uint8_t value = 0;
                    float base_weight = 0.0f;
                    float factor = 1.0f;
                    float effective_weight = 0.0f;
                };
                std::vector<CandidateQualityWeight> candidate_quality_weights;
                candidate_quality_weights.reserve(vote_positions.size());
                const float mean_base_weight = route_candidate_mean_base_weight_for_vote(
                    i, vote_positions, value_counts, params_.route_hint_agg);
                for (std::size_t rank_index = 0; rank_index < vote_positions.size();
                     ++rank_index) {
                    const int value_pos = vote_positions[rank_index];
                    if (value_pos < 0 || value_pos >= params_.N) {
                        continue;
                    }
                    const auto value =
                        nodes_[static_cast<std::size_t>(value_pos)].input_byte;
                    const float base_weight = route_candidate_base_weight_for_vote(
                        i,
                        value_pos,
                        rank_index,
                        vote_positions.size(),
                        value_counts,
                        params_.route_hint_agg);
                    const float basis_weight =
                        route_quality_candidate_weight_basis_for_vote(
                            i,
                            value_pos,
                            rank_index,
                            vote_positions.size(),
                            value_counts,
                            base_weight);
                    const float candidate_factor =
                        route_quality_candidate_weight_factor(
                            basis_weight, mean_base_weight);
                    const float candidate_weight = base_weight * candidate_factor;
                    high_votes[static_cast<std::size_t>(value / FieldTable::States)] +=
                        candidate_weight;
                    low_votes[static_cast<std::size_t>(value % FieldTable::States)] +=
                        candidate_weight;
                    value_votes[static_cast<std::size_t>(value)] += candidate_weight;
                    candidate_values.push_back(value);
                    candidate_quality_weights.push_back(
                        {value, base_weight, candidate_factor, candidate_weight});
                    vote_weight_sum += candidate_weight;
                    ++valid_vote_count;
                }
                if (valid_vote_count > 0 && vote_weight_sum > 0.0f) {
                    const auto target_high =
                        static_cast<std::uint8_t>(node.target_byte / FieldTable::States);
                    const auto target_low =
                        static_cast<std::uint8_t>(node.target_byte % FieldTable::States);
                    float high_other = 0.0f;
                    float low_other = 0.0f;
                    for (int state = 0; state < FieldTable::States; ++state) {
                        if (state != target_high) {
                            high_other =
                                std::max(high_other, high_votes[static_cast<std::size_t>(state)]);
                        }
                        if (state != target_low) {
                            low_other =
                                std::max(low_other, low_votes[static_cast<std::size_t>(state)]);
                        }
                    }
                    const double hi_margin =
                        static_cast<double>(
                            (high_votes[static_cast<std::size_t>(target_high)] -
                             high_other) /
                            vote_weight_sum);
                    const double lo_margin =
                        static_cast<double>(
                            (low_votes[static_cast<std::size_t>(target_low)] -
                             low_other) /
                            vote_weight_sum);
                    const double vote_margin = 0.5 * (hi_margin + lo_margin);
                    route_hint_vote_query_count += 1.0;
                    route_hint_vote_candidate_count_sum +=
                        static_cast<double>(valid_vote_count);
                    route_hint_vote_margin_sum += vote_margin;
                    const auto target_value = node.target_byte;
                    const double top_value_share =
                        static_cast<double>(
                            value_votes[static_cast<std::size_t>(target_value)] /
                            vote_weight_sum);
                    route_hint_correct_value_vote_share_sum +=
                        top_value_share;
                    double entropy = 0.0;
                    double unique_values = 0.0;
                    for (float value_vote : value_votes) {
                        if (value_vote <= 0.0f) {
                            continue;
                        }
                        unique_values += 1.0;
                        const double p =
                            static_cast<double>(value_vote / vote_weight_sum);
                        entropy -= p * (std::log(p) / std::log(2.0));
                    }
                    route_hint_vote_entropy_sum += entropy;
                    route_hint_unique_values_sum += unique_values;
                    const double channel_offdiag = std::abs(hi_margin - lo_margin);
                    if (params_.route_quality_diagnostics != 0 ||
                        params_.route_quality_score != 0) {
                        float best_candidate_weight = -1.0f;
                        std::uint8_t best_candidate_value = 0;
                        for (const auto& candidate_quality :
                             candidate_quality_weights) {
                            const double normalized_weight =
                                static_cast<double>(
                                    candidate_quality.effective_weight /
                                    vote_weight_sum);
                            const double factor =
                                static_cast<double>(candidate_quality.factor);
                            route_quality_candidate_factor_sum +=
                                factor;
                            route_quality_candidate_factor_count += 1.0;
                            route_quality_candidate_factors.push_back(factor);
                            route_quality_candidate_factor_max =
                                std::max(route_quality_candidate_factor_max, factor);
                            if (candidate_quality.value == target_value) {
                                route_quality_candidate_weight_correct_sum +=
                                    normalized_weight;
                                route_quality_candidate_weight_correct_count += 1.0;
                                route_quality_candidate_factor_correct_sum +=
                                    factor;
                                route_quality_candidate_factor_correct_count += 1.0;
                            } else {
                                route_quality_candidate_weight_wrong_sum +=
                                    normalized_weight;
                                route_quality_candidate_weight_wrong_count += 1.0;
                                route_quality_candidate_factor_wrong_sum +=
                                    factor;
                                route_quality_candidate_factor_wrong_count += 1.0;
                            }
                            if (candidate_quality.effective_weight >
                                best_candidate_weight) {
                                best_candidate_weight =
                                    candidate_quality.effective_weight;
                                best_candidate_value = candidate_quality.value;
                            }
                        }
                        double weight_entropy = 0.0;
                        double weight_top_share = 0.0;
                        for (const auto& candidate_quality :
                             candidate_quality_weights) {
                            if (candidate_quality.effective_weight <= 0.0f) {
                                continue;
                            }
                            const double p =
                                static_cast<double>(
                                    candidate_quality.effective_weight /
                                    vote_weight_sum);
                            weight_top_share = std::max(weight_top_share, p);
                            weight_entropy -= p * (std::log(p) / std::log(2.0));
                        }
                        route_quality_candidate_weight_entropy_sum += weight_entropy;
                        route_quality_candidate_weight_top_share_sum += weight_top_share;
                        route_quality_candidate_weight_concentration_count += 1.0;
                        if (best_candidate_weight >= 0.0f) {
                            route_quality_candidate_best_correct_sum +=
                                best_candidate_value == target_value ? 1.0 : 0.0;
                            route_quality_candidate_best_correct_count += 1.0;
                        }
                        const QualityGramStats gram = candidate_value_gram_stats(
                            candidate_values,
                            static_cast<double>(params_.route_quality_eps));
                        const double source_credit_proxy =
                            static_cast<double>(
                                route_source_credit_weight_for_candidate(
                                    i, route_hint_value_pos));
                        const double edge_credit_proxy =
                            static_cast<double>(
                                route_credit_weight_for_candidate(
                                    i, route_hint_value_pos));
                        const double quality_score =
                            static_cast<double>(
                                params_.route_quality_vote_margin_weight) *
                                vote_margin +
                            static_cast<double>(
                                params_.route_quality_top_share_weight) *
                                top_value_share +
                            static_cast<double>(
                                params_.route_quality_source_credit_weight) *
                                source_credit_proxy +
                            static_cast<double>(
                                params_.route_quality_edge_credit_weight) *
                                edge_credit_proxy -
                            static_cast<double>(
                                params_.route_quality_entropy_weight) *
                                entropy -
                            static_cast<double>(
                                params_.route_quality_logdet_weight) *
                                gram.logdet_norm -
                            static_cast<double>(
                                params_.route_quality_channel_weight) *
                                channel_offdiag;
                        route_quality_query_count += 1.0;
                        route_quality_logdet_sum += gram.logdet;
                        route_quality_logdet_norm_sum += gram.logdet_norm;
                        route_quality_condition_sum += gram.condition;
                        route_quality_score_sum += quality_score;
                        if (route_hint_value == target_value) {
                            route_quality_score_correct_sum += quality_score;
                            route_quality_score_correct_count += 1.0;
                        } else {
                            route_quality_score_wrong_sum += quality_score;
                            route_quality_score_wrong_count += 1.0;
                        }
                    }
                    if (params_.route_channel_tension_diagnostics != 0) {
                        const double trace = hi_margin + lo_margin;
                        const double det =
                            hi_margin * lo_margin - channel_offdiag * channel_offdiag;
                        route_channel_query_count += 1.0;
                        route_channel_tension_det_sum += det;
                        route_channel_tension_trace_sum += trace;
                        route_channel_tension_offdiag_sum += channel_offdiag;
                        route_channel_hi_margin_sum += hi_margin;
                        route_channel_lo_margin_sum += lo_margin;
                        route_channel_margin_imbalance_sum += channel_offdiag;
                    }
                }
            }
            if (route_hint_value_pos >= 0 && route_hint_value_pos < params_.N) {
                route_hint_candidate_lookup_count += 1.0;
                route_hint_value_read_distance_sum +=
                    static_cast<double>(ring_distance(i, route_hint_value_pos));
                if (route_hint_parsed_active() || route_hint_kv_exact_active() ||
                    route_hint_kv_hash_active()) {
                    route_hint_value =
                        nodes_[static_cast<std::size_t>(route_hint_value_pos)].input_byte;
                }
            }
            route_hint_query_count += 1.0;
            const auto target_high =
                static_cast<std::uint8_t>(node.target_byte / FieldTable::States);
            const auto target_low =
                static_cast<std::uint8_t>(node.target_byte % FieldTable::States);
            fixture_query_hi_hits += node.state[0] == target_high ? 1.0 : 0.0;
            fixture_query_lo_hits += node.state[1] == target_low ? 1.0 : 0.0;
            const double route_margin = route_hint_margin_for_node(i, node.target_byte);
            const double local_margin = local_margin_against_route(i, node.target_byte);
            const double hi_local_margin =
                local_channel_margin_against_route(i, 0, target_high);
            const double lo_local_margin =
                local_channel_margin_against_route(i, 1, target_low);
            const double route_strength =
                static_cast<double>(route_effective_strength_for_node(i, node.target_byte));
            const int correct_value_pos =
                route_hint_correct_value_positions_.empty()
                    ? -1
                    : route_hint_correct_value_positions_[static_cast<std::size_t>(i)];
            const bool has_correct_candidate = correct_value_pos >= 0;
            const bool candidate_is_correct =
                has_correct_candidate && route_hint_value_pos == correct_value_pos;
            const bool final_candidate_recall =
                has_correct_candidate && candidate_positions_contain_correct(i);
            const bool primary_has_correct =
                !route_hint_primary_has_correct_.empty() &&
                route_hint_primary_has_correct_[static_cast<std::size_t>(i)];
            const bool fallback_used =
                !route_hint_fallback_used_.empty() &&
                route_hint_fallback_used_[static_cast<std::size_t>(i)];
            const bool fallback_recovered =
                !route_hint_fallback_recovered_.empty() &&
                route_hint_fallback_recovered_[static_cast<std::size_t>(i)];
            const bool retry_used =
                !route_hint_retry_used_.empty() &&
                route_hint_retry_used_[static_cast<std::size_t>(i)];
            const bool retry_recovered =
                !route_hint_retry_recovered_.empty() &&
                route_hint_retry_recovered_[static_cast<std::size_t>(i)];
            if (retry_used) {
                route_source_retry_used_count += 1.0;
                if (retry_recovered) {
                    route_source_retry_success_count += 1.0;
                }
            }
            const std::string selected_source_id =
                route_source_id_for_candidate(i, route_hint_value_pos);
            if (selected_source_id == "retry-raw-key") {
                route_source_retry_raw_selected_count += 1.0;
            } else if (selected_source_id == "retry-key-shape") {
                route_source_retry_keyshape_selected_count += 1.0;
            } else if (selected_source_id == "retry-noisy-route-code") {
                route_source_retry_noisy_selected_count += 1.0;
            }
            if (!route_quality_retry_raw_proxy_.empty()) {
                const auto idx = static_cast<std::size_t>(i);
                observe_finite_metric(
                    route_quality_retry_raw_proxy_[idx],
                    route_quality_retry_raw_proxy_sum,
                    route_quality_retry_raw_proxy_count);
                observe_finite_metric(
                    route_quality_retry_keyshape_proxy_[idx],
                    route_quality_retry_keyshape_proxy_sum,
                    route_quality_retry_keyshape_proxy_count);
                observe_finite_metric(
                    route_quality_retry_noisy_proxy_[idx],
                    route_quality_retry_noisy_proxy_sum,
                    route_quality_retry_noisy_proxy_count);
                observe_finite_metric(
                    route_quality_retry_raw_norm_proxy_[idx],
                    route_quality_retry_raw_norm_proxy_sum,
                    route_quality_retry_raw_norm_proxy_count);
                observe_finite_metric(
                    route_quality_retry_keyshape_norm_proxy_[idx],
                    route_quality_retry_keyshape_norm_proxy_sum,
                    route_quality_retry_keyshape_norm_proxy_count);
                observe_finite_metric(
                    route_quality_retry_noisy_norm_proxy_[idx],
                    route_quality_retry_noisy_norm_proxy_sum,
                    route_quality_retry_noisy_norm_proxy_count);
                observe_finite_metric(
                    route_quality_retry_raw_delta_[idx],
                    route_quality_retry_raw_delta_sum,
                    route_quality_retry_raw_delta_count);
                observe_finite_metric(
                    route_quality_retry_keyshape_delta_[idx],
                    route_quality_retry_keyshape_delta_sum,
                    route_quality_retry_keyshape_delta_count);
                observe_finite_metric(
                    route_quality_retry_noisy_delta_[idx],
                    route_quality_retry_noisy_delta_sum,
                    route_quality_retry_noisy_delta_count);
            }
            const double selected_query_hit =
                relaxed_byte == static_cast<int>(node.target_byte) ? 1.0 : 0.0;
            if (selected_source_id == "retry-raw-key") {
                route_quality_selected_raw_qacc_sum += selected_query_hit;
                route_quality_selected_raw_qacc_count += 1.0;
            } else if (selected_source_id == "retry-key-shape") {
                route_quality_selected_keyshape_qacc_sum += selected_query_hit;
                route_quality_selected_keyshape_qacc_count += 1.0;
            } else if (selected_source_id == "retry-noisy-route-code") {
                route_quality_selected_noisy_qacc_sum += selected_query_hit;
                route_quality_selected_noisy_qacc_count += 1.0;
            }
            const auto& candidate_sources =
                route_hint_candidate_source_ids_[static_cast<std::size_t>(i)];
            if (route_quality_source_ranking_apply_active(params_) && retry_used &&
                !route_hint_quality_source_ranking_delta_.empty()) {
                route_quality_source_ranking_delta_sum +=
                    route_hint_quality_source_ranking_delta_[
                        static_cast<std::size_t>(i)];
                route_quality_source_ranking_delta_count += 1.0;
            }
            if (route_source_filter_active()) {
                bool filter_saw_candidate = false;
                bool filter_saw_allowed = false;
                auto observe_filter_candidate = [&](int value_pos) {
                    if (value_pos < 0 || value_pos >= params_.N) {
                        return;
                    }
                    filter_saw_candidate = true;
                    route_source_filter_candidate_count += 1.0;
                    if (route_source_candidate_allowed(i, value_pos)) {
                        filter_saw_allowed = true;
                    } else {
                        route_source_filter_filtered_count += 1.0;
                    }
                };
                if (!vote_positions.empty()) {
                    for (const int value_pos : vote_positions) {
                        observe_filter_candidate(value_pos);
                    }
                } else {
                    observe_filter_candidate(route_hint_value_pos);
                }
                if (filter_saw_candidate) {
                    route_source_filter_query_count += 1.0;
                    if (!filter_saw_allowed) {
                        route_source_filter_abstain_count += 1.0;
                    }
                }
            }
            const bool noisy_source_used =
                std::find(candidate_sources.begin(),
                          candidate_sources.end(),
                          noisy_route_source_id()) != candidate_sources.end();
            if (noisy_source_used) {
                route_noisy_source_used_count += 1.0;
            }
            if (route_source_id_for_candidate(i, route_hint_value_pos) ==
                noisy_route_source_id()) {
                route_noisy_source_selected_count += 1.0;
            }
            if (route_source_credit_apply_active()) {
                const float source_strength_scale =
                    route_source_credit_strength_scale_for_node(i);
                route_source_credit_strength_sum +=
                    static_cast<double>(source_strength_scale);
                route_source_credit_strength_count += 1.0;
            }
            std::uint8_t source_policy_value = 0;
            const bool has_source_policy_value =
                route_hint_value_for_node(i, source_policy_value);
            const std::string source_effective_agg =
                has_source_policy_value
                    ? route_effective_hint_agg_for_node(i, source_policy_value)
                    : params_.route_hint_agg;
            if (route_source_credit_ranking_apply_active() &&
                source_effective_agg == "weighted-vote" &&
                !vote_positions.empty()) {
                const auto select_weighted_vote =
                    [this, i, &vote_positions](bool include_source_credit) {
                        std::array<int, FieldTable::ByteValues> value_counts{};
                        if (params_.route_candidate_score == "value-vote") {
                            for (const int value_pos : vote_positions) {
                                if (value_pos < 0 || value_pos >= params_.N) {
                                    continue;
                                }
                                const auto value =
                                    nodes_[static_cast<std::size_t>(value_pos)].input_byte;
                                ++value_counts[static_cast<std::size_t>(value)];
                            }
                        }

                        std::array<float, FieldTable::ByteValues> value_votes{};
                        std::array<float, FieldTable::ByteValues> best_candidate_weight{};
                        std::array<int, FieldTable::ByteValues> best_candidate_pos{};
                        best_candidate_pos.fill(-1);
                        for (std::size_t rank_index = 0;
                             rank_index < vote_positions.size();
                             ++rank_index) {
                            const int value_pos = vote_positions[rank_index];
                            if (value_pos < 0 || value_pos >= params_.N) {
                                continue;
                            }
                            const auto value =
                                nodes_[static_cast<std::size_t>(value_pos)].input_byte;
                            float candidate_weight = 1.0f;
                            if (params_.route_candidate_score == "recency") {
                                candidate_weight = static_cast<float>(
                                    vote_positions.size() - rank_index);
                            } else if (params_.route_candidate_score == "value-vote") {
                                candidate_weight = static_cast<float>(
                                    value_counts[static_cast<std::size_t>(value)]);
                            }
                            candidate_weight *= route_credit_weight_for_candidate(i, value_pos);
                            if (include_source_credit) {
                                candidate_weight *=
                                    route_source_credit_weight_for_candidate(i, value_pos);
                            }
                            const auto value_index = static_cast<std::size_t>(value);
                            value_votes[value_index] += candidate_weight;
                            if (candidate_weight > best_candidate_weight[value_index]) {
                                best_candidate_weight[value_index] = candidate_weight;
                                best_candidate_pos[value_index] = value_pos;
                            }
                        }

                        float best_vote = 0.0f;
                        int best_value = -1;
                        for (int value = 0; value < FieldTable::ByteValues; ++value) {
                            const float vote = value_votes[static_cast<std::size_t>(value)];
                            if (vote > best_vote) {
                                best_vote = vote;
                                best_value = value;
                            }
                        }
                        const int best_pos =
                            best_value >= 0
                                ? best_candidate_pos[static_cast<std::size_t>(best_value)]
                                : -1;
                        return std::pair<int, int>{best_value, best_pos};
                    };
                const auto baseline_selection = select_weighted_vote(false);
                const auto source_selection = select_weighted_vote(true);
                if (baseline_selection.first >= 0 && source_selection.first >= 0) {
                    route_source_credit_ranking_query_count += 1.0;
                    if (baseline_selection.first != source_selection.first) {
                        route_source_credit_override_count += 1.0;
                    }
                    if (route_source_id_for_candidate(i, source_selection.second)
                            .rfind("fallback-", 0) == 0) {
                        route_source_credit_selected_fallback_count += 1.0;
                    }
                }
            }
            const double query_hit =
                relaxed_byte == static_cast<int>(node.target_byte) ? 1.0 : 0.0;
            route_primary_recall_sum += primary_has_correct ? 1.0 : 0.0;
            if (fallback_used) {
                route_fallback_used_count += 1.0;
                route_fallback_qacc_sum += query_hit;
                route_fallback_recall_sum += final_candidate_recall ? 1.0 : 0.0;
                route_fallback_hi_acc_sum +=
                    node.state[0] == target_high ? 1.0 : 0.0;
                route_fallback_lo_acc_sum +=
                    node.state[1] == target_low ? 1.0 : 0.0;
                route_fallback_route_margin_sum += route_margin;
                route_fallback_effective_strength_sum += route_strength;
                route_fallback_hi_effective_strength_sum +=
                    route_fallback_channel_effective_strength_for_node(
                        i,
                        0,
                        node.target_byte,
                        static_cast<float>(route_strength));
                route_fallback_lo_effective_strength_sum +=
                    route_fallback_channel_effective_strength_for_node(
                        i,
                        1,
                        node.target_byte,
                        static_cast<float>(route_strength));
                route_fallback_strength_max =
                    std::max(route_fallback_strength_max, route_strength);
                route_fallback_strength_values.push_back(route_strength);
                route_fallback_local_margin_sum += local_margin;
                route_fallback_hi_local_margin_sum += hi_local_margin;
                route_fallback_lo_local_margin_sum += lo_local_margin;
                const int persist_visits =
                    route_fallback_persist_visits_.empty()
                        ? 0
                        : route_fallback_persist_visits_[static_cast<std::size_t>(i)];
                route_fallback_persist_used_sum += persist_visits > 0 ? 1.0 : 0.0;
                route_fallback_persist_cycles_sum += static_cast<double>(persist_visits);
                if (!primary_has_correct && fallback_recovered) {
                    route_fallback_success_count += 1.0;
                }
            }
            if (params_.route_credit_learning != 0) {
                std::vector<int> credit_positions = vote_positions;
                if (credit_positions.empty() && route_hint_value_pos >= 0) {
                    credit_positions.push_back(route_hint_value_pos);
                }
                if (!credit_positions.empty()) {
                    route_credit_query_count += 1.0;
                    route_credit_qacc_sum += query_hit;
                    int best_credit_pos = -1;
                    float best_credit = -std::numeric_limits<float>::infinity();
                    for (const int value_pos : credit_positions) {
                        if (value_pos < 0 || value_pos >= params_.N) {
                            continue;
                        }
                        const float credit = route_credit_for_candidate(i, value_pos);
                        const auto value =
                            nodes_[static_cast<std::size_t>(value_pos)].input_byte;
                        route_credit_candidate_count += 1.0;
                        if (credit > 0.0f) {
                            route_credit_rewarded_count += 1.0;
                        }
                        if (credit < 0.0f) {
                            route_credit_slashed_count += 1.0;
                        }
                        if (value == node.target_byte) {
                            route_credit_correct_sum += static_cast<double>(credit);
                            route_credit_correct_count += 1.0;
                        } else {
                            route_credit_wrong_sum += static_cast<double>(credit);
                            route_credit_wrong_count += 1.0;
                        }
                        if (credit > best_credit) {
                            best_credit = credit;
                            best_credit_pos = value_pos;
                        }
                    }
                    if (best_credit_pos >= 0 &&
                        nodes_[static_cast<std::size_t>(best_credit_pos)].input_byte ==
                            node.target_byte) {
                        route_credit_top1_sum += 1.0;
                    }
                }
            }
            const bool candidate_is_corrupted =
                !route_hint_corrupted_.empty() &&
                route_hint_corrupted_[static_cast<std::size_t>(i)];
            if (candidate_is_corrupted) {
                route_candidate_corrupt_count += 1.0;
            }
            if (candidate_is_correct) {
                route_correct_candidate_count += 1.0;
                route_correct_hint_strength_sum += route_strength;
                route_candidate_conf_correct_sum += static_cast<double>(route_hint_weight);
            } else if (has_correct_candidate) {
                route_wrong_hint_count += 1.0;
                route_wrong_hint_strength_sum += route_strength;
                route_candidate_conf_wrong_sum += static_cast<double>(route_hint_weight);
            }
            const double top_value_correct =
                route_top_value_is_target(i, node.target_byte);
            const double top_value_confidence = route_top_value_confidence_for_node(i);
            const double agreement_top_correct =
                route_agreement_top_value_is_target(i, node.target_byte);
            const double agreement_top_confidence =
                route_agreement_top_confidence_for_node(i);
            route_value_top_correct_sum += top_value_correct;
            if (top_value_correct > 0.5) {
                route_value_conf_correct_sum += top_value_confidence;
                route_value_conf_correct_count += 1.0;
            } else if (has_correct_candidate) {
                route_value_conf_wrong_sum += top_value_confidence;
                route_value_conf_wrong_count += 1.0;
            }
            route_agreement_top_correct_sum += agreement_top_correct;
            if (agreement_top_correct > 0.5) {
                route_agreement_conf_correct_sum += agreement_top_confidence;
                route_agreement_conf_correct_count += 1.0;
            } else if (has_correct_candidate) {
                route_agreement_conf_wrong_sum += agreement_top_confidence;
                route_agreement_conf_wrong_count += 1.0;
            }
            if (params_.route_hint_agg == "confidence-gated") {
                const double aggregation_confidence =
                    route_aggregation_confidence_for_node(i, route_hint_value);
                const bool high_confidence =
                    aggregation_confidence >=
                    static_cast<double>(params_.route_confidence_threshold);
                const std::string effective_agg =
                    route_effective_hint_agg_for_node(i, route_hint_value);
                if (!high_confidence) {
                    route_primary_lowconf_count += 1.0;
                }
                if (effective_agg == "none") {
                    route_abstain_count += 1.0;
                }
                double candidate_recall = 0.0;
                if (has_correct_candidate) {
                    if (!vote_positions.empty()) {
                        for (const int value_pos : vote_positions) {
                            if (value_pos == correct_value_pos) {
                                candidate_recall = 1.0;
                                break;
                            }
                        }
                    } else if (candidate_is_correct) {
                        candidate_recall = 1.0;
                    }
                }
                const double candidate_top1 = candidate_is_correct ? 1.0 : 0.0;

                std::array<float, FieldTable::ByteValues> subset_value_votes{};
                float subset_vote_weight_sum = 0.0f;
                if (effective_agg == "none") {
                    subset_vote_weight_sum = 0.0f;
                } else if (effective_agg == "top1" || vote_positions.empty()) {
                    subset_value_votes[static_cast<std::size_t>(route_hint_value)] = 1.0f;
                    subset_vote_weight_sum = 1.0f;
                } else {
                    std::array<int, FieldTable::ByteValues> subset_value_counts{};
                    if (params_.route_candidate_score == "value-vote") {
                        for (const int value_pos : vote_positions) {
                            if (value_pos < 0 || value_pos >= params_.N) {
                                continue;
                            }
                            const auto value =
                                nodes_[static_cast<std::size_t>(value_pos)].input_byte;
                            ++subset_value_counts[static_cast<std::size_t>(value)];
                        }
                    }
                    for (std::size_t rank_index = 0; rank_index < vote_positions.size();
                         ++rank_index) {
                        const int value_pos = vote_positions[rank_index];
                        if (value_pos < 0 || value_pos >= params_.N) {
                            continue;
                        }
                        const auto value =
                            nodes_[static_cast<std::size_t>(value_pos)].input_byte;
                        float candidate_weight = 1.0f;
                        if (effective_agg == "weighted-vote") {
                            if (params_.route_candidate_score == "recency") {
                                candidate_weight = static_cast<float>(
                                    vote_positions.size() - rank_index);
                            } else if (params_.route_candidate_score == "value-vote") {
                                candidate_weight = static_cast<float>(
                                    subset_value_counts[static_cast<std::size_t>(value)]);
                            }
                            candidate_weight *= route_credit_weight_for_candidate(i, value_pos);
                            candidate_weight *=
                                route_source_credit_weight_for_candidate(i, value_pos);
                        }
                        subset_value_votes[static_cast<std::size_t>(value)] +=
                            candidate_weight;
                        subset_vote_weight_sum += candidate_weight;
                    }
                }
                double correct_vote_share = 0.0;
                double unique_values = 0.0;
                double vote_entropy = 0.0;
                if (subset_vote_weight_sum > 0.0f) {
                    correct_vote_share = static_cast<double>(
                        subset_value_votes[static_cast<std::size_t>(node.target_byte)] /
                        subset_vote_weight_sum);
                    for (const float value_vote : subset_value_votes) {
                        if (value_vote <= 0.0f) {
                            continue;
                        }
                        unique_values += 1.0;
                        const double p =
                            static_cast<double>(value_vote / subset_vote_weight_sum);
                        vote_entropy -= p * (std::log(p) / std::log(2.0));
                    }
                }
                const double hi_hit =
                    node.state[0] == target_high ? 1.0 : 0.0;
                const double lo_hit =
                    node.state[1] == target_low ? 1.0 : 0.0;
                route_gated_query_count += 1.0;
                if (effective_agg == "vote") {
                    route_agg_policy_vote_count += 1.0;
                } else if (effective_agg == "weighted-vote") {
                    route_agg_policy_weighted_count += 1.0;
                }
                if (high_confidence) {
                    route_highconf_query_count += 1.0;
                    route_highconf_effective_strength_sum += route_strength;
                    route_highconf_qacc_sum += query_hit;
                    route_highconf_candidate_recall_sum += candidate_recall;
                    route_highconf_top1_sum += candidate_top1;
                    route_highconf_correct_value_vote_share_sum += correct_vote_share;
                    route_highconf_unique_values_sum += unique_values;
                    route_highconf_vote_entropy_sum += vote_entropy;
                    route_highconf_route_margin_sum += route_margin;
                    route_highconf_local_margin_sum += local_margin;
                    route_highconf_hi_acc_sum += hi_hit;
                    route_highconf_lo_acc_sum += lo_hit;
                    if (!candidate_is_correct && has_correct_candidate) {
                        route_highconf_wrong_strength_sum += route_strength;
                        route_highconf_wrong_strength_count += 1.0;
                    }
                } else {
                    route_lowconf_query_count += 1.0;
                    route_lowconf_effective_strength_sum += route_strength;
                    if (params_.route_lowconf_policy == "none") {
                        route_lowconf_policy_none_count += 1.0;
                    } else if (params_.route_lowconf_policy == "weak-vote") {
                        route_lowconf_policy_weak_vote_count += 1.0;
                    } else {
                        route_lowconf_policy_aggregate_count += 1.0;
                    }
                    route_lowconf_qacc_sum += query_hit;
                    route_lowconf_candidate_recall_sum += candidate_recall;
                    route_lowconf_top1_sum += candidate_top1;
                    route_lowconf_correct_value_vote_share_sum += correct_vote_share;
                    route_lowconf_unique_values_sum += unique_values;
                    route_lowconf_vote_entropy_sum += vote_entropy;
                    route_lowconf_route_margin_sum += route_margin;
                    route_lowconf_local_margin_sum += local_margin;
                    route_lowconf_hi_acc_sum += hi_hit;
                    route_lowconf_lo_acc_sum += lo_hit;
                    if (!candidate_is_correct && has_correct_candidate) {
                        route_lowconf_wrong_strength_sum += route_strength;
                        route_lowconf_wrong_strength_count += 1.0;
                    }
                }
            }
            query_route_hint_margin_sum += route_margin;
            query_local_margin_against_route_sum += local_margin;
            query_effective_route_margin_sum +=
                route_strength * static_cast<double>(route_hint_weight) * route_margin -
                local_margin;
            route_strength_sum += route_strength;
            route_strength_max = std::max(route_strength_max, route_strength);
            route_strength_values.push_back(route_strength);
            route_hint_value_match_sum +=
                relaxed_byte == static_cast<int>(route_hint_value) ? 1.0 : 0.0;
            fixture_query_byte_hits +=
                relaxed_byte == static_cast<int>(node.target_byte) ? 1.0 : 0.0;
            fixture_query_field_hits +=
                field_byte == static_cast<int>(node.target_byte) ? 1.0 : 0.0;
            fixture_query_joint_hits += joint_byte == node.target_byte ? 1.0 : 0.0;
            if (route_hint_active() &&
                (!(route_hint_parsed_active() || route_hint_kv_exact_active() ||
                   route_hint_kv_hash_active()) ||
                 (route_hint_value_pos >= 0 && route_hint_value_pos < params_.N))) {
                route_hint_applied_count += 1.0;
                route_hint_applied_weight_sum += static_cast<double>(route_hint_weight);
            }
        }

        if (routing_enabled()) {
            const auto route_key = route_keys_[static_cast<std::size_t>(i)];
            const auto relaxed_state_byte = static_cast<std::uint8_t>(relaxed_byte);
            route_diagnostic_count += 1.0;
            route_key_anchor_match_sum += route_key == anchor_byte ? 1.0 : 0.0;
            route_state_anchor_match_sum += relaxed_state_byte == anchor_byte ? 1.0 : 0.0;
            route_key_state_match_sum += route_key == relaxed_state_byte ? 1.0 : 0.0;
            route_key_anchor_hamming_sum +=
                static_cast<double>(byte_nibble_hamming(route_key, anchor_byte));

            const bool reservoir_reason =
                std::abs(node.reservoir) > params_.route_reservoir_threshold;
            const bool stagnation_reason =
                node.age_since_change >= params_.stagnation_window &&
                local_disagreement(i) >= params_.stagnation_threshold;
            const bool triggered = reservoir_reason || stagnation_reason;
            if (triggered) {
                const double anchor_gap = route_anchor_gap(i);
                const double route_gate = effective_route_min_anchor_gap(i);
                const double route_gate_margin = anchor_gap - route_gate;
                const double stress = route_stress(i);
                const double route_confidence = route_confidence_margin(node.input_byte);
                const int jump_candidates =
                    routing_.candidate_count(route_key, i);
                std::array<int, 8> effective_neighbors{};
                JumpNeighborDiagnostics jump_diagnostics;
                const int neighbor_count =
                    fill_effective_neighbors(i, effective_neighbors, &jump_diagnostics);
                const int active_jumps = jump_diagnostics.selected_jumps;
                const bool jump_filter_gate_passed = jump_neighbors_active() && anchor_gap > route_gate;
                routing_trigger_sum += 1.0;
                route_gap_pass_sum += anchor_gap > route_gate ? 1.0 : 0.0;
                triggered_route_anchor_gap_sum += anchor_gap;
                triggered_anchor_gaps.push_back(anchor_gap);
                triggered_anchor_gap_gt_0_sum += anchor_gap > 0.0 ? 1.0 : 0.0;
                triggered_anchor_gap_gt_1e_6_sum += anchor_gap > 1.0e-6 ? 1.0 : 0.0;
                triggered_anchor_gap_gt_1e_4_sum += anchor_gap > 1.0e-4 ? 1.0 : 0.0;
                triggered_anchor_gap_gt_1e_3_sum += anchor_gap > 1.0e-3 ? 1.0 : 0.0;
                triggered_anchor_gap_gt_1e_2_sum += anchor_gap > 1.0e-2 ? 1.0 : 0.0;
                triggered_anchor_gap_gt_1e_1_sum += anchor_gap > 1.0e-1 ? 1.0 : 0.0;
                if (anchor_gap > 0.0) {
                    positive_triggered_anchor_gap_sum += anchor_gap;
                    positive_triggered_anchor_gap_count += 1.0;
                }
                max_triggered_route_anchor_gap =
                    std::max(max_triggered_route_anchor_gap, anchor_gap);
                triggered_gate_margins.push_back(route_gate_margin);
                triggered_route_gate_margin_sum += route_gate_margin;
                max_triggered_route_gate_margin =
                    routing_trigger_sum == 1.0
                        ? route_gate_margin
                        : std::max(max_triggered_route_gate_margin, route_gate_margin);
                triggered_gap_equal_gate_sum +=
                    std::abs(route_gate_margin) <= 1.0e-9 ? 1.0 : 0.0;
                triggered_gap_below_gate_sum += anchor_gap < route_gate - 1.0e-9 ? 1.0 : 0.0;
                triggered_route_gate_sum += route_gate;
                triggered_route_stress_sum += stress;
                triggered_route_confidence_sum += route_confidence;
                max_triggered_route_confidence =
                    std::max(max_triggered_route_confidence, route_confidence);
                jump_candidate_sum += static_cast<double>(jump_candidates);
                routing_hit_sum += jump_candidates > 0 ? 1.0 : 0.0;
                active_jump_sum += static_cast<double>(active_jumps);
                active_jump_node_sum += active_jumps > 0 ? 1.0 : 0.0;
                triggered_route_key_anchor_match_sum += route_key == anchor_byte ? 1.0 : 0.0;
                triggered_route_state_anchor_match_sum +=
                    relaxed_state_byte == anchor_byte ? 1.0 : 0.0;
                triggered_route_key_state_match_sum +=
                    route_key == relaxed_state_byte ? 1.0 : 0.0;
                triggered_route_key_anchor_hamming_sum +=
                    static_cast<double>(byte_nibble_hamming(route_key, anchor_byte));
                triggered_route_state_anchor_hamming_sum +=
                    static_cast<double>(byte_nibble_hamming(relaxed_state_byte, anchor_byte));
                if (anchor_gap <= 1.0e-9) {
                    triggered_zero_gap_count += 1.0;
                    triggered_zero_gap_state_anchor_mismatch_sum +=
                        relaxed_state_byte != anchor_byte ? 1.0 : 0.0;
                }
                triggered_reservoir_reason_sum += reservoir_reason ? 1.0 : 0.0;
                triggered_stagnation_reason_sum += stagnation_reason ? 1.0 : 0.0;
                triggered_both_reasons_sum +=
                    reservoir_reason && stagnation_reason ? 1.0 : 0.0;
                if (anchor_gap > route_gate) {
                    gate_pass_active_jump_sum += active_jumps > 0 ? 1.0 : 0.0;
                }
                if (jump_filter_gate_passed) {
                    jump_filter_node_count += 1.0;
                    jump_candidate_slots_examined_sum +=
                        static_cast<double>(jump_diagnostics.candidate_slots_examined);
                    jump_self_reject_sum += static_cast<double>(jump_diagnostics.self_rejects);
                    jump_local_duplicate_reject_sum +=
                        static_cast<double>(jump_diagnostics.local_duplicate_rejects);
                    jump_color_reject_sum += static_cast<double>(jump_diagnostics.color_rejects);
                    jump_anchor_gap_reject_sum +=
                        static_cast<double>(jump_diagnostics.anchor_gap_rejects);
                    jump_confidence_gain_reject_sum +=
                        static_cast<double>(jump_diagnostics.confidence_gain_rejects);
                    jump_local_score_reject_sum +=
                        static_cast<double>(jump_diagnostics.local_score_rejects);
                    selected_jump_sum += static_cast<double>(jump_diagnostics.selected_jumps);
                    jump_underfilled_sum += jump_diagnostics.underfilled ? 1.0 : 0.0;
                }

                if (active_jumps > 0) {
                    const int local_keep = params_.K - active_jumps;
                    for (int n = local_keep; n < neighbor_count; ++n) {
                        jump_distance_sum += static_cast<double>(ring_distance(
                            i, effective_neighbors[static_cast<std::size_t>(n)]));
                        jump_distance_count += 1.0;
                    }
                }
            }
        }
    }

    EpochMetricsV02 metrics;
    metrics.epoch = epoch;
    metrics.H = total_energy();
    metrics.byte_acc = byte_hits / static_cast<double>(params_.N);
    metrics.field_byte_acc = field_byte_hits / static_cast<double>(params_.N);
    metrics.oracle1_acc = oracle_hits / static_cast<double>(params_.N);
    metrics.ch0_acc = ch0_hits / static_cast<double>(params_.N);
    metrics.ch1_acc = ch1_hits / static_cast<double>(params_.N);
    metrics.field_ch0_acc = field_ch0_hits / static_cast<double>(params_.N);
    metrics.field_ch1_acc = field_ch1_hits / static_cast<double>(params_.N);
    metrics.field_margin = margin_sum / static_cast<double>(params_.channels * params_.N);
    metrics.joint_byte_acc = joint_byte_hits / static_cast<double>(params_.N);
    metrics.pair_margin = pair_margin_sum / static_cast<double>(params_.N);
    metrics.mean_disagreement = disagreement_sum / static_cast<double>(params_.N);
    metrics.mean_tick = tick_sum / static_cast<double>(params_.N);
    metrics.mean_abs_reservoir = abs_reservoir_sum / static_cast<double>(params_.N);
    metrics.changed = changed;
    metrics.downhill_accepts = downhill;
    metrics.uphill_accepts = uphill;
    metrics.rejected = rejected;
    metrics.skipped = skipped;
    if (routing_trigger_sum > 0.0) {
        metrics.mean_jump_candidates = jump_candidate_sum / routing_trigger_sum;
        metrics.routing_hit_rate = routing_hit_sum / routing_trigger_sum;
        metrics.route_gap_pass_rate = route_gap_pass_sum / routing_trigger_sum;
        metrics.mean_triggered_route_anchor_gap =
            triggered_route_anchor_gap_sum / routing_trigger_sum;
        metrics.max_triggered_route_anchor_gap = max_triggered_route_anchor_gap;
        metrics.mean_triggered_route_gate = triggered_route_gate_sum / routing_trigger_sum;
        metrics.mean_triggered_route_stress = triggered_route_stress_sum / routing_trigger_sum;
        metrics.mean_triggered_route_confidence =
            triggered_route_confidence_sum / routing_trigger_sum;
        metrics.max_triggered_route_confidence = max_triggered_route_confidence;
        metrics.triggered_route_key_anchor_match_rate =
            triggered_route_key_anchor_match_sum / routing_trigger_sum;
        metrics.triggered_route_state_anchor_match_rate =
            triggered_route_state_anchor_match_sum / routing_trigger_sum;
        metrics.triggered_route_key_state_match_rate =
            triggered_route_key_state_match_sum / routing_trigger_sum;
        metrics.mean_triggered_route_key_anchor_hamming =
            triggered_route_key_anchor_hamming_sum / routing_trigger_sum;
        metrics.triggered_route_anchor_gap_gt_0_rate =
            triggered_anchor_gap_gt_0_sum / routing_trigger_sum;
        metrics.triggered_route_anchor_gap_gt_1e_6_rate =
            triggered_anchor_gap_gt_1e_6_sum / routing_trigger_sum;
        metrics.triggered_route_anchor_gap_gt_1e_4_rate =
            triggered_anchor_gap_gt_1e_4_sum / routing_trigger_sum;
        metrics.triggered_route_anchor_gap_gt_1e_3_rate =
            triggered_anchor_gap_gt_1e_3_sum / routing_trigger_sum;
        metrics.triggered_route_anchor_gap_gt_1e_2_rate =
            triggered_anchor_gap_gt_1e_2_sum / routing_trigger_sum;
        metrics.triggered_route_anchor_gap_gt_1e_1_rate =
            triggered_anchor_gap_gt_1e_1_sum / routing_trigger_sum;
        metrics.p50_triggered_route_anchor_gap =
            nearest_rank_quantile(triggered_anchor_gaps, 0.50);
        metrics.p90_triggered_route_anchor_gap =
            nearest_rank_quantile(triggered_anchor_gaps, 0.90);
        metrics.p99_triggered_route_anchor_gap =
            nearest_rank_quantile(triggered_anchor_gaps, 0.99);
        metrics.mean_triggered_route_gate_margin =
            triggered_route_gate_margin_sum / routing_trigger_sum;
        metrics.p90_triggered_route_gate_margin =
            nearest_rank_quantile(triggered_gate_margins, 0.90);
        metrics.max_triggered_route_gate_margin = max_triggered_route_gate_margin;
        metrics.triggered_route_gap_equal_gate_rate =
            triggered_gap_equal_gate_sum / routing_trigger_sum;
        metrics.triggered_route_gap_below_gate_rate =
            triggered_gap_below_gate_sum / routing_trigger_sum;
        metrics.mean_triggered_route_state_anchor_hamming =
            triggered_route_state_anchor_hamming_sum / routing_trigger_sum;
        metrics.triggered_route_reservoir_reason_rate =
            triggered_reservoir_reason_sum / routing_trigger_sum;
        metrics.triggered_route_stagnation_reason_rate =
            triggered_stagnation_reason_sum / routing_trigger_sum;
        metrics.triggered_route_both_reasons_rate =
            triggered_both_reasons_sum / routing_trigger_sum;
    }
    if (triggered_zero_gap_count > 0.0) {
        metrics.triggered_route_zero_gap_state_anchor_mismatch_rate =
            triggered_zero_gap_state_anchor_mismatch_sum / triggered_zero_gap_count;
    }
    if (route_hint_query_count > 0.0) {
        metrics.route_hint_applied_rate = route_hint_applied_count / route_hint_query_count;
        metrics.route_hint_candidate_hit_rate =
            route_hint_candidate_lookup_count / route_hint_query_count;
        metrics.route_hint_value_match_rate =
            route_hint_value_match_sum / route_hint_query_count;
        metrics.fixture_query_byte_acc = fixture_query_byte_hits / route_hint_query_count;
        metrics.fixture_query_acc = metrics.fixture_query_byte_acc;
        metrics.fixture_query_hi_acc = fixture_query_hi_hits / route_hint_query_count;
        metrics.fixture_query_lo_acc = fixture_query_lo_hits / route_hint_query_count;
        metrics.fixture_query_field_acc = fixture_query_field_hits / route_hint_query_count;
        metrics.fixture_query_joint_acc = fixture_query_joint_hits / route_hint_query_count;
        metrics.query_route_hint_margin_mean =
            query_route_hint_margin_sum / route_hint_query_count;
        metrics.query_local_margin_against_route_mean =
            query_local_margin_against_route_sum / route_hint_query_count;
        metrics.query_effective_route_margin_mean =
            query_effective_route_margin_sum / route_hint_query_count;
        metrics.route_strength_mean = route_strength_sum / route_hint_query_count;
        metrics.route_strength_p50 = nearest_rank_quantile(route_strength_values, 0.50);
        metrics.route_strength_p90 = nearest_rank_quantile(route_strength_values, 0.90);
        metrics.route_strength_max = route_strength_max;
        metrics.route_candidate_corrupt_rate =
            route_candidate_corrupt_count / route_hint_query_count;
        metrics.route_correct_candidate_rate =
            route_correct_candidate_count / route_hint_query_count;
        metrics.route_wrong_hint_applied_rate =
            route_wrong_hint_count / route_hint_query_count;
        metrics.route_primary_recall = route_primary_recall_sum / route_hint_query_count;
        metrics.route_primary_lowconf_rate =
            route_primary_lowconf_count / route_hint_query_count;
        metrics.route_fallback_used_rate =
            route_fallback_used_count / route_hint_query_count;
        metrics.route_noisy_source_used_rate =
            route_noisy_source_used_count / route_hint_query_count;
        metrics.route_noisy_source_selected_rate =
            route_noisy_source_selected_count / route_hint_query_count;
        metrics.route_abstain_rate = route_abstain_count / route_hint_query_count;
        if (route_source_filter_candidate_count > 0.0) {
            metrics.route_source_filter_filtered_rate =
                route_source_filter_filtered_count / route_source_filter_candidate_count;
        }
        if (route_source_filter_query_count > 0.0) {
            metrics.route_source_filter_abstain_rate =
                route_source_filter_abstain_count / route_source_filter_query_count;
        }
        metrics.route_source_retry_used_rate =
            route_source_retry_used_count / route_hint_query_count;
        metrics.route_source_retry_success_rate =
            route_source_retry_success_count / route_hint_query_count;
        metrics.route_source_retry_raw_selected_rate =
            route_source_retry_raw_selected_count / route_hint_query_count;
        metrics.route_source_retry_keyshape_selected_rate =
            route_source_retry_keyshape_selected_count / route_hint_query_count;
        metrics.route_source_retry_noisy_selected_rate =
            route_source_retry_noisy_selected_count / route_hint_query_count;
        if (route_fallback_used_count > 0.0) {
            metrics.route_fallback_recall =
                route_fallback_recall_sum / route_fallback_used_count;
            metrics.route_fallback_qacc =
                route_fallback_qacc_sum / route_fallback_used_count;
            metrics.route_fallback_success_rate =
                route_fallback_success_count / route_fallback_used_count;
            metrics.route_fallback_hi_acc =
                route_fallback_hi_acc_sum / route_fallback_used_count;
            metrics.route_fallback_lo_acc =
                route_fallback_lo_acc_sum / route_fallback_used_count;
            metrics.route_fallback_route_margin_mean =
                route_fallback_route_margin_sum / route_fallback_used_count;
            metrics.route_fallback_effective_strength_mean =
                route_fallback_effective_strength_sum / route_fallback_used_count;
            metrics.route_fallback_hi_effective_strength_mean =
                route_fallback_hi_effective_strength_sum / route_fallback_used_count;
            metrics.route_fallback_lo_effective_strength_mean =
                route_fallback_lo_effective_strength_sum / route_fallback_used_count;
            metrics.route_fallback_strength_p50 =
                nearest_rank_quantile(route_fallback_strength_values, 0.50);
            metrics.route_fallback_strength_p90 =
                nearest_rank_quantile(route_fallback_strength_values, 0.90);
            metrics.route_fallback_strength_max = route_fallback_strength_max;
            metrics.route_fallback_local_margin_against_route_mean =
                route_fallback_local_margin_sum / route_fallback_used_count;
            metrics.route_fallback_hi_local_margin_against_route_mean =
                route_fallback_hi_local_margin_sum / route_fallback_used_count;
            metrics.route_fallback_lo_local_margin_against_route_mean =
                route_fallback_lo_local_margin_sum / route_fallback_used_count;
            metrics.route_fallback_persist_used_rate =
                route_fallback_persist_used_sum / route_fallback_used_count;
            metrics.route_fallback_persist_cycles_mean =
                route_fallback_persist_cycles_sum / route_fallback_used_count;
        }
        if (route_credit_correct_count > 0.0) {
            metrics.route_credit_correct_mean =
                route_credit_correct_sum / route_credit_correct_count;
        }
        if (route_credit_wrong_count > 0.0) {
            metrics.route_credit_wrong_mean =
                route_credit_wrong_sum / route_credit_wrong_count;
        }
        metrics.route_credit_gap =
            metrics.route_credit_correct_mean - metrics.route_credit_wrong_mean;
        if (route_credit_candidate_count > 0.0) {
            metrics.route_credit_rewarded_rate =
                route_credit_rewarded_count / route_credit_candidate_count;
            metrics.route_credit_slashed_rate =
                route_credit_slashed_count / route_credit_candidate_count;
        }
        if (route_credit_query_count > 0.0) {
            metrics.route_credit_top1_rate =
                route_credit_top1_sum / route_credit_query_count;
            metrics.route_credit_qacc =
                route_credit_qacc_sum / route_credit_query_count;
        }
        metrics.route_credit_learn_active = route_credit_learn_active() ? 1.0 : 0.0;
        metrics.route_credit_apply_active = route_credit_apply_active() ? 1.0 : 0.0;
        for (const auto& entry : route_source_credit_by_bucket_) {
            const bool is_primary =
                entry.first.find("|source:primary-") != std::string::npos;
            const bool is_fallback =
                entry.first.find("|source:fallback-") != std::string::npos;
            const bool is_noisy =
                entry.first.find("|source:noisy-route-code") != std::string::npos;
            const bool is_retry_raw =
                entry.first.find("|source:retry-raw-key") != std::string::npos;
            const bool is_retry_keyshape =
                entry.first.find("|source:retry-key-shape") != std::string::npos;
            const bool is_retry_noisy =
                entry.first.find("|source:retry-noisy-route-code") != std::string::npos;
            if (is_primary) {
                route_source_credit_primary_sum += static_cast<double>(entry.second);
                route_source_credit_primary_count += 1.0;
                route_source_credit_primary_candidate_count += 1.0;
                if (entry.second < 0.0f) {
                    route_source_credit_primary_slashed_count += 1.0;
                }
            } else if (is_fallback) {
                route_source_credit_fallback_sum += static_cast<double>(entry.second);
                route_source_credit_fallback_count += 1.0;
                route_source_credit_fallback_candidate_count += 1.0;
                if (entry.second > 0.0f) {
                    route_source_credit_fallback_rewarded_count += 1.0;
                }
            } else if (is_noisy) {
                route_source_credit_noisy_sum += static_cast<double>(entry.second);
                route_source_credit_noisy_count += 1.0;
                route_source_credit_noisy_candidate_count += 1.0;
                if (entry.second < 0.0f) {
                    route_source_credit_noisy_slashed_count += 1.0;
                }
            }
            if (is_retry_raw) {
                route_source_retry_raw_sum += static_cast<double>(entry.second);
                route_source_retry_raw_count += 1.0;
                if (entry.second > 0.0f) {
                    route_source_retry_raw_rewarded_count += 1.0;
                }
            } else if (is_retry_keyshape) {
                route_source_retry_keyshape_sum += static_cast<double>(entry.second);
                route_source_retry_keyshape_count += 1.0;
                if (entry.second > 0.0f) {
                    route_source_retry_keyshape_rewarded_count += 1.0;
                }
            } else if (is_retry_noisy) {
                route_source_retry_noisy_sum += static_cast<double>(entry.second);
                route_source_retry_noisy_count += 1.0;
                if (entry.second < 0.0f) {
                    route_source_retry_noisy_slashed_count += 1.0;
                }
            }
        }
        metrics.route_source_credit_size =
            static_cast<double>(route_source_credit_by_bucket_.size());
        metrics.route_source_credit_apply_active =
            route_source_credit_apply_active() ? 1.0 : 0.0;
        if (route_source_credit_ranking_query_count > 0.0) {
            metrics.route_source_credit_override_rate =
                route_source_credit_override_count /
                route_source_credit_ranking_query_count;
            metrics.route_source_credit_selected_fallback_rate =
                route_source_credit_selected_fallback_count /
                route_source_credit_ranking_query_count;
        }
        if (route_source_credit_strength_count > 0.0) {
            metrics.route_source_credit_strength_mean =
                route_source_credit_strength_sum / route_source_credit_strength_count;
        }
        if (route_source_credit_primary_count > 0.0) {
            metrics.route_source_credit_primary_mean =
                route_source_credit_primary_sum / route_source_credit_primary_count;
        }
        if (route_source_credit_fallback_count > 0.0) {
            metrics.route_source_credit_fallback_mean =
                route_source_credit_fallback_sum / route_source_credit_fallback_count;
        }
        if (route_source_credit_noisy_count > 0.0) {
            metrics.route_source_credit_noisy_mean =
                route_source_credit_noisy_sum / route_source_credit_noisy_count;
        }
        metrics.route_source_credit_gap =
            metrics.route_source_credit_fallback_mean -
            metrics.route_source_credit_primary_mean;
        if (route_source_credit_primary_candidate_count > 0.0) {
            metrics.route_source_credit_primary_slashed_rate =
                route_source_credit_primary_slashed_count /
                route_source_credit_primary_candidate_count;
        }
        if (route_source_credit_fallback_candidate_count > 0.0) {
            metrics.route_source_credit_fallback_rewarded_rate =
                route_source_credit_fallback_rewarded_count /
                route_source_credit_fallback_candidate_count;
        }
        if (route_source_credit_noisy_candidate_count > 0.0) {
            metrics.route_source_credit_noisy_slashed_rate =
                route_source_credit_noisy_slashed_count /
                route_source_credit_noisy_candidate_count;
        }
        if (route_source_retry_raw_count > 0.0) {
            metrics.route_source_retry_raw_mean =
                route_source_retry_raw_sum / route_source_retry_raw_count;
            metrics.route_source_retry_raw_rewarded_rate =
                route_source_retry_raw_rewarded_count / route_source_retry_raw_count;
        }
        if (route_source_retry_keyshape_count > 0.0) {
            metrics.route_source_retry_keyshape_mean =
                route_source_retry_keyshape_sum / route_source_retry_keyshape_count;
            metrics.route_source_retry_keyshape_rewarded_rate =
                route_source_retry_keyshape_rewarded_count /
                route_source_retry_keyshape_count;
        }
        if (route_source_retry_noisy_count > 0.0) {
            metrics.route_source_retry_noisy_mean =
                route_source_retry_noisy_sum / route_source_retry_noisy_count;
            metrics.route_source_retry_noisy_slashed_rate =
                route_source_retry_noisy_slashed_count / route_source_retry_noisy_count;
        }
        if (params_.route_plasticity_ledger != 0) {
            metrics.route_plasticity_ledger_size =
                static_cast<double>(route_plasticity_ledger_.size());
            double ledger_abs_sum = 0.0;
            for (const auto& entry : route_plasticity_ledger_) {
                ledger_abs_sum += static_cast<double>(std::abs(entry.second));
            }
            if (!route_plasticity_ledger_.empty()) {
                metrics.route_plasticity_ledger_mean_abs_credit =
                    ledger_abs_sum /
                    static_cast<double>(route_plasticity_ledger_.size());
            }
        }
        if (route_wrong_hint_count > 0.0) {
            metrics.route_wrong_hint_strength_mean =
                route_wrong_hint_strength_sum / route_wrong_hint_count;
            metrics.route_candidate_conf_wrong_mean =
                route_candidate_conf_wrong_sum / route_wrong_hint_count;
        }
        if (route_correct_candidate_count > 0.0) {
            metrics.route_correct_hint_strength_mean =
                route_correct_hint_strength_sum / route_correct_candidate_count;
            metrics.route_candidate_conf_correct_mean =
                route_candidate_conf_correct_sum / route_correct_candidate_count;
        }
        if (route_value_conf_correct_count > 0.0) {
            metrics.route_value_conf_correct_mean =
                route_value_conf_correct_sum / route_value_conf_correct_count;
        }
        if (route_value_conf_wrong_count > 0.0) {
            metrics.route_value_conf_wrong_mean =
                route_value_conf_wrong_sum / route_value_conf_wrong_count;
        }
        if (route_agreement_conf_correct_count > 0.0) {
            metrics.route_agreement_conf_correct_mean =
                route_agreement_conf_correct_sum / route_agreement_conf_correct_count;
        }
        if (route_agreement_conf_wrong_count > 0.0) {
            metrics.route_agreement_conf_wrong_mean =
                route_agreement_conf_wrong_sum / route_agreement_conf_wrong_count;
        }
        metrics.route_candidate_conf_gap =
            metrics.route_candidate_conf_correct_mean -
            metrics.route_candidate_conf_wrong_mean;
        metrics.route_value_top_correct_rate =
            route_value_top_correct_sum / route_hint_query_count;
        metrics.route_value_conf_gap =
            metrics.route_value_conf_correct_mean -
            metrics.route_value_conf_wrong_mean;
        metrics.route_agreement_conf_gap =
            metrics.route_agreement_conf_correct_mean -
            metrics.route_agreement_conf_wrong_mean;
        metrics.route_agreement_top_correct_rate =
            route_agreement_top_correct_sum / route_hint_query_count;
        if (route_gated_query_count > 0.0) {
            metrics.route_lowconf_query_rate =
                route_lowconf_query_count / route_gated_query_count;
            metrics.route_highconf_query_rate =
                route_highconf_query_count / route_gated_query_count;
            metrics.route_agg_policy_vote_rate =
                route_agg_policy_vote_count / route_gated_query_count;
            metrics.route_agg_policy_weighted_rate =
                route_agg_policy_weighted_count / route_gated_query_count;
            metrics.route_lowconf_policy_none_rate =
                route_lowconf_policy_none_count / route_gated_query_count;
            metrics.route_lowconf_policy_weak_vote_rate =
                route_lowconf_policy_weak_vote_count / route_gated_query_count;
            metrics.route_lowconf_policy_aggregate_rate =
                route_lowconf_policy_aggregate_count / route_gated_query_count;
        }
        if (route_lowconf_query_count > 0.0) {
            metrics.route_lowconf_effective_strength_mean =
                route_lowconf_effective_strength_sum / route_lowconf_query_count;
            metrics.route_lowconf_qacc =
                route_lowconf_qacc_sum / route_lowconf_query_count;
            metrics.route_lowconf_candidate_recall =
                route_lowconf_candidate_recall_sum / route_lowconf_query_count;
            metrics.route_lowconf_top1 =
                route_lowconf_top1_sum / route_lowconf_query_count;
            metrics.route_lowconf_correct_value_vote_share =
                route_lowconf_correct_value_vote_share_sum / route_lowconf_query_count;
            metrics.route_lowconf_unique_values =
                route_lowconf_unique_values_sum / route_lowconf_query_count;
            metrics.route_lowconf_vote_entropy =
                route_lowconf_vote_entropy_sum / route_lowconf_query_count;
            metrics.route_lowconf_route_margin =
                route_lowconf_route_margin_sum / route_lowconf_query_count;
            metrics.route_lowconf_local_margin =
                route_lowconf_local_margin_sum / route_lowconf_query_count;
            metrics.route_lowconf_hi_acc =
                route_lowconf_hi_acc_sum / route_lowconf_query_count;
            metrics.route_lowconf_lo_acc =
                route_lowconf_lo_acc_sum / route_lowconf_query_count;
        }
        if (route_highconf_query_count > 0.0) {
            metrics.route_highconf_effective_strength_mean =
                route_highconf_effective_strength_sum / route_highconf_query_count;
            metrics.route_highconf_qacc =
                route_highconf_qacc_sum / route_highconf_query_count;
            metrics.route_highconf_candidate_recall =
                route_highconf_candidate_recall_sum / route_highconf_query_count;
            metrics.route_highconf_top1 =
                route_highconf_top1_sum / route_highconf_query_count;
            metrics.route_highconf_correct_value_vote_share =
                route_highconf_correct_value_vote_share_sum / route_highconf_query_count;
            metrics.route_highconf_unique_values =
                route_highconf_unique_values_sum / route_highconf_query_count;
            metrics.route_highconf_vote_entropy =
                route_highconf_vote_entropy_sum / route_highconf_query_count;
            metrics.route_highconf_route_margin =
                route_highconf_route_margin_sum / route_highconf_query_count;
            metrics.route_highconf_local_margin =
                route_highconf_local_margin_sum / route_highconf_query_count;
            metrics.route_highconf_hi_acc =
                route_highconf_hi_acc_sum / route_highconf_query_count;
            metrics.route_highconf_lo_acc =
                route_highconf_lo_acc_sum / route_highconf_query_count;
        }
        if (route_lowconf_wrong_strength_count > 0.0) {
            metrics.route_lowconf_wrong_strength_mean =
                route_lowconf_wrong_strength_sum / route_lowconf_wrong_strength_count;
        }
        if (route_highconf_wrong_strength_count > 0.0) {
            metrics.route_highconf_wrong_strength_mean =
                route_highconf_wrong_strength_sum / route_highconf_wrong_strength_count;
        }
    }
    if (route_hint_applied_count > 0.0) {
        metrics.route_hint_weight_mean =
            route_hint_applied_weight_sum / route_hint_applied_count;
        metrics.route_hint_strength_mean = metrics.route_hint_weight_mean;
    }
    metrics.route_hint_query_count = route_hint_query_count;
    metrics.route_hint_candidate_lookup_count = route_hint_candidate_lookup_count;
    if (route_hint_candidate_lookup_count > 0.0) {
        metrics.route_hint_value_read_distance_mean =
            route_hint_value_read_distance_sum / route_hint_candidate_lookup_count;
    }
    if (route_hint_vote_query_count > 0.0) {
        metrics.route_hint_vote_candidate_count_mean =
            route_hint_vote_candidate_count_sum / route_hint_vote_query_count;
        metrics.route_hint_vote_margin_mean =
            route_hint_vote_margin_sum / route_hint_vote_query_count;
        metrics.route_hint_correct_value_vote_share_mean =
            route_hint_correct_value_vote_share_sum / route_hint_vote_query_count;
        metrics.route_hint_vote_entropy_mean =
            route_hint_vote_entropy_sum / route_hint_vote_query_count;
        metrics.route_hint_unique_values_mean =
            route_hint_unique_values_sum / route_hint_vote_query_count;
    }
    if (route_quality_query_count > 0.0) {
        metrics.route_quality_logdet_mean =
            route_quality_logdet_sum / route_quality_query_count;
        metrics.route_quality_logdet_norm_mean =
            route_quality_logdet_norm_sum / route_quality_query_count;
        metrics.route_quality_condition_mean =
            route_quality_condition_sum / route_quality_query_count;
        metrics.route_quality_score_mean =
            route_quality_score_sum / route_quality_query_count;
    }
    metrics.route_quality_apply_active =
        (route_quality_source_ranking_apply_active(params_) ||
         route_quality_candidate_weight_apply_active(params_))
            ? 1.0
            : 0.0;
    metrics.route_quality_source_ranking_beta =
        static_cast<double>(params_.route_quality_source_ranking_beta);
    metrics.route_quality_source_normalization_active =
        params_.route_quality_source_normalization == "none" ? 0.0 : 1.0;
    if (route_quality_source_ranking_delta_count > 0.0) {
        metrics.route_quality_source_ranking_delta_mean =
            route_quality_source_ranking_delta_sum /
            route_quality_source_ranking_delta_count;
    }
    if (route_hint_query_count > 0.0 &&
        route_quality_source_ranking_apply_active(params_)) {
        metrics.route_quality_selected_raw_rate =
            route_source_retry_raw_selected_count / route_hint_query_count;
        metrics.route_quality_selected_keyshape_rate =
            route_source_retry_keyshape_selected_count / route_hint_query_count;
        metrics.route_quality_selected_noisy_rate =
            route_source_retry_noisy_selected_count / route_hint_query_count;
    }
    if (route_quality_retry_raw_proxy_count > 0.0) {
        metrics.route_quality_retry_raw_proxy_mean =
            route_quality_retry_raw_proxy_sum /
            route_quality_retry_raw_proxy_count;
    }
    if (route_quality_retry_keyshape_proxy_count > 0.0) {
        metrics.route_quality_retry_keyshape_proxy_mean =
            route_quality_retry_keyshape_proxy_sum /
            route_quality_retry_keyshape_proxy_count;
    }
    if (route_quality_retry_noisy_proxy_count > 0.0) {
        metrics.route_quality_retry_noisy_proxy_mean =
            route_quality_retry_noisy_proxy_sum /
            route_quality_retry_noisy_proxy_count;
    }
    if (route_quality_retry_raw_norm_proxy_count > 0.0) {
        metrics.route_quality_retry_raw_norm_proxy_mean =
            route_quality_retry_raw_norm_proxy_sum /
            route_quality_retry_raw_norm_proxy_count;
    }
    if (route_quality_retry_keyshape_norm_proxy_count > 0.0) {
        metrics.route_quality_retry_keyshape_norm_proxy_mean =
            route_quality_retry_keyshape_norm_proxy_sum /
            route_quality_retry_keyshape_norm_proxy_count;
    }
    if (route_quality_retry_noisy_norm_proxy_count > 0.0) {
        metrics.route_quality_retry_noisy_norm_proxy_mean =
            route_quality_retry_noisy_norm_proxy_sum /
            route_quality_retry_noisy_norm_proxy_count;
    }
    if (route_quality_retry_raw_delta_count > 0.0) {
        metrics.route_quality_retry_raw_delta_mean =
            route_quality_retry_raw_delta_sum /
            route_quality_retry_raw_delta_count;
    }
    if (route_quality_retry_keyshape_delta_count > 0.0) {
        metrics.route_quality_retry_keyshape_delta_mean =
            route_quality_retry_keyshape_delta_sum /
            route_quality_retry_keyshape_delta_count;
    }
    if (route_quality_retry_noisy_delta_count > 0.0) {
        metrics.route_quality_retry_noisy_delta_mean =
            route_quality_retry_noisy_delta_sum /
            route_quality_retry_noisy_delta_count;
    }
    if (route_quality_selected_raw_qacc_count > 0.0) {
        metrics.route_quality_selected_raw_qacc =
            route_quality_selected_raw_qacc_sum /
            route_quality_selected_raw_qacc_count;
    }
    if (route_quality_selected_keyshape_qacc_count > 0.0) {
        metrics.route_quality_selected_keyshape_qacc =
            route_quality_selected_keyshape_qacc_sum /
            route_quality_selected_keyshape_qacc_count;
    }
    if (route_quality_selected_noisy_qacc_count > 0.0) {
        metrics.route_quality_selected_noisy_qacc =
            route_quality_selected_noisy_qacc_sum /
            route_quality_selected_noisy_qacc_count;
    }
    if (route_quality_candidate_weight_correct_count > 0.0) {
        metrics.route_quality_candidate_weight_correct_mean =
            route_quality_candidate_weight_correct_sum /
            route_quality_candidate_weight_correct_count;
    }
    if (route_quality_candidate_weight_wrong_count > 0.0) {
        metrics.route_quality_candidate_weight_wrong_mean =
            route_quality_candidate_weight_wrong_sum /
            route_quality_candidate_weight_wrong_count;
    }
    metrics.route_quality_candidate_weight_gap =
        metrics.route_quality_candidate_weight_correct_mean -
        metrics.route_quality_candidate_weight_wrong_mean;
    if (route_quality_candidate_best_correct_count > 0.0) {
        metrics.route_quality_candidate_best_correct_rate =
            route_quality_candidate_best_correct_sum /
            route_quality_candidate_best_correct_count;
    }
    metrics.route_quality_candidate_weight_beta =
        route_quality_candidate_weight_apply_active(params_)
            ? params_.route_quality_candidate_weight_beta
            : 0.0;
    if (route_quality_candidate_factor_count > 0.0) {
        metrics.route_quality_candidate_weight_factor_mean =
            route_quality_candidate_factor_sum /
            route_quality_candidate_factor_count;
    }
    if (route_quality_candidate_factor_correct_count > 0.0) {
        metrics.route_quality_candidate_weight_factor_correct_mean =
            route_quality_candidate_factor_correct_sum /
            route_quality_candidate_factor_correct_count;
    }
    if (route_quality_candidate_factor_wrong_count > 0.0) {
        metrics.route_quality_candidate_weight_factor_wrong_mean =
            route_quality_candidate_factor_wrong_sum /
            route_quality_candidate_factor_wrong_count;
    }
    metrics.route_quality_candidate_weight_factor_gap =
        metrics.route_quality_candidate_weight_factor_correct_mean -
        metrics.route_quality_candidate_weight_factor_wrong_mean;
    if (!route_quality_candidate_factors.empty()) {
        std::sort(
            route_quality_candidate_factors.begin(),
            route_quality_candidate_factors.end());
        const std::size_t p90_index = static_cast<std::size_t>(
            std::ceil(0.90 * static_cast<double>(route_quality_candidate_factors.size())) -
            1.0);
        metrics.route_quality_candidate_weight_factor_p90 =
            route_quality_candidate_factors[std::min(
                p90_index, route_quality_candidate_factors.size() - 1)];
        metrics.route_quality_candidate_weight_factor_max =
            route_quality_candidate_factor_max;
    }
    if (route_quality_candidate_weight_concentration_count > 0.0) {
        metrics.route_quality_candidate_weight_entropy_mean =
            route_quality_candidate_weight_entropy_sum /
            route_quality_candidate_weight_concentration_count;
        metrics.route_quality_candidate_weight_top_share_mean =
            route_quality_candidate_weight_top_share_sum /
            route_quality_candidate_weight_concentration_count;
    }
    if (route_quality_score_correct_count > 0.0) {
        metrics.route_quality_score_correct_mean =
            route_quality_score_correct_sum / route_quality_score_correct_count;
    }
    if (route_quality_score_wrong_count > 0.0) {
        metrics.route_quality_score_wrong_mean =
            route_quality_score_wrong_sum / route_quality_score_wrong_count;
    }
    metrics.route_quality_score_gap =
        metrics.route_quality_score_correct_mean -
        metrics.route_quality_score_wrong_mean;
    if (route_channel_query_count > 0.0) {
        metrics.route_channel_tension_det_mean =
            route_channel_tension_det_sum / route_channel_query_count;
        metrics.route_channel_tension_trace_mean =
            route_channel_tension_trace_sum / route_channel_query_count;
        metrics.route_channel_tension_offdiag_mean =
            route_channel_tension_offdiag_sum / route_channel_query_count;
        metrics.route_channel_hi_margin_mean =
            route_channel_hi_margin_sum / route_channel_query_count;
        metrics.route_channel_lo_margin_mean =
            route_channel_lo_margin_sum / route_channel_query_count;
        metrics.route_channel_margin_imbalance_mean =
            route_channel_margin_imbalance_sum / route_channel_query_count;
    }
    metrics.kv_record_count = static_cast<double>(kv_record_count_);
    metrics.kv_query_count = static_cast<double>(kv_query_count_);
    if (kv_record_count_ > 0) {
        metrics.kv_duplicate_key_rate =
            static_cast<double>(kv_duplicate_key_count_) / static_cast<double>(kv_record_count_);
    }
    if (kv_query_count_ > 0) {
        metrics.kv_query_hit_rate =
            static_cast<double>(kv_query_hit_count_) / static_cast<double>(kv_query_count_);
        metrics.kv_missing_key_rate =
            static_cast<double>(kv_missing_key_count_) / static_cast<double>(kv_query_count_);
    }
    metrics.route_candidate_query_count =
        static_cast<double>(route_candidate_query_count_);
    if (route_candidate_query_count_ > 0) {
        metrics.route_candidate_recall_rate =
            static_cast<double>(route_candidate_hit_count_) /
            static_cast<double>(route_candidate_query_count_);
        metrics.route_candidate_top1_rate =
            static_cast<double>(route_candidate_top1_hit_count_) /
            static_cast<double>(route_candidate_query_count_);
        metrics.route_bucket_load_mean =
            static_cast<double>(route_bucket_load_sum_) /
            static_cast<double>(route_candidate_query_count_);
        metrics.route_bucket_load_max = static_cast<double>(route_bucket_load_max_);
        metrics.route_bucket_collision_rate =
            static_cast<double>(route_bucket_collision_count_) /
            static_cast<double>(route_candidate_query_count_);
    }
    if (route_candidate_hit_count_ > 0) {
        metrics.route_candidate_rank_mean =
            route_candidate_rank_sum_ / static_cast<double>(route_candidate_hit_count_);
    }
    metrics.key_region_count = static_cast<double>(key_region_count_);
    metrics.raw_key_unique_count = static_cast<double>(raw_key_unique_count_);
    metrics.joint_key_unique_count = static_cast<double>(joint_key_unique_count_);
    metrics.route_key_unique_count = static_cast<double>(route_key_unique_count_);
    if (key_region_count_ > 0) {
        metrics.key_region_joint_decode_acc =
            static_cast<double>(key_region_joint_decode_hit_count_) /
            static_cast<double>(key_region_count_);
        metrics.key_region_route_decode_acc =
            static_cast<double>(key_region_route_decode_hit_count_) /
            static_cast<double>(key_region_count_);
    }
    if (raw_key_unique_count_ > 0) {
        metrics.joint_signature_collision_rate =
            1.0 - static_cast<double>(joint_key_unique_count_) /
                      static_cast<double>(raw_key_unique_count_);
        metrics.route_signature_collision_rate =
            1.0 - static_cast<double>(route_key_unique_count_) /
                      static_cast<double>(raw_key_unique_count_);
    }
    if (joint_vs_raw_candidate_overlap_count_ > 0) {
        metrics.joint_vs_raw_candidate_overlap_rate =
            joint_vs_raw_candidate_overlap_sum_ /
            static_cast<double>(joint_vs_raw_candidate_overlap_count_);
    }
    if (route_vs_raw_candidate_overlap_count_ > 0) {
        metrics.route_vs_raw_candidate_overlap_rate =
            route_vs_raw_candidate_overlap_sum_ /
            static_cast<double>(route_vs_raw_candidate_overlap_count_);
    }
    if (positive_triggered_anchor_gap_count > 0.0) {
        metrics.mean_positive_triggered_anchor_gap =
            positive_triggered_anchor_gap_sum / positive_triggered_anchor_gap_count;
    }
    if (route_gap_pass_sum > 0.0) {
        metrics.active_jump_gate_pass_rate =
            gate_pass_active_jump_sum / route_gap_pass_sum;
    }
    if (jump_filter_node_count > 0.0) {
        metrics.mean_jump_filter_candidates =
            jump_candidate_slots_examined_sum / jump_filter_node_count;
        metrics.jump_filter_underfilled_rate =
            jump_underfilled_sum / jump_filter_node_count;
    }
    if (jump_candidate_slots_examined_sum > 0.0) {
        metrics.jump_filter_self_rate =
            jump_self_reject_sum / jump_candidate_slots_examined_sum;
        metrics.jump_filter_local_duplicate_rate =
            jump_local_duplicate_reject_sum / jump_candidate_slots_examined_sum;
        metrics.jump_filter_color_conflict_rate =
            jump_color_reject_sum / jump_candidate_slots_examined_sum;
        metrics.jump_filter_anchor_gap_rate =
            jump_anchor_gap_reject_sum / jump_candidate_slots_examined_sum;
        metrics.jump_filter_confidence_gain_rate =
            jump_confidence_gain_reject_sum / jump_candidate_slots_examined_sum;
        metrics.jump_filter_local_replacement_rate =
            jump_local_score_reject_sum / jump_candidate_slots_examined_sum;
        metrics.jump_filter_selected_rate =
            selected_jump_sum / jump_candidate_slots_examined_sum;
    }
    if (route_diagnostic_count > 0.0) {
        metrics.route_key_anchor_match_rate =
            route_key_anchor_match_sum / route_diagnostic_count;
        metrics.route_state_anchor_match_rate =
            route_state_anchor_match_sum / route_diagnostic_count;
        metrics.route_key_state_match_rate =
            route_key_state_match_sum / route_diagnostic_count;
        metrics.mean_route_key_anchor_hamming =
            route_key_anchor_hamming_sum / route_diagnostic_count;
    }
    if (active_jump_node_sum > 0.0) {
        metrics.mean_active_jump_neighbors = active_jump_sum / active_jump_node_sum;
    }
    metrics.routing_trigger_rate = routing_trigger_sum / static_cast<double>(params_.N);
    metrics.active_jump_rate = active_jump_node_sum / static_cast<double>(params_.N);
    if (jump_distance_count > 0.0) {
        metrics.mean_jump_distance = jump_distance_sum / jump_distance_count;
    }
    return metrics;
}

double GraphV02::pair_energy(
    std::uint8_t input_byte,
    std::uint8_t high_state,
    std::uint8_t low_state) const {
    return -static_cast<double>(params_.lambda_u) *
               static_cast<double>(field_.score(0, input_byte, high_state) +
                                   field_.score(1, input_byte, low_state)) -
           static_cast<double>(params_.lambda_b) *
               static_cast<double>(coupling_.score(input_byte, high_state, low_state));
}

double GraphV02::route_confidence_margin(std::uint8_t input_byte) const {
    return route_confidence_cache_[static_cast<std::size_t>(input_byte)];
}

double GraphV02::compute_route_confidence_margin(std::uint8_t input_byte) const {
    double best_energy = std::numeric_limits<double>::infinity();
    double second_best_energy = std::numeric_limits<double>::infinity();

    for (int high_state = 0; high_state < params_.S; ++high_state) {
        for (int low_state = 0; low_state < params_.S; ++low_state) {
            const double candidate_energy = pair_energy(
                input_byte,
                static_cast<std::uint8_t>(high_state),
                static_cast<std::uint8_t>(low_state));
            if (candidate_energy < best_energy) {
                second_best_energy = best_energy;
                best_energy = candidate_energy;
            } else if (candidate_energy < second_best_energy) {
                second_best_energy = candidate_energy;
            }
        }
    }

    if (!std::isfinite(second_best_energy)) {
        return 0.0;
    }
    return second_best_energy - best_energy;
}

std::uint8_t GraphV02::best_joint_byte(std::uint8_t input_byte) const {
    std::uint8_t best_byte = 0;
    double best_energy = pair_energy(input_byte, 0, 0);
    for (int high_state = 0; high_state < params_.S; ++high_state) {
        for (int low_state = 0; low_state < params_.S; ++low_state) {
            const auto candidate_byte =
                static_cast<std::uint8_t>(high_state * FieldTable::States + low_state);
            const double candidate_energy = pair_energy(
                input_byte,
                static_cast<std::uint8_t>(high_state),
                static_cast<std::uint8_t>(low_state));
            if (candidate_energy < best_energy) {
                best_energy = candidate_energy;
                best_byte = candidate_byte;
            }
        }
    }
    return best_byte;
}

double GraphV02::positive_pair_margin(
    std::uint8_t input_byte,
    std::uint8_t positive_high,
    std::uint8_t positive_low) const {
    const double positive_energy = pair_energy(input_byte, positive_high, positive_low);
    double best_other_energy = std::numeric_limits<double>::infinity();

    for (int high_state = 0; high_state < params_.S; ++high_state) {
        for (int low_state = 0; low_state < params_.S; ++low_state) {
            const auto candidate_high = static_cast<std::uint8_t>(high_state);
            const auto candidate_low = static_cast<std::uint8_t>(low_state);
            if (candidate_high == positive_high && candidate_low == positive_low) {
                continue;
            }
            best_other_energy =
                std::min(best_other_energy, pair_energy(input_byte, candidate_high, candidate_low));
        }
    }

    return best_other_energy - positive_energy;
}

double GraphV02::total_energy() const {
    double total = 0.0;
    for (int i = 0; i < params_.N; ++i) {
        const NodeV02& node = nodes_[static_cast<std::size_t>(i)];
        for (int channel = 0; channel < params_.channels; ++channel) {
            total += -static_cast<double>(params_.lambda_u) *
                     static_cast<double>(
                         field_.score(channel, node.input_byte, node.state[static_cast<std::size_t>(channel)]));
        }
        total += -static_cast<double>(params_.lambda_b) *
                 static_cast<double>(coupling_.score(node.input_byte, node.state[0], node.state[1]));
        total += 0.5 * static_cast<double>(params_.lambda_v) *
                 static_cast<double>(disagreement(i));
    }
    return total;
}

std::uint8_t GraphV02::positive_state(int index, int channel) const {
    const NodeV02& node = nodes_[static_cast<std::size_t>(index)];
    if (channel == 0) {
        return static_cast<std::uint8_t>(node.target_byte / 16U);
    }
    return static_cast<std::uint8_t>(node.target_byte % 16U);
}

}  // namespace dle
