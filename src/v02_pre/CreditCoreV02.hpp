#pragma once

#include "common/Params.hpp"

namespace dle {

class CreditCoreV02 {
  public:
    static bool route_credit_learn_active(
        const V02CreditConfigView& credit,
        int current_epoch) {
        return credit.learning() != 0 && credit.mode() != "off" &&
               current_epoch >= credit.learn_after_epoch();
    }

    static bool route_credit_apply_active(
        const V02CreditConfigView& credit,
        int current_epoch) {
        return credit.learning() != 0 && credit.mode() != "off" &&
               current_epoch >= credit.apply_after_epoch();
    }

    static bool route_source_credit_active(const V02CreditConfigView& credit) {
        return credit.source_learning() != 0;
    }

    static bool route_source_credit_apply_active(
        const V02CreditConfigView& credit,
        int current_epoch) {
        return route_source_credit_active(credit) &&
               credit.source_apply_mode() != "off" &&
               current_epoch >= credit.apply_after_epoch();
    }

    static bool route_source_credit_ranking_apply_active(
        const V02CreditConfigView& credit,
        int current_epoch) {
        return route_source_credit_apply_active(credit, current_epoch) &&
               (credit.source_apply_mode() == "ranking" ||
                credit.source_apply_mode() == "ranking-strength");
    }

    static bool route_source_credit_strength_apply_active(
        const V02CreditConfigView& credit,
        int current_epoch) {
        return route_source_credit_apply_active(credit, current_epoch) &&
               (credit.source_apply_mode() == "strength" ||
                credit.source_apply_mode() == "ranking-strength");
    }

    static bool route_source_filter_active(
        const V02CreditConfigView& credit,
        int current_epoch) {
        return route_source_credit_apply_active(credit, current_epoch) &&
               credit.source_filter_mode() != "off";
    }
};

}  // namespace dle
