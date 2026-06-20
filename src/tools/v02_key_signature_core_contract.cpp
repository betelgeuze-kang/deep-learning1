#include "v02_pre/KeySignatureCoreV02.hpp"

#include <cmath>
#include <stdexcept>
#include <string>

namespace {

void require_equal(int actual, int expected, const std::string& message) {
    if (actual != expected) {
        throw std::runtime_error(message);
    }
}

void require_near(double actual, double expected, const std::string& message) {
    if (std::abs(actual - expected) > 1.0e-12) {
        throw std::runtime_error(message);
    }
}

}  // namespace

int main() {
    using namespace dle;

    require_equal(
        KeySignatureCoreV02::digit_count("key-12-a3"),
        3,
        "ASCII digit count drifted");
    require_equal(
        KeySignatureCoreV02::common_prefix_count("alpha-1", "alpha-2"),
        6,
        "common prefix count drifted");
    require_equal(
        KeySignatureCoreV02::common_suffix_count("row-abc", "col-abc"),
        4,
        "common suffix count drifted");
    require_equal(
        KeySignatureCoreV02::common_prefix_count("", "abc"),
        0,
        "empty prefix count drifted");
    require_equal(
        KeySignatureCoreV02::common_suffix_count("", "abc"),
        0,
        "empty suffix count drifted");

    require_near(
        KeySignatureCoreV02::key_shape_score("k12", "x34"),
        5.0,
        "same-length same-digit key shape score drifted");
    require_near(
        KeySignatureCoreV02::key_shape_score("abc1def", "abc2def"),
        5.0 + 6.0 / 7.0,
        "prefix/suffix key shape score drifted");
    require_near(
        KeySignatureCoreV02::key_shape_score("", ""),
        5.0,
        "empty key shape max-length clamp drifted");

    require_near(
        KeySignatureCoreV02::byte_signature_shape_score("abcd", "abxd"),
        3.25,
        "byte signature shape score drifted");
    require_near(
        KeySignatureCoreV02::byte_signature_shape_score("", ""),
        1.0,
        "empty byte signature max-length clamp drifted");

    return 0;
}
