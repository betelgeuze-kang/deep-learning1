#pragma once

#include <string>

namespace dle {

struct V02ExperimentConfigView;
struct V02EnergyConfigView;
struct V02RouteConfigView;
struct V02FallbackConfigView;
struct V02CreditConfigView;
struct V02QualityConfigView;

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
    float route_quality_source_ranking_beta = 0.10f;
    float route_quality_candidate_weight_beta = 0.25f;
    float route_quality_candidate_weight_min = 0.5f;
    float route_quality_candidate_weight_max = 2.0f;
    std::string route_quality_candidate_weight_preset = "none";
    std::string route_quality_candidate_weight_basis = "base";
    float route_quality_candidate_weight_basis_mix = 0.25f;
    float route_quality_candidate_weight_auto_factor_max = 6.0f;
    float route_quality_candidate_weight_auto_top_share = 0.72f;
    std::string route_quality_candidate_weight_auto_trigger_mode = "any";
    std::string route_quality_source_normalization = "none";
    float route_quality_source_norm_eps = 1e-6f;
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
    int route_span_hints = 0;
    std::string route_hint_agg = "top1";
    std::string route_delta_mode = "target-only";
    float route_pull_scale = 1.0f;
    float route_push_scale = 1.0f;
    std::string route_candidate_score = "insertion";
    std::string routing_source = "none";
    std::string route_mode = "probe";
    std::string route_refresh = "epoch";

    std::string backend = "cpu";
    int hip_device = 0;

    std::string dataset = "counter";
    std::string input_path;
    std::string csv_path;

    V02ExperimentConfigView experiment() const;
    V02EnergyConfigView energy() const;
    V02RouteConfigView route() const;
    V02FallbackConfigView fallback() const;
    V02CreditConfigView credit() const;
    V02QualityConfigView quality() const;
};

struct V02ExperimentConfigView {
    const V02PreParams& params;

    int n() const { return params.N; }
    int states() const { return params.S; }
    int channels() const { return params.channels; }
    int radius() const { return params.R; }
    int neighbor_count() const { return params.K; }
    int color_count() const { return params.C_colors; }
    int epochs() const { return params.epochs; }
    int cycles_per_epoch() const { return params.cycles_per_epoch; }
    int seed() const { return params.seed; }
    const std::string& backend() const { return params.backend; }
    int hip_device() const { return params.hip_device; }
    const std::string& dataset() const { return params.dataset; }
    const std::string& input_path() const { return params.input_path; }
    const std::string& csv_path() const { return params.csv_path; }
};

struct V02EnergyConfigView {
    const V02PreParams& params;

    float lambda_v() const { return params.lambda_v; }
    float lambda_u() const { return params.lambda_u; }
    float lambda_b() const { return params.lambda_b; }
    float lambda_m() const { return params.lambda_m; }
    float eta_r() const { return params.eta_r; }
    float eta_tau() const { return params.eta_tau; }
    float tau_max() const { return params.tau_max; }
    float tau_decay() const { return params.tau_decay; }
    float reservoir_decay() const { return params.reservoir_decay; }
    float t0() const { return params.T0; }
    float alpha_t() const { return params.alpha_T; }
    float eps_t() const { return params.eps_T; }
    int stagnation_window() const { return params.stagnation_window; }
    int stagnation_threshold() const { return params.stagnation_threshold; }
    int proposal_count() const { return params.proposal_count; }
    float eta_h() const { return params.eta_h; }
    float eta_b() const { return params.eta_b; }
    float lambda_h() const { return params.lambda_h; }
    float h_clip() const { return params.H_clip; }
    float mass_init() const { return params.mass_init; }
};

struct V02RouteConfigView {
    const V02PreParams& params;

    int jump_neighbor_count() const { return params.K_jump; }
    float reservoir_threshold() const { return params.route_reservoir_threshold; }
    float min_anchor_gap() const { return params.route_min_anchor_gap; }
    float adaptive_gap_scale() const { return params.route_adaptive_gap_scale; }
    float confidence_gap_scale() const { return params.route_confidence_gap_scale; }
    float accept_confidence_gain() const { return params.route_accept_confidence_gain; }
    float lambda() const { return params.lambda_route; }
    const std::string& strength_mode() const { return params.route_strength_mode; }
    float lambda_base() const { return params.lambda_route_base; }
    float lambda_max() const { return params.lambda_route_max; }
    float margin_alpha() const { return params.route_margin_alpha; }
    float confidence_power() const { return params.route_confidence_power; }
    float min_confidence() const { return params.route_min_confidence; }
    const std::string& strength_confidence() const { return params.route_strength_confidence; }
    float confidence_threshold() const { return params.route_confidence_threshold; }
    const std::string& lowconf_policy() const { return params.route_lowconf_policy; }
    float lowconf_weak_scale() const { return params.route_lowconf_weak_scale; }
    const std::string& lowconf_agg() const { return params.route_lowconf_agg; }
    const std::string& highconf_agg() const { return params.route_highconf_agg; }
    const std::string& aggregation_confidence() const {
        return params.route_aggregation_confidence;
    }
    int route_count() const { return params.K_route; }
    int hash_bits() const { return params.route_hash_bits; }
    const std::string& hash_source() const { return params.route_hash_source; }
    int code_aux() const { return params.route_code_aux; }
    int code_key_region_only() const { return params.route_code_key_region_only; }
    float code_key_region_keep_prob() const {
        return params.route_code_key_region_keep_prob;
    }
    float code_aux_noise_rate() const { return params.route_code_aux_noise_rate; }
    float eta_code() const { return params.eta_route_code; }
    float lambda_code_id() const { return params.lambda_route_code_id; }
    int target_proposals() const { return params.route_target_proposals; }
    int span_hints() const { return params.route_span_hints; }
    const std::string& hint_agg() const { return params.route_hint_agg; }
    const std::string& delta_mode() const { return params.route_delta_mode; }
    float pull_scale() const { return params.route_pull_scale; }
    float push_scale() const { return params.route_push_scale; }
    const std::string& candidate_score() const { return params.route_candidate_score; }
    const std::string& routing_source() const { return params.routing_source; }
    const std::string& mode() const { return params.route_mode; }
    const std::string& refresh() const { return params.route_refresh; }
};

struct V02FallbackConfigView {
    const V02PreParams& params;

    float corrupt_candidate_rate() const { return params.route_corrupt_candidate_rate; }
    float noisy_source_rate() const { return params.route_noisy_source_rate; }
    const std::string& corrupt_confidence() const { return params.route_corrupt_confidence; }
    float corrupt_confidence_value() const { return params.route_corrupt_confidence_value; }
    int corrupt_preserve_correct() const { return params.route_corrupt_preserve_correct; }
    const std::string& source() const { return params.route_fallback_source; }
    const std::string& strength_mode() const { return params.route_fallback_strength_mode; }
    float strength_mult() const { return params.route_fallback_strength_mult; }
    float hi_strength_mult() const { return params.route_fallback_hi_strength_mult; }
    float lo_strength_mult() const { return params.route_fallback_lo_strength_mult; }
    const std::string& channel_strength_mode() const {
        return params.route_fallback_channel_strength_mode;
    }
    float lambda_base() const { return params.route_fallback_lambda_base; }
    float lambda_max() const { return params.route_fallback_lambda_max; }
    float margin_alpha() const { return params.route_fallback_margin_alpha; }
    float hi_lambda_base() const { return params.route_fallback_hi_lambda_base; }
    float lo_lambda_base() const { return params.route_fallback_lo_lambda_base; }
    float hi_lambda_max() const { return params.route_fallback_hi_lambda_max; }
    float lo_lambda_max() const { return params.route_fallback_lo_lambda_max; }
    float hi_margin_alpha() const { return params.route_fallback_hi_margin_alpha; }
    float lo_margin_alpha() const { return params.route_fallback_lo_margin_alpha; }
    int persist_cycles() const { return params.route_fallback_persist_cycles; }
};

struct V02CreditConfigView {
    const V02PreParams& params;

    int learning() const { return params.route_credit_learning; }
    const std::string& mode() const { return params.route_credit_mode; }
    float score_weight() const { return params.route_credit_score_weight; }
    float eta_reward() const { return params.route_credit_eta_reward; }
    float eta_slash() const { return params.route_credit_eta_slash; }
    float decay() const { return params.route_credit_decay; }
    float clip() const { return params.route_credit_clip; }
    int learn_after_epoch() const { return params.route_credit_learn_after_epoch; }
    int apply_after_epoch() const { return params.route_credit_apply_after_epoch; }
    int source_learning() const { return params.route_source_credit_learning; }
    const std::string& source_apply_mode() const {
        return params.route_source_credit_apply_mode;
    }
    float source_score_weight() const { return params.route_source_credit_score_weight; }
    float source_eta_reward() const { return params.route_source_credit_eta_reward; }
    float source_eta_slash() const { return params.route_source_credit_eta_slash; }
    float source_decay() const { return params.route_source_credit_decay; }
    float source_clip() const { return params.route_source_credit_clip; }
    const std::string& source_filter_mode() const { return params.route_source_filter_mode; }
    float source_filter_threshold() const { return params.route_source_filter_threshold; }
    const std::string& retry_source() const { return params.route_source_retry_source; }
    const std::string& retry_policy() const { return params.route_source_retry_policy; }
    const std::string& retry_tiebreak() const { return params.route_source_retry_tiebreak; }
    const std::string& retry_priorities() const {
        return params.route_source_retry_priorities;
    }
    const std::string& retry_prior_mode() const {
        return params.route_source_retry_prior_mode;
    }
    float retry_prior_decay() const { return params.route_source_retry_prior_decay; }
    int retry_prior_warmup_epochs() const {
        return params.route_source_retry_prior_warmup_epochs;
    }
    const std::string& retry_candidates() const {
        return params.route_source_retry_candidates;
    }
    int retry_per_source_limit() const { return params.route_source_retry_per_source_limit; }
    int plasticity_ledger() const { return params.route_plasticity_ledger; }
    float plasticity_ledger_decay() const { return params.route_plasticity_ledger_decay; }
};

struct V02QualityConfigView {
    const V02PreParams& params;

    int diagnostics() const { return params.route_quality_diagnostics; }
    const std::string& feature_set() const { return params.route_quality_feature_set; }
    const std::string& apply() const { return params.route_quality_apply; }
    float eps() const { return params.route_quality_eps; }
    int channel_tension_diagnostics() const {
        return params.route_channel_tension_diagnostics;
    }
    const std::string& channel_tension_mode() const {
        return params.route_channel_tension_mode;
    }
    int score() const { return params.route_quality_score; }
    float source_ranking_beta() const { return params.route_quality_source_ranking_beta; }
    float candidate_weight_beta() const {
        return params.route_quality_candidate_weight_beta;
    }
    float candidate_weight_min() const { return params.route_quality_candidate_weight_min; }
    float candidate_weight_max() const { return params.route_quality_candidate_weight_max; }
    const std::string& candidate_weight_preset() const {
        return params.route_quality_candidate_weight_preset;
    }
    const std::string& candidate_weight_basis() const {
        return params.route_quality_candidate_weight_basis;
    }
    float candidate_weight_basis_mix() const {
        return params.route_quality_candidate_weight_basis_mix;
    }
    float candidate_weight_auto_factor_max() const {
        return params.route_quality_candidate_weight_auto_factor_max;
    }
    float candidate_weight_auto_top_share() const {
        return params.route_quality_candidate_weight_auto_top_share;
    }
    const std::string& candidate_weight_auto_trigger_mode() const {
        return params.route_quality_candidate_weight_auto_trigger_mode;
    }
    const std::string& source_normalization() const {
        return params.route_quality_source_normalization;
    }
    float source_norm_eps() const { return params.route_quality_source_norm_eps; }
    float logdet_weight() const { return params.route_quality_logdet_weight; }
    float entropy_weight() const { return params.route_quality_entropy_weight; }
    float vote_margin_weight() const { return params.route_quality_vote_margin_weight; }
    float top_share_weight() const { return params.route_quality_top_share_weight; }
    float source_credit_weight() const { return params.route_quality_source_credit_weight; }
    float edge_credit_weight() const { return params.route_quality_edge_credit_weight; }
    float channel_weight() const { return params.route_quality_channel_weight; }
};

inline V02ExperimentConfigView V02PreParams::experiment() const {
    return {*this};
}

inline V02EnergyConfigView V02PreParams::energy() const {
    return {*this};
}

inline V02RouteConfigView V02PreParams::route() const {
    return {*this};
}

inline V02FallbackConfigView V02PreParams::fallback() const {
    return {*this};
}

inline V02CreditConfigView V02PreParams::credit() const {
    return {*this};
}

inline V02QualityConfigView V02PreParams::quality() const {
    return {*this};
}

}  // namespace dle
