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
        } else if (key == "eta-route-code" || key == "eta_route_code") {
            params.eta_route_code = cli_to_float(value, key);
        } else if (key == "lambda-route-code-id" || key == "lambda_route_code_id") {
            params.lambda_route_code_id = cli_to_float(value, key);
        } else if (key == "route-target-proposals" || key == "route_target_proposals") {
            params.route_target_proposals = cli_to_int(value, key);
        } else if (key == "route-hint-agg" || key == "route_hint_agg") {
            params.route_hint_agg = value;
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
       << "  --K-route <int>\n"
       << "  --route-hash-bits <int>\n"
       << "  --route-hash-source <raw-key|joint-code-key|route-code-key>\n"
       << "  --route-code-aux <0|1>\n"
       << "  --route-code-key-region-only <0|1>\n"
       << "  --eta-route-code <float>\n"
       << "  --lambda-route-code-id <float>\n"
       << "  --route-target-proposals <0|1>\n"
       << "  --route-hint-agg <top1|vote|weighted-vote|confidence-gated>\n"
       << "  --route-candidate-score <insertion|recency|value-vote|key-shape>\n"
       << "  --route-source <none|input-byte|joint-code|state-code>\n"
       << "  --route-mode <off|probe|jump-neighbors|hint-oracle|hint-parsed|hint-kv-exact|hint-kv-hash>\n"
       << "     jump-neighbors may use input-byte, joint-code, or state-code route keys\n"
       << "  --route-refresh <epoch|cycle>\n"
       << "  --csv <path>\n";
}

}  // namespace dle
