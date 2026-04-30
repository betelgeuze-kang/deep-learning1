#pragma once

#include <iomanip>
#include <sstream>
#include <string>

namespace dle {

struct CycleMetrics {
    int cycle = 0;
    double H = 0.0;
    double mean_disagreement = 0.0;
    double mean_tick = 0.0;
    double mean_abs_reservoir = 0.0;
    int changed = 0;
    int downhill_accepts = 0;
    int uphill_accepts = 0;
    int rejected = 0;
    int skipped = 0;
};

struct EpochMetricsV02 {
    int epoch = 0;
    double H = 0.0;
    double byte_acc = 0.0;
    double field_byte_acc = 0.0;
    double oracle1_acc = 0.0;
    double ch0_acc = 0.0;
    double ch1_acc = 0.0;
    double field_ch0_acc = 0.0;
    double field_ch1_acc = 0.0;
    double field_margin = 0.0;
    double joint_byte_acc = 0.0;
    double pair_margin = 0.0;
    double mean_disagreement = 0.0;
    double mean_tick = 0.0;
    double mean_abs_reservoir = 0.0;
    int changed = 0;
    int downhill_accepts = 0;
    int uphill_accepts = 0;
    int rejected = 0;
    int skipped = 0;
    double routing_trigger_rate = 0.0;
    double mean_jump_candidates = 0.0;
    double routing_hit_rate = 0.0;
    double active_jump_rate = 0.0;
    double mean_active_jump_neighbors = 0.0;
    double mean_jump_distance = 0.0;
    double route_gap_pass_rate = 0.0;
    double mean_triggered_route_anchor_gap = 0.0;
    double max_triggered_route_anchor_gap = 0.0;
    double mean_triggered_route_gate = 0.0;
    double mean_triggered_route_stress = 0.0;
    double mean_triggered_route_confidence = 0.0;
    double max_triggered_route_confidence = 0.0;
    double route_key_anchor_match_rate = 0.0;
    double route_state_anchor_match_rate = 0.0;
    double route_key_state_match_rate = 0.0;
    double mean_route_key_anchor_hamming = 0.0;
    double triggered_route_key_anchor_match_rate = 0.0;
    double triggered_route_state_anchor_match_rate = 0.0;
    double triggered_route_key_state_match_rate = 0.0;
    double mean_triggered_route_key_anchor_hamming = 0.0;
    double mean_jump_filter_candidates = 0.0;
    double jump_filter_self_rate = 0.0;
    double jump_filter_local_duplicate_rate = 0.0;
    double jump_filter_color_conflict_rate = 0.0;
    double jump_filter_anchor_gap_rate = 0.0;
    double jump_filter_confidence_gain_rate = 0.0;
    double jump_filter_local_replacement_rate = 0.0;
    double jump_filter_selected_rate = 0.0;
    double jump_filter_underfilled_rate = 0.0;
    // Denominator: triggered routing nodes.
    double triggered_route_anchor_gap_gt_0_rate = 0.0;
    double triggered_route_anchor_gap_gt_1e_4_rate = 0.0;
    double triggered_route_anchor_gap_gt_1e_3_rate = 0.0;
    double triggered_route_anchor_gap_gt_1e_2_rate = 0.0;
    // Denominator: triggered routing nodes with anchor_gap > 0.
    double mean_positive_triggered_anchor_gap = 0.0;
    // Denominator: triggered routing nodes with anchor_gap > effective gate.
    double active_jump_gate_pass_rate = 0.0;
    double triggered_route_anchor_gap_gt_1e_6_rate = 0.0;
    double triggered_route_anchor_gap_gt_1e_1_rate = 0.0;
    double p50_triggered_route_anchor_gap = 0.0;
    double p90_triggered_route_anchor_gap = 0.0;
    double p99_triggered_route_anchor_gap = 0.0;
    double mean_triggered_route_gate_margin = 0.0;
    double p90_triggered_route_gate_margin = 0.0;
    double max_triggered_route_gate_margin = 0.0;
    double triggered_route_gap_equal_gate_rate = 0.0;
    double triggered_route_gap_below_gate_rate = 0.0;
    double mean_triggered_route_state_anchor_hamming = 0.0;
    double triggered_route_zero_gap_state_anchor_mismatch_rate = 0.0;
    double triggered_route_reservoir_reason_rate = 0.0;
    double triggered_route_stagnation_reason_rate = 0.0;
    double triggered_route_both_reasons_rate = 0.0;
    double route_hint_applied_rate = 0.0;
    double route_hint_weight_mean = 0.0;
    double route_hint_query_count = 0.0;
    double route_hint_value_match_rate = 0.0;
    double fixture_query_acc = 0.0;
    double fixture_query_byte_acc = 0.0;
    double fixture_query_hi_acc = 0.0;
    double fixture_query_lo_acc = 0.0;
    double fixture_query_field_acc = 0.0;
    double fixture_query_joint_acc = 0.0;
    double query_route_hint_margin_mean = 0.0;
    double query_local_margin_against_route_mean = 0.0;
    double query_effective_route_margin_mean = 0.0;
    double route_strength_mean = 0.0;
    double route_strength_p50 = 0.0;
    double route_strength_p90 = 0.0;
    double route_strength_max = 0.0;
    double route_candidate_corrupt_rate = 0.0;
    double route_correct_candidate_rate = 0.0;
    double route_wrong_hint_applied_rate = 0.0;
    double route_wrong_hint_strength_mean = 0.0;
    double route_correct_hint_strength_mean = 0.0;
    double route_candidate_conf_correct_mean = 0.0;
    double route_candidate_conf_wrong_mean = 0.0;
    double route_candidate_conf_gap = 0.0;
    double route_value_top_correct_rate = 0.0;
    double route_value_conf_correct_mean = 0.0;
    double route_value_conf_wrong_mean = 0.0;
    double route_value_conf_gap = 0.0;
    double route_agreement_conf_correct_mean = 0.0;
    double route_agreement_conf_wrong_mean = 0.0;
    double route_agreement_conf_gap = 0.0;
    double route_agreement_top_correct_rate = 0.0;
    double route_lowconf_query_rate = 0.0;
    double route_highconf_query_rate = 0.0;
    double route_lowconf_qacc = 0.0;
    double route_highconf_qacc = 0.0;
    double route_lowconf_wrong_strength_mean = 0.0;
    double route_highconf_wrong_strength_mean = 0.0;
    double route_lowconf_candidate_recall = 0.0;
    double route_highconf_candidate_recall = 0.0;
    double route_lowconf_top1 = 0.0;
    double route_highconf_top1 = 0.0;
    double route_lowconf_correct_value_vote_share = 0.0;
    double route_highconf_correct_value_vote_share = 0.0;
    double route_lowconf_unique_values = 0.0;
    double route_highconf_unique_values = 0.0;
    double route_lowconf_vote_entropy = 0.0;
    double route_highconf_vote_entropy = 0.0;
    double route_lowconf_route_margin = 0.0;
    double route_highconf_route_margin = 0.0;
    double route_lowconf_local_margin = 0.0;
    double route_highconf_local_margin = 0.0;
    double route_lowconf_hi_acc = 0.0;
    double route_highconf_hi_acc = 0.0;
    double route_lowconf_lo_acc = 0.0;
    double route_highconf_lo_acc = 0.0;
    double route_agg_policy_vote_rate = 0.0;
    double route_agg_policy_weighted_rate = 0.0;
    double route_lowconf_policy_none_rate = 0.0;
    double route_lowconf_policy_weak_vote_rate = 0.0;
    double route_lowconf_policy_aggregate_rate = 0.0;
    double route_lowconf_effective_strength_mean = 0.0;
    double route_highconf_effective_strength_mean = 0.0;
    double route_primary_recall = 0.0;
    double route_primary_lowconf_rate = 0.0;
    double route_fallback_used_rate = 0.0;
    double route_fallback_recall = 0.0;
    double route_fallback_qacc = 0.0;
    double route_fallback_success_rate = 0.0;
    double route_fallback_hi_acc = 0.0;
    double route_fallback_lo_acc = 0.0;
    double route_fallback_route_margin_mean = 0.0;
    double route_fallback_effective_strength_mean = 0.0;
    double route_fallback_hi_effective_strength_mean = 0.0;
    double route_fallback_lo_effective_strength_mean = 0.0;
    double route_fallback_strength_p50 = 0.0;
    double route_fallback_strength_p90 = 0.0;
    double route_fallback_strength_max = 0.0;
    double route_fallback_local_margin_against_route_mean = 0.0;
    double route_fallback_hi_local_margin_against_route_mean = 0.0;
    double route_fallback_lo_local_margin_against_route_mean = 0.0;
    double route_abstain_rate = 0.0;
    double route_hint_strength_mean = 0.0;
    double route_hint_candidate_lookup_count = 0.0;
    double route_hint_candidate_hit_rate = 0.0;
    double route_hint_value_read_distance_mean = 0.0;
    double kv_record_count = 0.0;
    double kv_query_count = 0.0;
    double kv_query_hit_rate = 0.0;
    double kv_duplicate_key_rate = 0.0;
    double kv_missing_key_rate = 0.0;
    double route_candidate_query_count = 0.0;
    double route_candidate_recall_rate = 0.0;
    double route_candidate_top1_rate = 0.0;
    double route_candidate_rank_mean = 0.0;
    double route_bucket_load_mean = 0.0;
    double route_bucket_load_max = 0.0;
    double route_bucket_collision_rate = 0.0;
    double route_hint_vote_candidate_count_mean = 0.0;
    double route_hint_vote_margin_mean = 0.0;
    double route_hint_correct_value_vote_share_mean = 0.0;
    double route_hint_vote_entropy_mean = 0.0;
    double route_hint_unique_values_mean = 0.0;
    double key_region_count = 0.0;
    double key_region_joint_decode_acc = 0.0;
    double raw_key_unique_count = 0.0;
    double joint_key_unique_count = 0.0;
    double joint_signature_collision_rate = 0.0;
    double joint_vs_raw_candidate_overlap_rate = 0.0;
    double key_region_route_decode_acc = 0.0;
    double route_key_unique_count = 0.0;
    double route_signature_collision_rate = 0.0;
    double route_vs_raw_candidate_overlap_rate = 0.0;
};

inline std::string v01_csv_header() {
    return "cycle,H,mean_disagreement,mean_tick,mean_abs_reservoir,changed,downhill_accepts,"
           "uphill_accepts,rejected,skipped";
}

inline std::string v02_csv_header() {
    return "epoch,H,byte_acc,field_byte_acc,oracle1_acc,ch0_acc,ch1_acc,field_ch0_acc,"
           "field_ch1_acc,field_margin,mean_disagreement,mean_tick,mean_abs_reservoir,"
           "changed,downhill_accepts,uphill_accepts,rejected,skipped,joint_byte_acc,"
           "pair_margin,routing_trigger_rate,mean_jump_candidates,routing_hit_rate,"
           "active_jump_rate,mean_active_jump_neighbors,mean_jump_distance,"
           "route_gap_pass_rate,mean_triggered_route_anchor_gap,max_triggered_route_anchor_gap,"
           "mean_triggered_route_gate,mean_triggered_route_stress,"
           "mean_triggered_route_confidence,max_triggered_route_confidence,"
           "route_key_anchor_match_rate,route_state_anchor_match_rate,"
           "route_key_state_match_rate,mean_route_key_anchor_hamming,"
           "triggered_route_key_anchor_match_rate,"
           "triggered_route_state_anchor_match_rate,"
           "triggered_route_key_state_match_rate,"
           "mean_triggered_route_key_anchor_hamming,"
           "mean_jump_filter_candidates,jump_filter_self_rate,"
           "jump_filter_local_duplicate_rate,jump_filter_color_conflict_rate,"
           "jump_filter_anchor_gap_rate,jump_filter_confidence_gain_rate,"
           "jump_filter_local_replacement_rate,jump_filter_selected_rate,"
           "jump_filter_underfilled_rate,triggered_route_anchor_gap_gt_0_rate,"
           "triggered_route_anchor_gap_gt_1e_4_rate,"
           "triggered_route_anchor_gap_gt_1e_3_rate,"
           "triggered_route_anchor_gap_gt_1e_2_rate,"
           "mean_positive_triggered_anchor_gap,active_jump_gate_pass_rate,"
           "triggered_route_anchor_gap_gt_1e_6_rate,"
           "triggered_route_anchor_gap_gt_1e_1_rate,"
           "p50_triggered_route_anchor_gap,p90_triggered_route_anchor_gap,"
           "p99_triggered_route_anchor_gap,mean_triggered_route_gate_margin,"
           "p90_triggered_route_gate_margin,max_triggered_route_gate_margin,"
           "triggered_route_gap_equal_gate_rate,triggered_route_gap_below_gate_rate,"
           "mean_triggered_route_state_anchor_hamming,"
           "triggered_route_zero_gap_state_anchor_mismatch_rate,"
           "triggered_route_reservoir_reason_rate,"
           "triggered_route_stagnation_reason_rate,"
           "triggered_route_both_reasons_rate,route_hint_applied_rate,"
           "route_hint_weight_mean,route_hint_query_count,"
           "route_hint_value_match_rate,fixture_query_acc,"
           "fixture_query_byte_acc,fixture_query_hi_acc,fixture_query_lo_acc,"
           "fixture_query_field_acc,fixture_query_joint_acc,"
           "query_route_hint_margin_mean,query_local_margin_against_route_mean,"
           "query_effective_route_margin_mean,route_strength_mean,route_strength_p50,"
           "route_strength_p90,route_strength_max,route_candidate_corrupt_rate,"
           "route_correct_candidate_rate,route_wrong_hint_applied_rate,"
           "route_wrong_hint_strength_mean,route_correct_hint_strength_mean,"
           "route_candidate_conf_correct_mean,route_candidate_conf_wrong_mean,"
           "route_candidate_conf_gap,route_value_top_correct_rate,"
           "route_value_conf_correct_mean,route_value_conf_wrong_mean,"
           "route_value_conf_gap,route_agreement_conf_correct_mean,"
           "route_agreement_conf_wrong_mean,route_agreement_conf_gap,"
           "route_agreement_top_correct_rate,"
           "route_lowconf_query_rate,route_highconf_query_rate,"
           "route_lowconf_qacc,route_highconf_qacc,"
           "route_lowconf_wrong_strength_mean,route_highconf_wrong_strength_mean,"
           "route_lowconf_candidate_recall,route_highconf_candidate_recall,"
           "route_lowconf_top1,route_highconf_top1,"
           "route_lowconf_correct_value_vote_share,"
           "route_highconf_correct_value_vote_share,"
           "route_lowconf_unique_values,route_highconf_unique_values,"
           "route_lowconf_vote_entropy,route_highconf_vote_entropy,"
           "route_lowconf_route_margin,route_highconf_route_margin,"
           "route_lowconf_local_margin,route_highconf_local_margin,"
           "route_lowconf_hi_acc,route_highconf_hi_acc,"
           "route_lowconf_lo_acc,route_highconf_lo_acc,"
           "route_agg_policy_vote_rate,route_agg_policy_weighted_rate,"
           "route_lowconf_policy_none_rate,route_lowconf_policy_weak_vote_rate,"
           "route_lowconf_policy_aggregate_rate,"
           "route_lowconf_effective_strength_mean,"
           "route_highconf_effective_strength_mean,"
           "route_primary_recall,route_primary_lowconf_rate,"
           "route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,"
           "route_fallback_success_rate,route_fallback_hi_acc,route_fallback_lo_acc,"
           "route_fallback_route_margin_mean,"
           "route_fallback_effective_strength_mean,"
           "route_fallback_hi_effective_strength_mean,"
           "route_fallback_lo_effective_strength_mean,route_fallback_strength_p50,"
           "route_fallback_strength_p90,route_fallback_strength_max,"
           "route_fallback_local_margin_against_route_mean,"
           "route_fallback_hi_local_margin_against_route_mean,"
           "route_fallback_lo_local_margin_against_route_mean,route_abstain_rate,"
           "route_hint_strength_mean,"
           "route_hint_candidate_lookup_count,route_hint_candidate_hit_rate,"
           "route_hint_value_read_distance_mean,kv_record_count,kv_query_count,"
           "kv_query_hit_rate,kv_duplicate_key_rate,kv_missing_key_rate,"
           "route_candidate_query_count,route_candidate_recall_rate,"
           "route_candidate_top1_rate,route_candidate_rank_mean,"
           "route_bucket_load_mean,route_bucket_load_max,route_bucket_collision_rate,"
           "route_hint_vote_candidate_count_mean,route_hint_vote_margin_mean,"
           "route_hint_correct_value_vote_share_mean,route_hint_vote_entropy_mean,"
           "route_hint_unique_values_mean,key_region_count,key_region_joint_decode_acc,"
           "raw_key_unique_count,joint_key_unique_count,joint_signature_collision_rate,"
           "joint_vs_raw_candidate_overlap_rate,key_region_route_decode_acc,"
           "route_key_unique_count,route_signature_collision_rate,"
           "route_vs_raw_candidate_overlap_rate";
}

inline std::string to_csv_row(const CycleMetrics& metrics) {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(6) << metrics.cycle << ',' << metrics.H << ','
        << metrics.mean_disagreement << ',' << metrics.mean_tick << ','
        << metrics.mean_abs_reservoir << ',' << metrics.changed << ','
        << metrics.downhill_accepts << ',' << metrics.uphill_accepts << ','
        << metrics.rejected << ',' << metrics.skipped;
    return oss.str();
}

inline std::string to_csv_row(const EpochMetricsV02& metrics) {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(6) << metrics.epoch << ',' << metrics.H << ','
        << metrics.byte_acc << ',' << metrics.field_byte_acc << ',' << metrics.oracle1_acc
        << ',' << metrics.ch0_acc << ',' << metrics.ch1_acc << ','
        << metrics.field_ch0_acc << ',' << metrics.field_ch1_acc << ','
        << metrics.field_margin << ',' << metrics.mean_disagreement << ','
        << metrics.mean_tick << ',' << metrics.mean_abs_reservoir << ',' << metrics.changed
        << ',' << metrics.downhill_accepts << ',' << metrics.uphill_accepts << ','
        << metrics.rejected << ',' << metrics.skipped << ',' << metrics.joint_byte_acc
        << ',' << metrics.pair_margin << ',' << metrics.routing_trigger_rate << ','
        << metrics.mean_jump_candidates << ',' << metrics.routing_hit_rate << ','
        << metrics.active_jump_rate << ',' << metrics.mean_active_jump_neighbors << ','
        << metrics.mean_jump_distance << ',' << metrics.route_gap_pass_rate << ','
        << metrics.mean_triggered_route_anchor_gap << ','
        << metrics.max_triggered_route_anchor_gap << ','
        << metrics.mean_triggered_route_gate << ','
        << metrics.mean_triggered_route_stress << ','
        << metrics.mean_triggered_route_confidence << ','
        << metrics.max_triggered_route_confidence << ','
        << metrics.route_key_anchor_match_rate << ','
        << metrics.route_state_anchor_match_rate << ','
        << metrics.route_key_state_match_rate << ','
        << metrics.mean_route_key_anchor_hamming << ','
        << metrics.triggered_route_key_anchor_match_rate << ','
        << metrics.triggered_route_state_anchor_match_rate << ','
        << metrics.triggered_route_key_state_match_rate << ','
        << metrics.mean_triggered_route_key_anchor_hamming << ','
        << metrics.mean_jump_filter_candidates << ','
        << metrics.jump_filter_self_rate << ','
        << metrics.jump_filter_local_duplicate_rate << ','
        << metrics.jump_filter_color_conflict_rate << ','
        << metrics.jump_filter_anchor_gap_rate << ','
        << metrics.jump_filter_confidence_gain_rate << ','
        << metrics.jump_filter_local_replacement_rate << ','
        << metrics.jump_filter_selected_rate << ','
        << metrics.jump_filter_underfilled_rate << ','
        << metrics.triggered_route_anchor_gap_gt_0_rate << ','
        << metrics.triggered_route_anchor_gap_gt_1e_4_rate << ','
        << metrics.triggered_route_anchor_gap_gt_1e_3_rate << ','
        << metrics.triggered_route_anchor_gap_gt_1e_2_rate << ','
        << metrics.mean_positive_triggered_anchor_gap << ','
        << metrics.active_jump_gate_pass_rate << ','
        << metrics.triggered_route_anchor_gap_gt_1e_6_rate << ','
        << metrics.triggered_route_anchor_gap_gt_1e_1_rate << ','
        << metrics.p50_triggered_route_anchor_gap << ','
        << metrics.p90_triggered_route_anchor_gap << ','
        << metrics.p99_triggered_route_anchor_gap << ','
        << metrics.mean_triggered_route_gate_margin << ','
        << metrics.p90_triggered_route_gate_margin << ','
        << metrics.max_triggered_route_gate_margin << ','
        << metrics.triggered_route_gap_equal_gate_rate << ','
        << metrics.triggered_route_gap_below_gate_rate << ','
        << metrics.mean_triggered_route_state_anchor_hamming << ','
        << metrics.triggered_route_zero_gap_state_anchor_mismatch_rate << ','
        << metrics.triggered_route_reservoir_reason_rate << ','
        << metrics.triggered_route_stagnation_reason_rate << ','
        << metrics.triggered_route_both_reasons_rate << ','
        << metrics.route_hint_applied_rate << ','
        << metrics.route_hint_weight_mean << ','
        << metrics.route_hint_query_count << ','
        << metrics.route_hint_value_match_rate << ','
        << metrics.fixture_query_acc << ','
        << metrics.fixture_query_byte_acc << ','
        << metrics.fixture_query_hi_acc << ','
        << metrics.fixture_query_lo_acc << ','
        << metrics.fixture_query_field_acc << ','
        << metrics.fixture_query_joint_acc << ','
        << metrics.query_route_hint_margin_mean << ','
        << metrics.query_local_margin_against_route_mean << ','
        << metrics.query_effective_route_margin_mean << ','
        << metrics.route_strength_mean << ','
        << metrics.route_strength_p50 << ','
        << metrics.route_strength_p90 << ','
        << metrics.route_strength_max << ','
        << metrics.route_candidate_corrupt_rate << ','
        << metrics.route_correct_candidate_rate << ','
        << metrics.route_wrong_hint_applied_rate << ','
        << metrics.route_wrong_hint_strength_mean << ','
        << metrics.route_correct_hint_strength_mean << ','
        << metrics.route_candidate_conf_correct_mean << ','
        << metrics.route_candidate_conf_wrong_mean << ','
        << metrics.route_candidate_conf_gap << ','
        << metrics.route_value_top_correct_rate << ','
        << metrics.route_value_conf_correct_mean << ','
        << metrics.route_value_conf_wrong_mean << ','
        << metrics.route_value_conf_gap << ','
        << metrics.route_agreement_conf_correct_mean << ','
        << metrics.route_agreement_conf_wrong_mean << ','
        << metrics.route_agreement_conf_gap << ','
        << metrics.route_agreement_top_correct_rate << ','
        << metrics.route_lowconf_query_rate << ','
        << metrics.route_highconf_query_rate << ','
        << metrics.route_lowconf_qacc << ','
        << metrics.route_highconf_qacc << ','
        << metrics.route_lowconf_wrong_strength_mean << ','
        << metrics.route_highconf_wrong_strength_mean << ','
        << metrics.route_lowconf_candidate_recall << ','
        << metrics.route_highconf_candidate_recall << ','
        << metrics.route_lowconf_top1 << ','
        << metrics.route_highconf_top1 << ','
        << metrics.route_lowconf_correct_value_vote_share << ','
        << metrics.route_highconf_correct_value_vote_share << ','
        << metrics.route_lowconf_unique_values << ','
        << metrics.route_highconf_unique_values << ','
        << metrics.route_lowconf_vote_entropy << ','
        << metrics.route_highconf_vote_entropy << ','
        << metrics.route_lowconf_route_margin << ','
        << metrics.route_highconf_route_margin << ','
        << metrics.route_lowconf_local_margin << ','
        << metrics.route_highconf_local_margin << ','
        << metrics.route_lowconf_hi_acc << ','
        << metrics.route_highconf_hi_acc << ','
        << metrics.route_lowconf_lo_acc << ','
        << metrics.route_highconf_lo_acc << ','
        << metrics.route_agg_policy_vote_rate << ','
        << metrics.route_agg_policy_weighted_rate << ','
        << metrics.route_lowconf_policy_none_rate << ','
        << metrics.route_lowconf_policy_weak_vote_rate << ','
        << metrics.route_lowconf_policy_aggregate_rate << ','
        << metrics.route_lowconf_effective_strength_mean << ','
        << metrics.route_highconf_effective_strength_mean << ','
        << metrics.route_primary_recall << ','
        << metrics.route_primary_lowconf_rate << ','
        << metrics.route_fallback_used_rate << ','
        << metrics.route_fallback_recall << ','
        << metrics.route_fallback_qacc << ','
        << metrics.route_fallback_success_rate << ','
        << metrics.route_fallback_hi_acc << ','
        << metrics.route_fallback_lo_acc << ','
        << metrics.route_fallback_route_margin_mean << ','
        << metrics.route_fallback_effective_strength_mean << ','
        << metrics.route_fallback_hi_effective_strength_mean << ','
        << metrics.route_fallback_lo_effective_strength_mean << ','
        << metrics.route_fallback_strength_p50 << ','
        << metrics.route_fallback_strength_p90 << ','
        << metrics.route_fallback_strength_max << ','
        << metrics.route_fallback_local_margin_against_route_mean << ','
        << metrics.route_fallback_hi_local_margin_against_route_mean << ','
        << metrics.route_fallback_lo_local_margin_against_route_mean << ','
        << metrics.route_abstain_rate << ','
        << metrics.route_hint_strength_mean << ','
        << metrics.route_hint_candidate_lookup_count << ','
        << metrics.route_hint_candidate_hit_rate << ','
        << metrics.route_hint_value_read_distance_mean << ','
        << metrics.kv_record_count << ','
        << metrics.kv_query_count << ','
        << metrics.kv_query_hit_rate << ','
        << metrics.kv_duplicate_key_rate << ','
        << metrics.kv_missing_key_rate << ','
        << metrics.route_candidate_query_count << ','
        << metrics.route_candidate_recall_rate << ','
        << metrics.route_candidate_top1_rate << ','
        << metrics.route_candidate_rank_mean << ','
        << metrics.route_bucket_load_mean << ','
        << metrics.route_bucket_load_max << ','
        << metrics.route_bucket_collision_rate << ','
        << metrics.route_hint_vote_candidate_count_mean << ','
        << metrics.route_hint_vote_margin_mean << ','
        << metrics.route_hint_correct_value_vote_share_mean << ','
        << metrics.route_hint_vote_entropy_mean << ','
        << metrics.route_hint_unique_values_mean << ','
        << metrics.key_region_count << ','
        << metrics.key_region_joint_decode_acc << ','
        << metrics.raw_key_unique_count << ','
        << metrics.joint_key_unique_count << ','
        << metrics.joint_signature_collision_rate << ','
        << metrics.joint_vs_raw_candidate_overlap_rate << ','
        << metrics.key_region_route_decode_acc << ','
        << metrics.route_key_unique_count << ','
        << metrics.route_signature_collision_rate << ','
        << metrics.route_vs_raw_candidate_overlap_rate;
    return oss.str();
}

}  // namespace dle
