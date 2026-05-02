#pragma once

#include <array>
#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

#include "common/Metrics.hpp"
#include "common/Params.hpp"
#include "common/RNG.hpp"
#include "v02_pre/ByteDataset.hpp"
#include "v02_pre/CouplingTable.hpp"
#include "v02_pre/FieldTable.hpp"
#include "v02_pre/NodeV02.hpp"
#include "v02_pre/RoutingTable.hpp"

namespace dle {

class GraphV02 {
  public:
    explicit GraphV02(const V02PreParams& params);

    void begin_epoch(const ByteDataset::Window& window);
    EpochMetricsV02 run_epoch(
        int epoch,
        const std::array<std::uint8_t, FieldTable::ByteValues>& oracle_next);
    void apply_contrastive_learning();

  private:
    struct Candidate {
        std::array<std::uint8_t, FieldTable::Channels> state{0, 0};
        float delta = 0.0f;
        float delta_eff = 0.0f;
        int changed_channels = 0;
        bool valid = false;
    };

    struct JumpNeighborDiagnostics {
        int candidate_slots_examined = 0;
        int self_rejects = 0;
        int local_duplicate_rejects = 0;
        int color_rejects = 0;
        int anchor_gap_rejects = 0;
        int confidence_gain_rejects = 0;
        int local_score_rejects = 0;
        int selected_jumps = 0;
        bool underfilled = false;
    };

    void validate_params() const;
    Candidate sample_best_candidate(int index);
    Candidate best_block_candidate(int index) const;
    Candidate make_candidate(int index, std::uint8_t new_high, std::uint8_t new_low) const;
    bool pair_proposals_enabled() const;
    bool routing_enabled() const;
    bool jump_neighbors_active() const;
    bool route_hint_oracle_active() const;
    bool route_hint_parsed_active() const;
    bool route_hint_kv_exact_active() const;
    bool route_hint_kv_hash_active() const;
    bool joint_code_key_hash_active() const;
    bool route_code_key_hash_active() const;
    bool learned_code_key_hash_active() const;
    bool route_hint_active() const;
    bool route_hint_value_for_node(int index, std::uint8_t& out_value) const;
    bool route_hint_proposal_value_for_node(int index, std::uint8_t& out_value) const;
    double route_hint_margin_for_node(int index, std::uint8_t target_value) const;
    double route_value_support_confidence_for_node(int index, std::uint8_t target_value) const;
    double route_top_value_confidence_for_node(int index) const;
    double route_top_value_is_target(int index, std::uint8_t target_value) const;
    bool route_agreement_votes_for_node(
        int index,
        std::array<int, FieldTable::ByteValues>& votes,
        std::array<int, FieldTable::ByteValues>& first_seen,
        int& scorer_count) const;
    double route_agreement_confidence_for_node(int index, std::uint8_t target_value) const;
    double route_agreement_top_confidence_for_node(int index) const;
    double route_agreement_top_value_is_target(int index, std::uint8_t target_value) const;
    double route_aggregation_confidence_for_node(int index, std::uint8_t target_value) const;
    std::string route_effective_hint_agg_for_node(int index, std::uint8_t target_value) const;
    bool route_low_confidence_for_node(int index, std::uint8_t target_value) const;
    float route_effective_policy_scale_for_node(int index, std::uint8_t target_value) const;
    double local_energy_without_route(int index, std::uint8_t high, std::uint8_t low) const;
    double local_margin_against_route(int index, std::uint8_t target_value) const;
    double local_channel_margin_against_route(
        int index,
        int channel,
        std::uint8_t target_state) const;
    float compute_route_effective_strength_for_node(int index, std::uint8_t target_value) const;
    float route_effective_strength_for_node(int index, std::uint8_t target_value) const;
    float route_fallback_channel_strength_scale_for_node(int index, int channel) const;
    float route_fallback_channel_effective_strength_for_node(
        int index,
        int channel,
        std::uint8_t target_value,
        float base_strength) const;
    void refresh_route_strength_cache();
    void apply_route_candidate_corruption();
    void apply_route_fallback_source(const ByteDataset::Window& window);
    void refresh_route_hint_candidate_keys();
    bool candidate_positions_contain_correct(int index) const;
    bool should_corrupt_route_candidate(int index) const;
    bool route_fallback_persistence_active(int index) const;
    std::string route_credit_query_signature(int query_index) const;
    std::string route_credit_edge_key(int query_index, int value_pos) const;
    float route_credit_for_candidate(int query_index, int value_pos) const;
    float route_credit_weight_for_candidate(int query_index, int value_pos) const;
    void apply_route_credit_learning();
    int wrong_route_value_position_for_node(int index) const;
    std::string joint_code_signature_for_key(const std::string& key) const;
    std::uint32_t joint_code_hash_for_key(const std::string& key) const;
    std::uint8_t route_code_for_byte(std::uint8_t input_byte) const;
    std::string route_code_signature_for_key(const std::string& key) const;
    std::uint32_t route_code_hash_for_key(const std::string& key) const;
    std::uint32_t learned_code_hash_for_key(const std::string& key) const;
    void refresh_key_region_diagnostics(const ByteDataset::Window& window);
    void rebuild_learned_code_key_route_hints(const ByteDataset::Window& window);
    bool routing_triggered(int index) const;
    void rebuild_routing_table();
    std::uint8_t route_key_for_node(const NodeV02& node) const;
    float route_score_for_node(const NodeV02& node) const;
    double route_min_anchor_gap() const;
    double route_stress(int index) const;
    double effective_route_min_anchor_gap(int index) const;
    double route_anchor_gap(int index) const;
    void refresh_route_confidence_cache();
    void refresh_route_anchor_cache();
    double compute_route_confidence_margin(std::uint8_t input_byte) const;
    int edge_disagreement(int index, int neighbor_index) const;
    int local_disagreement(int index) const;
    int active_jump_neighbor_count(int index) const;
    int fill_effective_neighbors(
        int index,
        std::array<int, 8>& out_neighbors,
        JumpNeighborDiagnostics* diagnostics = nullptr) const;
    int ring_distance(int from, int to) const;
    float delta_energy(int index, int channel, std::uint8_t new_state) const;
    float delta_energy(int index, std::uint8_t new_high, std::uint8_t new_low) const;
    int disagreement(int index) const;
    float local_temperature(int index) const;
    void try_update_node(int index, int& accepted, int& downhill, int& uphill, int& rejected, int& skipped);
    void accept_update(int index, const Candidate& candidate, int& accepted, int& downhill, int& uphill);
    void relax_tick_and_reservoir();
    void update_age();
    EpochMetricsV02 collect_metrics(
        int epoch,
        const std::array<std::uint8_t, FieldTable::ByteValues>& oracle_next,
        int changed,
        int downhill,
        int uphill,
        int rejected,
        int skipped) const;
    double pair_energy(std::uint8_t input_byte, std::uint8_t high_state, std::uint8_t low_state) const;
    double route_confidence_margin(std::uint8_t input_byte) const;
    std::uint8_t best_joint_byte(std::uint8_t input_byte) const;
    double positive_pair_margin(
        std::uint8_t input_byte,
        std::uint8_t positive_high,
        std::uint8_t positive_low) const;
    double total_energy() const;
    std::uint8_t positive_state(int index, int channel) const;

    V02PreParams params_;
    RNG rng_;
    FieldTable field_;
    FieldTable route_field_;
    CouplingTable coupling_;
    RoutingTable routing_;
    std::vector<std::uint8_t> route_keys_;
    std::vector<std::uint8_t> route_hint_values_;
    std::vector<int> route_hint_value_positions_;
    std::vector<std::vector<int>> route_hint_candidate_value_positions_;
    std::vector<float> route_hint_weights_;
    std::vector<float> route_strength_cache_;
    std::vector<int> route_hint_correct_value_positions_;
    std::vector<bool> route_hint_corrupted_;
    std::vector<bool> route_hint_primary_has_correct_;
    std::vector<bool> route_hint_fallback_used_;
    std::vector<bool> route_hint_fallback_recovered_;
    std::vector<int> route_fallback_persist_remaining_;
    std::vector<int> route_fallback_persist_visits_;
    std::vector<float> route_credit_by_value_pos_;
    std::unordered_map<std::string, float> route_credit_by_query_value_;
    std::vector<int> route_value_positions_;
    std::vector<std::string> route_value_position_keys_;
    std::vector<std::string> route_hint_query_keys_;
    std::vector<std::vector<std::string>> route_hint_candidate_keys_;
    std::vector<bool> key_region_mask_;
    int kv_record_count_ = 0;
    int kv_duplicate_key_count_ = 0;
    int kv_query_count_ = 0;
    int kv_query_hit_count_ = 0;
    int kv_missing_key_count_ = 0;
    int route_candidate_query_count_ = 0;
    int route_candidate_hit_count_ = 0;
    int route_candidate_top1_hit_count_ = 0;
    double route_candidate_rank_sum_ = 0.0;
    int route_bucket_load_sum_ = 0;
    int route_bucket_load_max_ = 0;
    int route_bucket_collision_count_ = 0;
    int key_region_count_ = 0;
    int key_region_joint_decode_hit_count_ = 0;
    int key_region_route_decode_hit_count_ = 0;
    int raw_key_unique_count_ = 0;
    int joint_key_unique_count_ = 0;
    int route_key_unique_count_ = 0;
    double joint_vs_raw_candidate_overlap_sum_ = 0.0;
    int joint_vs_raw_candidate_overlap_count_ = 0;
    double route_vs_raw_candidate_overlap_sum_ = 0.0;
    int route_vs_raw_candidate_overlap_count_ = 0;
    std::array<double, FieldTable::ByteValues> route_confidence_cache_{};
    std::array<std::uint8_t, FieldTable::ByteValues> route_anchor_cache_{};
    std::vector<NodeV02> nodes_;
    std::vector<bool> changed_this_cycle_;
    bool coupling_has_signal_ = false;
};

}  // namespace dle
