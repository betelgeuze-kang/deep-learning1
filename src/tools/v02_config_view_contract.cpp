#include "common/Params.hpp"

#include <stdexcept>
#include <string>
#include <type_traits>

namespace {

template <typename L, typename R>
void require_equal(const L& lhs, const R& rhs, const std::string& message) {
    if (!(lhs == rhs)) {
        throw std::runtime_error(message);
    }
}

}  // namespace

int main() {
    using namespace dle;

    static_assert(
        sizeof(V02ExperimentConfigView) == sizeof(const V02PreParams*),
        "typed config views must be pointer-sized");
    static_assert(
        sizeof(V02EnergyConfigView) == sizeof(const V02PreParams*),
        "typed config views must be pointer-sized");
    static_assert(
        sizeof(V02RouteConfigView) == sizeof(const V02PreParams*),
        "typed config views must be pointer-sized");
    static_assert(
        sizeof(V02FallbackConfigView) == sizeof(const V02PreParams*),
        "typed config views must be pointer-sized");
    static_assert(
        sizeof(V02CreditConfigView) == sizeof(const V02PreParams*),
        "typed config views must be pointer-sized");
    static_assert(
        sizeof(V02QualityConfigView) == sizeof(const V02PreParams*),
        "typed config views must be pointer-sized");

    static_assert(
        std::is_trivially_copyable<V02ExperimentConfigView>::value,
        "typed config views should remain cheap value facades");
    static_assert(
        std::is_trivially_copyable<V02EnergyConfigView>::value,
        "typed config views should remain cheap value facades");

    V02PreParams params;
    params.N = 64;
    params.S = 16;
    params.channels = 2;
    params.R = 3;
    params.K = 6;
    params.C_colors = 7;
    params.epochs = 5;
    params.cycles_per_epoch = 9;
    params.seed = 42;
    params.backend = "cpu";
    params.dataset = "counter";
    params.input_path = "fixtures/input.bin";
    params.csv_path = "results/out.csv";
    params.lambda_u = 1.25f;
    params.lambda_v = 0.5f;
    params.route_strength_mode = "adaptive";
    params.route_hint_agg = "weighted-vote";
    params.route_refresh = "cycle";
    params.route_fallback_source = "key-shape";
    params.route_credit_learning = 1;
    params.route_source_retry_candidates = "raw-key,key-shape,noisy";
    params.route_quality_candidate_weight_beta = 0.75f;
    params.route_quality_source_normalization = "zscore";

    const auto experiment = params.experiment();
    const auto energy = params.energy();
    const auto route = params.route();
    const auto fallback = params.fallback();
    const auto credit = params.credit();
    const auto quality = params.quality();

    require_equal(experiment.n(), params.N, "experiment view lost N");
    require_equal(experiment.states(), params.S, "experiment view lost S");
    require_equal(experiment.channels(), params.channels, "experiment view lost channels");
    require_equal(experiment.radius(), params.R, "experiment view lost R");
    require_equal(experiment.neighbor_count(), params.K, "experiment view lost K");
    require_equal(experiment.color_count(), params.C_colors, "experiment view lost C_colors");
    require_equal(experiment.epochs(), params.epochs, "experiment view lost epochs");
    require_equal(
        experiment.cycles_per_epoch(),
        params.cycles_per_epoch,
        "experiment view lost cycles_per_epoch");
    require_equal(experiment.seed(), params.seed, "experiment view lost seed");
    require_equal(experiment.backend(), params.backend, "experiment view lost backend");
    require_equal(experiment.dataset(), params.dataset, "experiment view lost dataset");
    require_equal(experiment.input_path(), params.input_path, "experiment view lost input_path");
    require_equal(experiment.csv_path(), params.csv_path, "experiment view lost csv_path");

    require_equal(energy.lambda_u(), params.lambda_u, "energy view lost lambda_u");
    require_equal(energy.lambda_v(), params.lambda_v, "energy view lost lambda_v");
    require_equal(energy.proposal_count(), params.proposal_count, "energy view lost proposal_count");

    require_equal(route.strength_mode(), params.route_strength_mode, "route view lost strength mode");
    require_equal(route.hint_agg(), params.route_hint_agg, "route view lost hint agg");
    require_equal(route.refresh(), params.route_refresh, "route view lost refresh");
    require_equal(route.route_count(), params.K_route, "route view lost K_route");

    require_equal(fallback.source(), params.route_fallback_source, "fallback view lost source");
    require_equal(
        fallback.persist_cycles(),
        params.route_fallback_persist_cycles,
        "fallback view lost persistence");

    require_equal(credit.learning(), params.route_credit_learning, "credit view lost learning flag");
    require_equal(
        credit.retry_candidates(),
        params.route_source_retry_candidates,
        "credit view lost retry candidates");

    require_equal(
        quality.candidate_weight_beta(),
        params.route_quality_candidate_weight_beta,
        "quality view lost candidate weight beta");
    require_equal(
        quality.source_normalization(),
        params.route_quality_source_normalization,
        "quality view lost source normalization");

    params.N = 128;
    if (experiment.n() != 128) {
        throw std::runtime_error("typed config views must reflect subsequent flat-field updates");
    }

    return 0;
}
