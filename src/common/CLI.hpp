#pragma once

#include <iostream>
#include <stdexcept>
#include <string>
#include <unordered_map>

#include "common/Params.hpp"

namespace dle {

using CliArgs = std::unordered_map<std::string, std::string>;

inline CliArgs parse_cli_args(int argc, char** argv) {
    CliArgs args;
    for (int i = 1; i < argc; ++i) {
        std::string token = argv[i];
        if (token == "--help") {
            args["help"] = "1";
            continue;
        }
        if (token.rfind("--", 0) != 0) {
            throw std::runtime_error("expected --key or --key=value, got: " + token);
        }

        token.erase(0, 2);
        const std::size_t eq = token.find('=');
        if (eq != std::string::npos) {
            args[token.substr(0, eq)] = token.substr(eq + 1);
            continue;
        }

        if (i + 1 >= argc) {
            throw std::runtime_error("missing value for --" + token);
        }
        args[token] = argv[++i];
    }
    return args;
}

inline int cli_to_int(const std::string& value, const std::string& key) {
    try {
        return std::stoi(value);
    } catch (const std::exception&) {
        throw std::runtime_error("invalid integer for --" + key + ": " + value);
    }
}

inline float cli_to_float(const std::string& value, const std::string& key) {
    try {
        return std::stof(value);
    } catch (const std::exception&) {
        throw std::runtime_error("invalid float for --" + key + ": " + value);
    }
}

inline void apply_route_quality_candidate_weight_preset(
    V02PreParams& params,
    const std::string& value,
    const std::string& key) {
    if (value == "none" || value == "off") {
        params.route_quality_candidate_weight_preset = "none";
        return;
    }

    if (value != "base" && value != "base-default" &&
        value != "hybrid-safe" && value != "hybrid-m0p25") {
        throw std::runtime_error(
            "route-quality-candidate-weight-preset must be one of: none, base-default, hybrid-safe");
    }

    params.route_quality_candidate_weight_preset =
        (value == "base" || value == "base-default") ? "base-default"
                                                      : "hybrid-safe";
    params.route_quality_diagnostics = 1;
    params.route_quality_feature_set = "value-only";
    params.route_quality_apply = "candidate-weight";
    params.route_quality_score = 1;
    params.route_quality_candidate_weight_beta = 8.0f;
    params.route_quality_candidate_weight_min = 0.5f;
    params.route_quality_candidate_weight_max = 8.0f;
    params.route_quality_candidate_weight_basis =
        params.route_quality_candidate_weight_preset == "base-default" ? "base"
                                                                       : "hybrid";
    params.route_quality_candidate_weight_basis_mix =
        params.route_quality_candidate_weight_preset == "base-default" ? 0.0f
                                                                       : 0.25f;
    params.route_quality_source_normalization = "none";
    params.route_quality_logdet_weight = 0.0f;
    params.route_quality_entropy_weight = 0.0f;
    params.route_quality_vote_margin_weight = 1.0f;
    params.route_quality_top_share_weight = 0.0f;
    params.route_quality_source_credit_weight = 0.0f;
    params.route_quality_edge_credit_weight = 0.0f;
    params.route_quality_channel_weight = 0.0f;

    (void)key;
}

inline void apply_v01_overrides(V01Params& params, const CliArgs& args) {
    for (const auto& [key, value] : args) {
        if (key == "help") {
            continue;
        }
        if (key == "N") {
            params.N = cli_to_int(value, key);
        } else if (key == "S") {
            params.S = cli_to_int(value, key);
        } else if (key == "R") {
            params.R = cli_to_int(value, key);
        } else if (key == "K") {
            params.K = cli_to_int(value, key);
        } else if (key == "C-colors" || key == "colors") {
            params.C_colors = cli_to_int(value, key);
        } else if (key == "cycles") {
            params.cycles = cli_to_int(value, key);
        } else if (key == "seed") {
            params.seed = cli_to_int(value, key);
        } else if (key == "lambda-u") {
            params.lambda_u = cli_to_float(value, key);
        } else if (key == "lambda-v") {
            params.lambda_v = cli_to_float(value, key);
        } else if (key == "lambda-m") {
            params.lambda_m = cli_to_float(value, key);
        } else if (key == "eta-r") {
            params.eta_r = cli_to_float(value, key);
        } else if (key == "eta-tau") {
            params.eta_tau = cli_to_float(value, key);
        } else if (key == "tau-max") {
            params.tau_max = cli_to_float(value, key);
        } else if (key == "tau-decay") {
            params.tau_decay = cli_to_float(value, key);
        } else if (key == "reservoir-decay") {
            params.reservoir_decay = cli_to_float(value, key);
        } else if (key == "T0") {
            params.T0 = cli_to_float(value, key);
        } else if (key == "alpha-T") {
            params.alpha_T = cli_to_float(value, key);
        } else if (key == "eps-T") {
            params.eps_T = cli_to_float(value, key);
        } else if (key == "stagnation-window") {
            params.stagnation_window = cli_to_int(value, key);
        } else if (key == "stagnation-threshold") {
            params.stagnation_threshold = cli_to_int(value, key);
        } else if (key == "proposal-count") {
            params.proposal_count = cli_to_int(value, key);
        } else if (key == "mass-init") {
            params.mass_init = cli_to_float(value, key);
        } else if (key == "csv") {
            params.csv_path = value;
        } else {
            throw std::runtime_error("unknown argument --" + key);
        }
    }
}

inline void apply_v02_overrides(V02PreParams& params, const CliArgs& args) {
    if (const auto it = args.find("route-quality-candidate-weight-preset");
        it != args.end()) {
        apply_route_quality_candidate_weight_preset(params, it->second, it->first);
    } else if (const auto it2 = args.find("route_quality_candidate_weight_preset");
               it2 != args.end()) {
        apply_route_quality_candidate_weight_preset(params, it2->second, it2->first);
    }

    for (const auto& [key, value] : args) {
        if (key == "help") {
            continue;
        }
        if (key == "N") {
            params.N = cli_to_int(value, key);
        } else if (key == "S") {
            params.S = cli_to_int(value, key);
        } else if (key == "channels") {
            params.channels = cli_to_int(value, key);
        } else if (key == "R") {
            params.R = cli_to_int(value, key);
        } else if (key == "K") {
            params.K = cli_to_int(value, key);
        } else if (key == "C-colors" || key == "colors") {
            params.C_colors = cli_to_int(value, key);
        } else if (key == "epochs") {
            params.epochs = cli_to_int(value, key);
        } else if (key == "cycles-per-epoch") {
            params.cycles_per_epoch = cli_to_int(value, key);
        } else if (key == "seed") {
            params.seed = cli_to_int(value, key);
        } else if (key == "lambda-u") {
            params.lambda_u = cli_to_float(value, key);
        } else if (key == "lambda-v") {
            params.lambda_v = cli_to_float(value, key);
        } else if (key == "lambda-b") {
            params.lambda_b = cli_to_float(value, key);
        } else if (key == "lambda-m") {
            params.lambda_m = cli_to_float(value, key);
        } else if (key == "eta-r") {
            params.eta_r = cli_to_float(value, key);
        } else if (key == "eta-tau") {
            params.eta_tau = cli_to_float(value, key);
        } else if (key == "tau-max") {
            params.tau_max = cli_to_float(value, key);
        } else if (key == "tau-decay") {
            params.tau_decay = cli_to_float(value, key);
        } else if (key == "reservoir-decay") {
            params.reservoir_decay = cli_to_float(value, key);
        } else if (key == "T0") {
            params.T0 = cli_to_float(value, key);
        } else if (key == "alpha-T") {
            params.alpha_T = cli_to_float(value, key);
        } else if (key == "eps-T") {
            params.eps_T = cli_to_float(value, key);
        } else if (key == "stagnation-window") {
            params.stagnation_window = cli_to_int(value, key);
        } else if (key == "stagnation-threshold") {
            params.stagnation_threshold = cli_to_int(value, key);
        } else if (key == "proposal-count") {
            params.proposal_count = cli_to_int(value, key);
        } else if (key == "eta-h") {
            params.eta_h = cli_to_float(value, key);
        } else if (key == "eta-b") {
            params.eta_b = cli_to_float(value, key);
        } else if (key == "lambda-h") {
            params.lambda_h = cli_to_float(value, key);
        } else if (key == "H-clip") {
            params.H_clip = cli_to_float(value, key);
        } else if (key == "mass-init") {
            params.mass_init = cli_to_float(value, key);
        } else if (key == "K-jump") {
            params.K_jump = cli_to_int(value, key);
        } else if (key == "route-reservoir-threshold") {
            params.route_reservoir_threshold = cli_to_float(value, key);
        } else if (key == "route-min-anchor-gap") {
            params.route_min_anchor_gap = cli_to_float(value, key);
        } else if (key == "route-adaptive-gap-scale") {
            params.route_adaptive_gap_scale = cli_to_float(value, key);
        } else if (key == "route-confidence-gap-scale") {
            params.route_confidence_gap_scale = cli_to_float(value, key);
        } else if (key == "route_accept_confidence_gain" ||
                   key == "route-accept-confidence-gain") {
            params.route_accept_confidence_gain = cli_to_float(value, key);
        } else if (key == "lambda-route") {
            params.lambda_route = cli_to_float(value, key);
        } else if (key == "route-strength-mode" || key == "route_strength_mode") {
            params.route_strength_mode = value;
        } else if (key == "lambda-route-base" || key == "lambda_route_base") {
            params.lambda_route_base = cli_to_float(value, key);
        } else if (key == "lambda-route-max" || key == "lambda_route_max") {
            params.lambda_route_max = cli_to_float(value, key);
        } else if (key == "route-margin-alpha" || key == "route_margin_alpha") {
            params.route_margin_alpha = cli_to_float(value, key);
        } else if (key == "route-confidence-power" || key == "route_confidence_power") {
            params.route_confidence_power = cli_to_float(value, key);
        } else if (key == "route-min-confidence" || key == "route_min_confidence") {
            params.route_min_confidence = cli_to_float(value, key);
        } else if (key == "route-corrupt-candidate-rate" ||
                   key == "route_corrupt_candidate_rate") {
            params.route_corrupt_candidate_rate = cli_to_float(value, key);
        } else if (key == "route-noisy-source-rate" ||
                   key == "route_noisy_source_rate") {
            params.route_noisy_source_rate = cli_to_float(value, key);
        } else if (key == "route-corrupt-confidence" ||
                   key == "route_corrupt_confidence") {
            params.route_corrupt_confidence = value;
        } else if (key == "route-corrupt-confidence-value" ||
                   key == "route_corrupt_confidence_value") {
            params.route_corrupt_confidence_value = cli_to_float(value, key);
        } else if (key == "route-corrupt-preserve-correct" ||
                   key == "route_corrupt_preserve_correct") {
            params.route_corrupt_preserve_correct = cli_to_int(value, key);
        } else if (key == "route-strength-confidence" ||
                   key == "route_strength_confidence") {
            params.route_strength_confidence = value;
        } else if (key == "route-confidence-threshold" ||
                   key == "route_confidence_threshold") {
            params.route_confidence_threshold = cli_to_float(value, key);
        } else if (key == "route-lowconf-policy" || key == "route_lowconf_policy") {
            params.route_lowconf_policy = value;
        } else if (key == "route-lowconf-weak-scale" ||
                   key == "route_lowconf_weak_scale") {
            params.route_lowconf_weak_scale = cli_to_float(value, key);
        } else if (key == "route-lowconf-agg" || key == "route_lowconf_agg") {
            params.route_lowconf_agg = value;
        } else if (key == "route-highconf-agg" || key == "route_highconf_agg") {
            params.route_highconf_agg = value;
        } else if (key == "route-aggregation-confidence" ||
                   key == "route_aggregation_confidence") {
            params.route_aggregation_confidence = value;
        } else if (key == "route-fallback-source" || key == "route_fallback_source") {
            params.route_fallback_source = value;
        } else if (key == "route-fallback-strength-mode" ||
                   key == "route_fallback_strength_mode") {
            params.route_fallback_strength_mode = value;
        } else if (key == "route-fallback-strength-mult" ||
                   key == "route_fallback_strength_mult") {
            params.route_fallback_strength_mult = cli_to_float(value, key);
        } else if (key == "route-fallback-hi-strength-mult" ||
                   key == "route_fallback_hi_strength_mult") {
            params.route_fallback_hi_strength_mult = cli_to_float(value, key);
        } else if (key == "route-fallback-lo-strength-mult" ||
                   key == "route_fallback_lo_strength_mult") {
            params.route_fallback_lo_strength_mult = cli_to_float(value, key);
        } else if (key == "route-fallback-channel-strength-mode" ||
                   key == "route_fallback_channel_strength_mode") {
            params.route_fallback_channel_strength_mode = value;
        } else if (key == "route-fallback-lambda-base" ||
                   key == "route_fallback_lambda_base") {
            params.route_fallback_lambda_base = cli_to_float(value, key);
        } else if (key == "route-fallback-lambda-max" ||
                   key == "route_fallback_lambda_max") {
            params.route_fallback_lambda_max = cli_to_float(value, key);
        } else if (key == "route-fallback-margin-alpha" ||
                   key == "route_fallback_margin_alpha") {
            params.route_fallback_margin_alpha = cli_to_float(value, key);
        } else if (key == "route-fallback-hi-lambda-base" ||
                   key == "route_fallback_hi_lambda_base") {
            params.route_fallback_hi_lambda_base = cli_to_float(value, key);
        } else if (key == "route-fallback-lo-lambda-base" ||
                   key == "route_fallback_lo_lambda_base") {
            params.route_fallback_lo_lambda_base = cli_to_float(value, key);
        } else if (key == "route-fallback-hi-lambda-max" ||
                   key == "route_fallback_hi_lambda_max" ||
                   key == "route-fallback-hi-max") {
            params.route_fallback_hi_lambda_max = cli_to_float(value, key);
        } else if (key == "route-fallback-lo-lambda-max" ||
                   key == "route_fallback_lo_lambda_max" ||
                   key == "route-fallback-lo-max") {
            params.route_fallback_lo_lambda_max = cli_to_float(value, key);
        } else if (key == "route-fallback-hi-margin-alpha" ||
                   key == "route_fallback_hi_margin_alpha" ||
                   key == "route-fallback-hi-alpha") {
            params.route_fallback_hi_margin_alpha = cli_to_float(value, key);
        } else if (key == "route-fallback-lo-margin-alpha" ||
                   key == "route_fallback_lo_margin_alpha" ||
                   key == "route-fallback-lo-alpha") {
            params.route_fallback_lo_margin_alpha = cli_to_float(value, key);
        } else if (key == "route-fallback-persist-cycles" ||
                   key == "route_fallback_persist_cycles") {
            params.route_fallback_persist_cycles = cli_to_int(value, key);
        } else if (key == "route-credit-learning" || key == "route_credit_learning") {
            params.route_credit_learning = cli_to_int(value, key);
        } else if (key == "route-credit-mode" || key == "route_credit_mode") {
            params.route_credit_mode = value;
        } else if (key == "route-credit-score-weight" ||
                   key == "route_credit_score_weight") {
            params.route_credit_score_weight = cli_to_float(value, key);
        } else if (key == "route-credit-eta-reward" ||
                   key == "route_credit_eta_reward") {
            params.route_credit_eta_reward = cli_to_float(value, key);
        } else if (key == "route-credit-eta-slash" ||
                   key == "route_credit_eta_slash") {
            params.route_credit_eta_slash = cli_to_float(value, key);
        } else if (key == "route-credit-decay" || key == "route_credit_decay") {
            params.route_credit_decay = cli_to_float(value, key);
        } else if (key == "route-credit-clip" || key == "route_credit_clip") {
            params.route_credit_clip = cli_to_float(value, key);
        } else if (key == "route-source-credit-learning" ||
                   key == "route_source_credit_learning") {
            params.route_source_credit_learning = cli_to_int(value, key);
        } else if (key == "route-source-credit-apply-mode" ||
                   key == "route_source_credit_apply_mode") {
            params.route_source_credit_apply_mode = value;
        } else if (key == "route-source-credit-score-weight" ||
                   key == "route_source_credit_score_weight") {
            params.route_source_credit_score_weight = cli_to_float(value, key);
        } else if (key == "route-source-credit-eta-reward" ||
                   key == "route_source_credit_eta_reward") {
            params.route_source_credit_eta_reward = cli_to_float(value, key);
        } else if (key == "route-source-credit-eta-slash" ||
                   key == "route_source_credit_eta_slash") {
            params.route_source_credit_eta_slash = cli_to_float(value, key);
        } else if (key == "route-source-credit-decay" ||
                   key == "route_source_credit_decay") {
            params.route_source_credit_decay = cli_to_float(value, key);
        } else if (key == "route-source-credit-clip" ||
                   key == "route_source_credit_clip") {
            params.route_source_credit_clip = cli_to_float(value, key);
        } else if (key == "route-source-filter-mode" ||
                   key == "route_source_filter_mode") {
            params.route_source_filter_mode = value;
        } else if (key == "route-source-filter-threshold" ||
                   key == "route_source_filter_threshold") {
            params.route_source_filter_threshold = cli_to_float(value, key);
        } else if (key == "route-source-retry-source" ||
                   key == "route_source_retry_source") {
            params.route_source_retry_source = value;
        } else if (key == "route-source-retry-policy" ||
                   key == "route_source_retry_policy") {
            params.route_source_retry_policy = value;
        } else if (key == "route-source-retry-tiebreak" ||
                   key == "route_source_retry_tiebreak") {
            params.route_source_retry_tiebreak = value;
        } else if (key == "route-source-retry-priorities" ||
                   key == "route_source_retry_priorities") {
            params.route_source_retry_priorities = value;
        } else if (key == "route-source-retry-prior-mode" ||
                   key == "route_source_retry_prior_mode") {
            params.route_source_retry_prior_mode = value;
        } else if (key == "route-source-retry-prior-decay" ||
                   key == "route_source_retry_prior_decay") {
            params.route_source_retry_prior_decay = cli_to_float(value, key);
        } else if (key == "route-source-retry-prior-warmup-epochs" ||
                   key == "route_source_retry_prior_warmup_epochs") {
            params.route_source_retry_prior_warmup_epochs = cli_to_int(value, key);
        } else if (key == "route-source-retry-candidates" ||
                   key == "route_source_retry_candidates") {
            params.route_source_retry_candidates = value;
        } else if (key == "route-source-retry-per-source-limit" ||
                   key == "route_source_retry_per_source_limit") {
            params.route_source_retry_per_source_limit = cli_to_int(value, key);
        } else if (key == "route-quality-diagnostics" ||
                   key == "route_quality_diagnostics") {
            params.route_quality_diagnostics = cli_to_int(value, key);
        } else if (key == "route-quality-feature-set" ||
                   key == "route_quality_feature_set") {
            params.route_quality_feature_set = value;
        } else if (key == "route-quality-apply" || key == "route_quality_apply") {
            params.route_quality_apply = value;
        } else if (key == "route-quality-eps" || key == "route_quality_eps") {
            params.route_quality_eps = cli_to_float(value, key);
        } else if (key == "route-channel-tension-diagnostics" ||
                   key == "route_channel_tension_diagnostics") {
            params.route_channel_tension_diagnostics = cli_to_int(value, key);
        } else if (key == "route-channel-tension-mode" ||
                   key == "route_channel_tension_mode") {
            params.route_channel_tension_mode = value;
        } else if (key == "route-quality-score" || key == "route_quality_score") {
            params.route_quality_score = cli_to_int(value, key);
        } else if (key == "route-quality-source-ranking-beta" ||
                   key == "route_quality_source_ranking_beta") {
            params.route_quality_source_ranking_beta = cli_to_float(value, key);
        } else if (key == "route-quality-candidate-weight-beta" ||
                   key == "route_quality_candidate_weight_beta") {
            params.route_quality_candidate_weight_beta = cli_to_float(value, key);
        } else if (key == "route-quality-candidate-weight-min" ||
                   key == "route_quality_candidate_weight_min") {
            params.route_quality_candidate_weight_min = cli_to_float(value, key);
        } else if (key == "route-quality-candidate-weight-max" ||
                   key == "route_quality_candidate_weight_max") {
            params.route_quality_candidate_weight_max = cli_to_float(value, key);
        } else if (key == "route-quality-candidate-weight-preset" ||
                   key == "route_quality_candidate_weight_preset") {
            params.route_quality_candidate_weight_preset = value;
        } else if (key == "route-quality-candidate-weight-basis" ||
                   key == "route_quality_candidate_weight_basis") {
            params.route_quality_candidate_weight_basis = value;
        } else if (key == "route-quality-candidate-weight-basis-mix" ||
                   key == "route_quality_candidate_weight_basis_mix") {
            params.route_quality_candidate_weight_basis_mix = cli_to_float(value, key);
        } else if (key == "route-quality-candidate-weight-auto-factor-max" ||
                   key == "route_quality_candidate_weight_auto_factor_max") {
            params.route_quality_candidate_weight_auto_factor_max =
                cli_to_float(value, key);
        } else if (key == "route-quality-candidate-weight-auto-top-share" ||
                   key == "route_quality_candidate_weight_auto_top_share") {
            params.route_quality_candidate_weight_auto_top_share =
                cli_to_float(value, key);
        } else if (key == "route-quality-candidate-weight-auto-trigger-mode" ||
                   key == "route_quality_candidate_weight_auto_trigger_mode") {
            params.route_quality_candidate_weight_auto_trigger_mode = value;
        } else if (key == "route-quality-source-normalization" ||
                   key == "route_quality_source_normalization") {
            params.route_quality_source_normalization = value;
        } else if (key == "route-quality-source-norm-eps" ||
                   key == "route_quality_source_norm_eps") {
            params.route_quality_source_norm_eps = cli_to_float(value, key);
        } else if (key == "route-quality-logdet-weight" ||
                   key == "route_quality_logdet_weight") {
            params.route_quality_logdet_weight = cli_to_float(value, key);
        } else if (key == "route-quality-entropy-weight" ||
                   key == "route_quality_entropy_weight") {
            params.route_quality_entropy_weight = cli_to_float(value, key);
        } else if (key == "route-quality-vote-margin-weight" ||
                   key == "route_quality_vote_margin_weight") {
            params.route_quality_vote_margin_weight = cli_to_float(value, key);
        } else if (key == "route-quality-top-share-weight" ||
                   key == "route_quality_top_share_weight") {
            params.route_quality_top_share_weight = cli_to_float(value, key);
        } else if (key == "route-quality-source-credit-weight" ||
                   key == "route_quality_source_credit_weight") {
            params.route_quality_source_credit_weight = cli_to_float(value, key);
        } else if (key == "route-quality-edge-credit-weight" ||
                   key == "route_quality_edge_credit_weight") {
            params.route_quality_edge_credit_weight = cli_to_float(value, key);
        } else if (key == "route-quality-channel-weight" ||
                   key == "route_quality_channel_weight") {
            params.route_quality_channel_weight = cli_to_float(value, key);
        } else if (key == "route-plasticity-ledger" ||
                   key == "route_plasticity_ledger") {
            params.route_plasticity_ledger = cli_to_int(value, key);
        } else if (key == "route-plasticity-ledger-decay" ||
                   key == "route_plasticity_ledger_decay") {
            params.route_plasticity_ledger_decay = cli_to_float(value, key);
        } else if (key == "route-credit-learn-after-epoch" ||
                   key == "route_credit_learn_after_epoch") {
            params.route_credit_learn_after_epoch = cli_to_int(value, key);
        } else if (key == "route-credit-apply-after-epoch" ||
                   key == "route_credit_apply_after_epoch") {
            params.route_credit_apply_after_epoch = cli_to_int(value, key);
        } else if (key == "K-route" || key == "K_route") {
            params.K_route = cli_to_int(value, key);
        } else if (key == "route-hash-bits" || key == "route_hash_bits") {
            params.route_hash_bits = cli_to_int(value, key);
        } else if (key == "route-hash-source" || key == "route_hash_source") {
            params.route_hash_source = value;
        } else if (key == "route-code-aux" || key == "route_code_aux") {
            params.route_code_aux = cli_to_int(value, key);
        } else if (key == "route-code-key-region-only" ||
                   key == "route_code_key_region_only") {
            params.route_code_key_region_only = cli_to_int(value, key);
        } else if (key == "route-code-key-region-keep-prob" ||
                   key == "route_code_key_region_keep_prob") {
            params.route_code_key_region_keep_prob = cli_to_float(value, key);
        } else if (key == "route-code-aux-noise-rate" ||
                   key == "route_code_aux_noise_rate") {
            params.route_code_aux_noise_rate = cli_to_float(value, key);
        } else if (key == "eta-route-code" || key == "eta_route_code") {
            params.eta_route_code = cli_to_float(value, key);
        } else if (key == "lambda-route-code-id" || key == "lambda_route_code_id") {
            params.lambda_route_code_id = cli_to_float(value, key);
        } else if (key == "route-target-proposals" || key == "route_target_proposals") {
            params.route_target_proposals = cli_to_int(value, key);
        } else if (key == "route-hint-agg" || key == "route_hint_agg") {
            params.route_hint_agg = value;
        } else if (key == "route-delta-mode" || key == "route_delta_mode") {
            params.route_delta_mode = value;
        } else if (key == "route-pull-scale" || key == "route_pull_scale") {
            params.route_pull_scale = cli_to_float(value, key);
        } else if (key == "route-push-scale" || key == "route_push_scale") {
            params.route_push_scale = cli_to_float(value, key);
        } else if (key == "route-candidate-score" || key == "route_candidate_score") {
            params.route_candidate_score = value;
        } else if (key == "route-source") {
            params.routing_source = value;
        } else if (key == "route-mode") {
            params.route_mode = value;
        } else if (key == "route-refresh" || key == "route_refresh") {
            params.route_refresh = value;
        } else if (key == "dataset") {
            params.dataset = value;
        } else if (key == "input") {
            params.input_path = value;
        } else if (key == "csv") {
            params.csv_path = value;
        } else {
            throw std::runtime_error("unknown argument --" + key);
        }
    }
}

inline void print_v01_help(std::ostream& os) {
    os << "dmv01 options:\n"
       << "  --N <int>\n"
       << "  --S <int>\n"
       << "  --R <int>\n"
       << "  --K <int>\n"
       << "  --C-colors <int>\n"
       << "  --cycles <int>\n"
       << "  --seed <int>\n"
       << "  --lambda-u <float>\n"
       << "  --lambda-v <float>\n"
       << "  --lambda-m <float>\n"
       << "  --eta-r <float>\n"
       << "  --eta-tau <float>\n"
       << "  --tau-max <float>\n"
       << "  --tau-decay <float>\n"
       << "  --reservoir-decay <float>\n"
       << "  --T0 <float>\n"
       << "  --alpha-T <float>\n"
       << "  --eps-T <float>\n"
       << "  --stagnation-window <int>\n"
       << "  --stagnation-threshold <int>\n"
       << "  --proposal-count <int>\n"
       << "  --mass-init <float>\n"
       << "  --csv <path>\n";
}

inline void print_v02_help(std::ostream& os) {
    os << "dmv02 options:\n"
       << "  --dataset <name>\n"
       << "  --input <path>\n"
       << "  --N <int>\n"
       << "  --S <int>\n"
       << "  --channels <int>\n"
       << "  --R <int>\n"
       << "  --K <int>\n"
       << "  --C-colors <int>\n"
       << "  --epochs <int>\n"
       << "  --cycles-per-epoch <int>\n"
       << "  --seed <int>\n"
       << "  --lambda-u <float>\n"
       << "  --lambda-v <float>\n"
       << "  --lambda-b <float>\n"
       << "  --lambda-m <float>\n"
       << "  --eta-r <float>\n"
       << "  --eta-tau <float>\n"
       << "  --tau-max <float>\n"
       << "  --tau-decay <float>\n"
       << "  --reservoir-decay <float>\n"
       << "  --T0 <float>\n"
       << "  --alpha-T <float>\n"
       << "  --eps-T <float>\n"
       << "  --stagnation-window <int>\n"
       << "  --stagnation-threshold <int>\n"
       << "  --proposal-count <int>\n"
       << "  --eta-h <float>\n"
       << "  --eta-b <float>\n"
       << "  --lambda-h <float>\n"
       << "  --H-clip <float>\n"
       << "  --mass-init <float>\n"
       << "  --K-jump <int>\n"
       << "  --route-reservoir-threshold <float>\n"
       << "  --route-min-anchor-gap <float>\n"
       << "  --route-adaptive-gap-scale <float>\n"
       << "  --route-confidence-gap-scale <float>\n"
       << "  --route-accept-confidence-gain <float>\n"
       << "  --lambda-route <float>\n"
       << "  --route-strength-mode <fixed|margin>\n"
       << "  --lambda-route-base <float>\n"
       << "  --lambda-route-max <float>\n"
       << "  --route-margin-alpha <float>\n"
       << "  --route-confidence-power <float>\n"
       << "  --route-min-confidence <float>\n"
       << "  --route-corrupt-candidate-rate <float>\n"
       << "  --route-corrupt-confidence <keep|low>\n"
       << "  --route-corrupt-confidence-value <float>\n"
       << "  --route-corrupt-preserve-correct <0|1>\n"
       << "  --route-strength-confidence <weight|value-support|agreement>\n"
       << "  --route-confidence-threshold <float>\n"
       << "  --route-lowconf-policy <aggregate|none|weak-vote>\n"
       << "  --route-lowconf-weak-scale <float>\n"
       << "  --route-lowconf-agg <top1|vote|weighted-vote>\n"
       << "  --route-highconf-agg <top1|vote|weighted-vote>\n"
       << "  --route-aggregation-confidence <value-support|agreement>\n"
       << "  --route-fallback-source <off|raw-key|key-shape|joint-code-key|noisy-route-code>\n"
       << "  --route-noisy-source-rate <float>\n"
       << "  --route-fallback-strength-mode <fixed|margin>\n"
       << "  --route-fallback-strength-mult <float>\n"
       << "  --route-fallback-hi-strength-mult <float>\n"
       << "  --route-fallback-lo-strength-mult <float>\n"
       << "  --route-fallback-channel-strength-mode <fixed|margin>\n"
       << "  --route-fallback-lambda-base <float>\n"
       << "  --route-fallback-lambda-max <float>\n"
       << "  --route-fallback-margin-alpha <float>\n"
       << "  --route-fallback-hi-lambda-base <float>\n"
       << "  --route-fallback-lo-lambda-base <float>\n"
       << "  --route-fallback-hi-lambda-max <float>\n"
       << "  --route-fallback-lo-lambda-max <float>\n"
       << "  --route-fallback-hi-margin-alpha <float>\n"
       << "  --route-fallback-lo-margin-alpha <float>\n"
       << "  --route-fallback-persist-cycles <int>\n"
       << "  --route-credit-learning <0|1>\n"
       << "  --route-credit-mode <off|value-pos|query-value>\n"
       << "  --route-credit-score-weight <float>\n"
       << "  --route-credit-eta-reward <float>\n"
       << "  --route-credit-eta-slash <float>\n"
       << "  --route-credit-decay <float>\n"
       << "  --route-credit-clip <float>\n"
       << "  --route-source-credit-learning <0|1>\n"
       << "  --route-source-credit-apply-mode <off|ranking|strength|ranking-strength>\n"
       << "  --route-source-credit-score-weight <float>\n"
       << "  --route-source-credit-eta-reward <float>\n"
       << "  --route-source-credit-eta-slash <float>\n"
       << "  --route-source-credit-decay <float>\n"
       << "  --route-source-credit-clip <float>\n"
       << "  --route-source-filter-mode <off|negative-credit>\n"
       << "  --route-source-filter-threshold <float>\n"
       << "  --route-source-retry-source <off|raw-key|key-shape|joint-code-key|noisy-route-code>\n"
       << "  --route-source-retry-policy <fixed|source-credit>\n"
       << "  --route-source-retry-tiebreak <source-order|source-prior>\n"
       << "  --route-source-retry-priorities <csv source:prior>\n"
       << "  --route-source-retry-prior-mode <none|static|decay|warmup>\n"
       << "  --route-source-retry-prior-decay <float>\n"
       << "  --route-source-retry-prior-warmup-epochs <int>\n"
       << "  --route-source-retry-candidates <csv of raw-key|key-shape|joint-code-key|noisy-route-code>\n"
       << "  --route-source-retry-per-source-limit <int>\n"
       << "  --route-quality-diagnostics <0|1>\n"
       << "  --route-quality-feature-set <value-only> (dynamics/full planned)\n"
       << "  --route-quality-apply <none|candidate-weight|source-ranking|source-candidate|strength>\n"
       << "  --route-quality-eps <float>\n"
       << "  --route-channel-tension-diagnostics <0|1>\n"
       << "  --route-channel-tension-mode <margin>\n"
       << "  --route-quality-score <0|1>\n"
       << "  --route-quality-source-ranking-beta <float>\n"
       << "  --route-quality-candidate-weight-beta <float>\n"
       << "  --route-quality-candidate-weight-min <float>\n"
       << "  --route-quality-candidate-weight-max <float>\n"
       << "  --route-quality-candidate-weight-preset <none|base-default|hybrid-safe>\n"
       << "  --route-quality-candidate-weight-basis <base|quality-score|hybrid|auto>\n"
       << "  --route-quality-candidate-weight-basis-mix <float>\n"
       << "  --route-quality-candidate-weight-auto-factor-max <float>\n"
       << "  --route-quality-candidate-weight-auto-top-share <float>\n"
       << "  --route-quality-candidate-weight-auto-trigger-mode <any|factor|top-share>\n"
       << "  --route-quality-source-normalization <none|center|zscore>\n"
       << "  --route-quality-source-norm-eps <float>\n"
       << "  --route-quality-logdet-weight <float>\n"
       << "  --route-quality-entropy-weight <float>\n"
       << "  --route-quality-vote-margin-weight <float>\n"
       << "  --route-quality-top-share-weight <float>\n"
       << "  --route-quality-source-credit-weight <float>\n"
       << "  --route-quality-edge-credit-weight <float>\n"
       << "  --route-quality-channel-weight <float>\n"
       << "  --route-plasticity-ledger <0|1>\n"
       << "  --route-plasticity-ledger-decay <float>\n"
       << "  --route-credit-learn-after-epoch <int>\n"
       << "  --route-credit-apply-after-epoch <int>\n"
       << "  --K-route <int>\n"
       << "  --route-hash-bits <int>\n"
       << "  --route-hash-source <raw-key|joint-code-key|route-code-key>\n"
       << "  --route-code-aux <0|1>\n"
       << "  --route-code-key-region-only <0|1>\n"
       << "  --route-code-key-region-keep-prob <float>\n"
       << "  --route-code-aux-noise-rate <float>\n"
       << "  --eta-route-code <float>\n"
       << "  --lambda-route-code-id <float>\n"
       << "  --route-target-proposals <0|1>\n"
       << "  --route-hint-agg <top1|vote|weighted-vote|confidence-gated>\n"
       << "  --route-delta-mode <target-only|projected>\n"
       << "  --route-pull-scale <float>\n"
       << "  --route-push-scale <float>\n"
       << "  --route-candidate-score <insertion|recency|value-vote|key-shape>\n"
       << "  --route-source <none|input-byte|joint-code|state-code>\n"
       << "  --route-mode <off|probe|jump-neighbors|hint-oracle|hint-parsed|hint-kv-exact|hint-kv-hash>\n"
       << "     jump-neighbors may use input-byte, joint-code, or state-code route keys\n"
       << "  --route-refresh <epoch|cycle>\n"
       << "  --csv <path>\n";
}

}  // namespace dle
