#include "v02_pre/EnergyCoreV02.hpp"

#include <array>
#include <cmath>
#include <stdexcept>
#include <string>

namespace {

void require_near(double actual, double expected, const std::string& message) {
    if (std::abs(actual - expected) > 1.0e-6) {
        throw std::runtime_error(message);
    }
}

}  // namespace

int main() {
    using namespace dle;

    FieldTable field;
    CouplingTable coupling;
    const std::uint8_t input = 17;
    const std::uint8_t old_high = 1;
    const std::uint8_t old_low = 2;
    const std::uint8_t new_high = 3;
    const std::uint8_t new_low = 4;
    const float lambda_u = 2.0f;
    const float lambda_b = 0.5f;
    const float lambda_v = 1.25f;

    field.add(0, input, old_high, 0.25f);
    field.add(1, input, old_low, -0.50f);
    field.add(0, input, new_high, 1.25f);
    field.add(1, input, new_low, 0.75f);
    coupling.add(input, old_high, old_low, -0.40f);
    coupling.add(input, new_high, new_low, 0.60f);

    const double expected_new_pair =
        -static_cast<double>(lambda_u) * (1.25 + 0.75) -
        static_cast<double>(lambda_b) * 0.60;
    const double expected_old_pair =
        -static_cast<double>(lambda_u) * (0.25 - 0.50) -
        static_cast<double>(lambda_b) * -0.40;
    require_near(
        EnergyCoreV02::pair_energy(
            lambda_u, lambda_b, field, coupling, input, new_high, new_low),
        expected_new_pair,
        "pair energy drifted");
    require_near(
        EnergyCoreV02::pair_delta(
            lambda_u,
            lambda_b,
            field,
            coupling,
            input,
            {old_high, old_low},
            new_high,
            new_low),
        expected_new_pair - expected_old_pair,
        "pair delta drifted");

    const std::array<std::uint8_t, FieldTable::Channels> neighbor{3, 9};
    require_near(
        EnergyCoreV02::neighbor_disagreement(new_high, new_low, neighbor),
        1.0,
        "neighbor disagreement drifted");
    require_near(
        EnergyCoreV02::neighbor_disagreement_energy(lambda_v, new_high, new_low, neighbor),
        1.25,
        "neighbor disagreement energy drifted");
    require_near(
        EnergyCoreV02::neighbor_disagreement_delta(
            lambda_v,
            {old_high, old_low},
            new_high,
            new_low,
            neighbor),
        -1.25,
        "neighbor disagreement delta drifted");
    require_near(
        EnergyCoreV02::local_temperature(0.1f, 0.2f, 0.01f, -3.0f, 1.5f),
        0.1 + 0.2 * 3.0 / 1.51,
        "local temperature drifted");

    return 0;
}
