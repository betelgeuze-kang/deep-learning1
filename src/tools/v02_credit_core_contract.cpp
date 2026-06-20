#include "v02_pre/CreditCoreV02.hpp"

#include <array>
#include <stdexcept>
#include <string>

namespace {

void require_bool(bool actual, bool expected, const std::string& message) {
    if (actual != expected) {
        throw std::runtime_error(message);
    }
}

}  // namespace

int main() {
    using namespace dle;

    V02PreParams params;
    params.route_credit_learning = 1;
    params.route_credit_mode = "value-pos";
    params.route_credit_learn_after_epoch = 3;
    params.route_credit_apply_after_epoch = 5;

    require_bool(
        CreditCoreV02::route_credit_learn_active(params.credit(), 2),
        false,
        "credit learn must stay inactive before learn epoch");
    require_bool(
        CreditCoreV02::route_credit_learn_active(params.credit(), 3),
        true,
        "credit learn must activate at learn epoch");
    require_bool(
        CreditCoreV02::route_credit_apply_active(params.credit(), 4),
        false,
        "credit apply must stay inactive before apply epoch");
    require_bool(
        CreditCoreV02::route_credit_apply_active(params.credit(), 5),
        true,
        "credit apply must activate at apply epoch");

    const std::array<std::string, 2> credit_modes{"value-pos", "query-value"};
    for (const std::string& mode : credit_modes) {
        params.route_credit_mode = mode;
        params.route_credit_learning = 1;
        require_bool(
            CreditCoreV02::route_credit_learn_active(params.credit(), 3),
            true,
            "supported credit mode must activate learning at learn epoch: " + mode);
        require_bool(
            CreditCoreV02::route_credit_apply_active(params.credit(), 5),
            true,
            "supported credit mode must activate apply at apply epoch: " + mode);
    }

    params.route_credit_mode = "off";
    require_bool(
        CreditCoreV02::route_credit_learn_active(params.credit(), 99),
        false,
        "credit mode off must disable learning");
    require_bool(
        CreditCoreV02::route_credit_apply_active(params.credit(), 99),
        false,
        "credit mode off must disable apply");

    params.route_credit_mode = "value-pos";
    params.route_credit_learning = 0;
    require_bool(
        CreditCoreV02::route_credit_learn_active(params.credit(), 99),
        false,
        "credit learning flag off must disable learning");
    require_bool(
        CreditCoreV02::route_credit_apply_active(params.credit(), 99),
        false,
        "credit learning flag off must disable apply");

    params.route_source_credit_learning = 1;
    params.route_source_credit_apply_mode = "ranking";
    params.route_source_filter_mode = "negative-credit";
    params.route_credit_apply_after_epoch = 7;
    require_bool(
        CreditCoreV02::route_source_credit_active(params.credit()),
        true,
        "source credit learning flag must activate source credit");
    require_bool(
        CreditCoreV02::route_source_credit_apply_active(params.credit(), 6),
        false,
        "source credit apply must stay inactive before apply epoch");
    require_bool(
        CreditCoreV02::route_source_credit_apply_active(params.credit(), 7),
        true,
        "source credit apply must activate at apply epoch");
    require_bool(
        CreditCoreV02::route_source_credit_ranking_apply_active(params.credit(), 7),
        true,
        "ranking mode must activate ranking apply");
    require_bool(
        CreditCoreV02::route_source_credit_strength_apply_active(params.credit(), 7),
        false,
        "ranking mode must not activate strength apply");
    require_bool(
        CreditCoreV02::route_source_filter_active(params.credit(), 7),
        true,
        "negative-credit filter must activate when source credit apply is active");
    if (CreditCoreV02::route_source_filter_active(params.credit(), 7) &&
        !CreditCoreV02::route_source_credit_apply_active(params.credit(), 7)) {
        throw std::runtime_error("source filter must imply source credit apply");
    }
    if (CreditCoreV02::route_source_credit_ranking_apply_active(params.credit(), 7) &&
        !CreditCoreV02::route_source_credit_apply_active(params.credit(), 7)) {
        throw std::runtime_error("ranking apply must imply source credit apply");
    }

    params.route_source_credit_apply_mode = "strength";
    require_bool(
        CreditCoreV02::route_source_credit_ranking_apply_active(params.credit(), 7),
        false,
        "strength mode must not activate ranking apply");
    require_bool(
        CreditCoreV02::route_source_credit_strength_apply_active(params.credit(), 7),
        true,
        "strength mode must activate strength apply");
    if (CreditCoreV02::route_source_credit_strength_apply_active(params.credit(), 7) &&
        !CreditCoreV02::route_source_credit_apply_active(params.credit(), 7)) {
        throw std::runtime_error("strength apply must imply source credit apply");
    }

    params.route_source_credit_apply_mode = "ranking-strength";
    require_bool(
        CreditCoreV02::route_source_credit_ranking_apply_active(params.credit(), 7),
        true,
        "ranking-strength mode must activate ranking apply");
    require_bool(
        CreditCoreV02::route_source_credit_strength_apply_active(params.credit(), 7),
        true,
        "ranking-strength mode must activate strength apply");

    params.route_source_credit_apply_mode = "off";
    require_bool(
        CreditCoreV02::route_source_credit_apply_active(params.credit(), 99),
        false,
        "source apply mode off must disable source apply");
    require_bool(
        CreditCoreV02::route_source_filter_active(params.credit(), 99),
        false,
        "source apply mode off must disable source filter");

    params.route_source_credit_apply_mode = "ranking";
    params.route_source_filter_mode = "off";
    require_bool(
        CreditCoreV02::route_source_filter_active(params.credit(), 99),
        false,
        "source filter mode off must disable source filter");

    params.route_source_credit_learning = 0;
    require_bool(
        CreditCoreV02::route_source_credit_active(params.credit()),
        false,
        "source credit learning flag off must disable source credit");
    require_bool(
        CreditCoreV02::route_source_credit_apply_active(params.credit(), 99),
        false,
        "source credit learning flag off must disable source apply");

    return 0;
}
