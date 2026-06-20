#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <vector>

namespace dle {

class EvaluatorCoreV02 {
  public:
    static double ratio_or_zero(double numerator, double denominator) {
        return denominator > 0.0 ? numerator / denominator : 0.0;
    }

    static double ratio_or_zero(int numerator, int denominator) {
        return ratio_or_zero(
            static_cast<double>(numerator),
            static_cast<double>(denominator));
    }

    static double nearest_rank_quantile(std::vector<double> values, double quantile) {
        if (values.empty()) {
            return 0.0;
        }
        std::sort(values.begin(), values.end());
        const auto rank =
            static_cast<std::size_t>(std::ceil(quantile * static_cast<double>(values.size())));
        return values[std::min(rank > 0 ? rank - 1 : 0, values.size() - 1)];
    }
};

}  // namespace dle
