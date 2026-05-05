#pragma once

#include <string>

namespace dle {

struct V01Params {
    int N = 1000;
    int S = 16;
    int R = 4;
    int K = 8;
    int C_colors = 9;
    int cycles = 1000;
    int seed = 1;

    float lambda_u = 1.0f;
    float lambda_v = 0.25f;
    float lambda_m = 0.05f;

    float eta_r = 0.10f;
    float eta_tau = 0.25f;
    float tau_max = 4.0f;
    float tau_decay = 0.05f;
    float reservoir_decay = 0.01f;

    float T0 = 0.0f;
    float alpha_T = 0.20f;
    float eps_T = 1e-6f;

    int stagnation_window = 8;
    int stagnation_threshold = 2;
    int proposal_count = 4;

    float mass_init = 1.0f;
    std::string csv_path;
};

struct V02PreParams {
    int N = 256;
    int S = 16;
    int channels = 2;

    int R = 4;
    int K = 8;
    int C_colors = 9;

    int epochs = 300;
    int cycles_per_epoch = 20;
    int seed = 1;

    float lambda_v = 0.0f;
    float lambda_u = 1.0f;
    float lambda_b = 0.0f;
    float lambda_m = 0.05f;

    float eta_r = 0.10f;
    float eta_tau = 0.25f;
    float tau_max = 4.0f;
    float tau_decay = 0.05f;
    float reservoir_decay = 0.01f;

    float T0 = 0.0f;
    float alpha_T = 0.20f;
    float eps_T = 1e-6f;

    int stagnation_window = 8;
    int stagnation_threshold = 2;
    int proposal_count = 4;

    float eta_h = 0.05f;
    float eta_b = 0.0f;
    float lambda_h = 1e-4f;
    float H_clip = 8.0f;
    float mass_init = 0.0f;
    int K_jump = 0;
    float route_reservoir_threshold = 0.10f;
    float route_min_anchor_gap = -1.0f;
    float route_adaptive_gap_scale = 0.0f;
    float route_confidence_gap_scale = 0.0f;
    float route_accept_confidence_gain = 0.0f;
    float lambda_route = 0.0f;
    std::string route_strength_mode = "fixed";
    float lambda_route_base = 0.0f;
    float lambda_route_max = 10.0f;
    float route_margin_alpha = 1.0f;
    float route_confidence_power = 1.0f;
    float route_min_confidence = 0.0f;
    float route_corrupt_candidate_rate = 0.0f;
    float route_noisy_source_rate = 0.0f;
    std::string route_corrupt_confidence = "keep";
    float route_corrupt_confidence_value = 0.1f;
    int route_corrupt_preserve_correct = 0;
    std::string route_strength_confidence = "weight";
    float route_confidence_threshold = 0.50f;
    std::string route_lowconf_policy = "aggregate";
    float route_lowconf_weak_scale = 0.50f;
    std::string route_lowconf_agg = "vote";
    std::string route_highconf_agg = "weighted-vote";
    std::string route_aggregation_confidence = "agreement";
    std::string route_fallback_source = "off";
    std::string route_fallback_strength_mode = "fixed";
    float route_fallback_strength_mult = 1.0f;
    float route_fallback_hi_strength_mult = 1.0f;
    float route_fallback_lo_strength_mult = 1.0f;
    std::string route_fallback_channel_strength_mode = "fixed";
    float route_fallback_lambda_base = 0.5f;
    float route_fallback_lambda_max = 50.0f;
    float route_fallback_margin_alpha = 1.0f;
    float route_fallback_hi_lambda_base = 0.5f;
    float route_fallback_lo_lambda_base = 0.5f;
    float route_fallback_hi_lambda_max = 50.0f;
    float route_fallback_lo_lambda_max = 50.0f;
    float route_fallback_hi_margin_alpha = 1.0f;
    float route_fallback_lo_margin_alpha = 1.0f;
    int route_fallback_persist_cycles = 0;
    int route_credit_learning = 0;
    std::string route_credit_mode = "value-pos";
    float route_credit_score_weight = 1.0f;
    float route_credit_eta_reward = 0.05f;
    float route_credit_eta_slash = 0.10f;
    float route_credit_decay = 0.001f;
    float route_credit_clip = 4.0f;
    int route_source_credit_learning = 0;
    std::string route_source_credit_apply_mode = "ranking";
    float route_source_credit_score_weight = 1.0f;
    float route_source_credit_eta_reward = 0.05f;
    float route_source_credit_eta_slash = 0.10f;
    float route_source_credit_decay = 0.001f;
    float route_source_credit_clip = 4.0f;
    std::string route_source_filter_mode = "off";
    float route_source_filter_threshold = 0.0f;
    std::string route_source_retry_source = "off";
    std::string route_source_retry_policy = "fixed";
    std::string route_source_retry_tiebreak = "source-order";
    std::string route_source_retry_priorities;
    std::string route_source_retry_prior_mode = "static";
    float route_source_retry_prior_decay = 1.0f;
    int route_source_retry_prior_warmup_epochs = 0;
    std::string route_source_retry_candidates = "raw-key,key-shape";
    int route_source_retry_per_source_limit = 1;
    int route_quality_diagnostics = 0;
    std::string route_quality_feature_set = "value-only";
    std::string route_quality_apply = "none";
    float route_quality_eps = 1e-4f;
    int route_channel_tension_diagnostics = 0;
    std::string route_channel_tension_mode = "margin";
    int route_quality_score = 0;
    float route_quality_logdet_weight = 0.1f;
    float route_quality_entropy_weight = 0.5f;
    float route_quality_vote_margin_weight = 1.0f;
    float route_quality_top_share_weight = 1.0f;
    float route_quality_source_credit_weight = 0.5f;
    float route_quality_edge_credit_weight = 0.5f;
    float route_quality_channel_weight = 0.1f;
    int route_plasticity_ledger = 0;
    float route_plasticity_ledger_decay = 0.0f;
    int route_credit_learn_after_epoch = 0;
    int route_credit_apply_after_epoch = 0;
    int K_route = 1;
    int route_hash_bits = 16;
    std::string route_hash_source = "raw-key";
    int route_code_aux = 0;
    int route_code_key_region_only = 1;
    float route_code_key_region_keep_prob = 1.0f;
    float route_code_aux_noise_rate = 0.0f;
    float eta_route_code = 0.05f;
    float lambda_route_code_id = 1.0f;
    int route_target_proposals = 0;
    std::string route_hint_agg = "top1";
    std::string route_delta_mode = "target-only";
    float route_pull_scale = 1.0f;
    float route_push_scale = 1.0f;
    std::string route_candidate_score = "insertion";
    std::string routing_source = "none";
    std::string route_mode = "probe";
    std::string route_refresh = "epoch";

    std::string dataset = "counter";
    std::string input_path;
    std::string csv_path;
};

}  // namespace dle
