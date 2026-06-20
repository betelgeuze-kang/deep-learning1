#include "v02_pre/EvaluatorCoreV02.hpp"

#include <cmath>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

void require_near(double actual, double expected, const std::string& message) {
    if (std::abs(actual - expected) > 1.0e-12) {
        throw std::runtime_error(message);
    }
}

}  // namespace

int main() {
    using namespace dle;

    require_near(EvaluatorCoreV02::ratio_or_zero(3.0, 4.0), 0.75, "double ratio drifted");
    require_near(EvaluatorCoreV02::ratio_or_zero(3, 4), 0.75, "integer ratio drifted");
    require_near(
        EvaluatorCoreV02::ratio_or_zero(3.0, 0.0),
        0.0,
        "zero denominator must preserve default-zero metric semantics");
    require_near(
        EvaluatorCoreV02::ratio_or_zero(3, 0),
        0.0,
        "zero integer denominator must preserve default-zero metric semantics");
    require_near(
        EvaluatorCoreV02::ratio_or_zero(-3.0, 4.0),
        -0.75,
        "negative ratio drifted");

    require_near(
        EvaluatorCoreV02::nearest_rank_quantile({}, 0.50),
        0.0,
        "empty quantile must preserve default-zero metric semantics");
    require_near(
        EvaluatorCoreV02::nearest_rank_quantile({4.0, 1.0, 9.0, 2.0}, 0.50),
        2.0,
        "p50 nearest-rank quantile drifted");
    require_near(
        EvaluatorCoreV02::nearest_rank_quantile({4.0, 1.0, 9.0, 2.0}, 0.90),
        9.0,
        "p90 nearest-rank quantile drifted");
    require_near(
        EvaluatorCoreV02::nearest_rank_quantile({4.0, 1.0, 9.0, 2.0}, 0.0),
        1.0,
        "zero quantile must clamp to first nearest-rank element");

    return 0;
}
