#include "v02_pre/RouteCoreV02.hpp"

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
    params.K_jump = 2;
    params.routing_source = "reservoir";
    params.route_mode = "jump-neighbors";
    params.lambda_route = 0.0f;
    require_bool(RouteCoreV02::routing_enabled(params.route()), true, "jump routing should enable routing");
    require_bool(
        RouteCoreV02::jump_neighbors_active(params.route()),
        true,
        "jump-neighbors mode should activate jump neighbors");
    require_bool(
        RouteCoreV02::route_hint_active(params.route()),
        false,
        "jump-neighbors mode should not activate route hints");

    const std::array<std::string, 7> route_modes{
        "off",
        "probe",
        "jump-neighbors",
        "hint-oracle",
        "hint-parsed",
        "hint-kv-exact",
        "hint-kv-hash",
    };
    params.K_jump = 2;
    params.routing_source = "reservoir";
    params.lambda_route = 1.0f;
    for (const std::string& mode : route_modes) {
        params.route_mode = mode;
        const bool expected_routing = mode == "probe" || mode == "jump-neighbors";
        const bool expected_hint = mode == "hint-oracle" || mode == "hint-parsed" ||
                                   mode == "hint-kv-exact" || mode == "hint-kv-hash";
        require_bool(
            RouteCoreV02::routing_enabled(params.route()),
            expected_routing,
            "routing truth table drifted for mode=" + mode);
        require_bool(
            RouteCoreV02::route_hint_active(params.route()),
            expected_hint,
            "route hint truth table drifted for mode=" + mode);
        if (RouteCoreV02::routing_enabled(params.route()) &&
            RouteCoreV02::route_hint_active(params.route())) {
            throw std::runtime_error("routing and route hints must stay mutually exclusive");
        }
    }

    params.routing_source = "none";
    params.route_mode = "jump-neighbors";
    require_bool(
        RouteCoreV02::routing_enabled(params.route()),
        false,
        "routing_source=none must disable routing");
    require_bool(
        RouteCoreV02::jump_neighbors_active(params.route()),
        false,
        "routing_source=none must disable jump neighbors");

    params.routing_source = "reservoir";
    params.K_jump = 0;
    require_bool(
        RouteCoreV02::routing_enabled(params.route()),
        false,
        "K_jump=0 must disable routing");

    params.K_jump = 2;
    params.route_mode = "hint-kv-hash";
    params.lambda_route = 0.0f;
    require_bool(
        RouteCoreV02::routing_enabled(params.route()),
        false,
        "hint-kv-hash should stay out of jump routing");
    require_bool(
        RouteCoreV02::route_hint_kv_hash_active(params.route()),
        false,
        "lambda_route=0 must disable kv hash hints");
    require_bool(
        RouteCoreV02::route_hint_active(params.route()),
        false,
        "lambda_route=0 must disable route hints");

    params.lambda_route = 1.0f;
    params.route_hash_source = "raw-key";
    require_bool(
        RouteCoreV02::route_hint_kv_hash_active(params.route()),
        true,
        "positive lambda should activate kv hash hints");
    require_bool(
        RouteCoreV02::route_hint_active(params.route()),
        true,
        "kv hash hints should activate route hints");
    require_bool(
        RouteCoreV02::learned_code_key_hash_active(params.route()),
        false,
        "raw-key hash should not activate learned code key hash");

    params.route_hash_source = "joint-code-key";
    require_bool(
        RouteCoreV02::joint_code_key_hash_active(params.route()),
        true,
        "joint-code-key should activate joint code hash");
    require_bool(
        RouteCoreV02::learned_code_key_hash_active(params.route()),
        true,
        "joint-code-key should activate learned code hash");

    params.route_hash_source = "route-code-key";
    require_bool(
        RouteCoreV02::route_code_key_hash_active(params.route()),
        true,
        "route-code-key should activate route code hash");
    require_bool(
        RouteCoreV02::learned_code_key_hash_active(params.route()),
        true,
        "route-code-key should activate learned code hash");

    params.route_mode = "hint-oracle";
    require_bool(
        RouteCoreV02::route_hint_oracle_active(params.route()),
        true,
        "hint-oracle should activate oracle hints");
    require_bool(
        RouteCoreV02::routing_enabled(params.route()),
        false,
        "hint-oracle should stay out of jump routing");

    params.route_mode = "off";
    require_bool(RouteCoreV02::routing_enabled(params.route()), false, "off must disable routing");
    require_bool(RouteCoreV02::route_hint_active(params.route()), false, "off must disable hints");

    return 0;
}
