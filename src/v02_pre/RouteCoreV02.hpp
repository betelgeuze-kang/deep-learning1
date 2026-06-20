#pragma once

#include "common/Params.hpp"

namespace dle {

class RouteCoreV02 {
  public:
    static bool routing_enabled(const V02RouteConfigView& route) {
        return route.jump_neighbor_count() > 0 && route.routing_source() != "none" &&
               route.mode() != "off" && route.mode() != "hint-oracle" &&
               route.mode() != "hint-parsed" && route.mode() != "hint-kv-exact" &&
               route.mode() != "hint-kv-hash";
    }

    static bool jump_neighbors_active(const V02RouteConfigView& route) {
        return routing_enabled(route) && route.mode() == "jump-neighbors";
    }

    static bool route_hint_oracle_active(const V02RouteConfigView& route) {
        return route.mode() == "hint-oracle" && route.lambda() > 0.0f;
    }

    static bool route_hint_parsed_active(const V02RouteConfigView& route) {
        return route.mode() == "hint-parsed" && route.lambda() > 0.0f;
    }

    static bool route_hint_kv_exact_active(const V02RouteConfigView& route) {
        return route.mode() == "hint-kv-exact" && route.lambda() > 0.0f;
    }

    static bool route_hint_kv_hash_active(const V02RouteConfigView& route) {
        return route.mode() == "hint-kv-hash" && route.lambda() > 0.0f;
    }

    static bool joint_code_key_hash_active(const V02RouteConfigView& route) {
        return route_hint_kv_hash_active(route) && route.hash_source() == "joint-code-key";
    }

    static bool route_code_key_hash_active(const V02RouteConfigView& route) {
        return route_hint_kv_hash_active(route) && route.hash_source() == "route-code-key";
    }

    static bool learned_code_key_hash_active(const V02RouteConfigView& route) {
        return joint_code_key_hash_active(route) || route_code_key_hash_active(route);
    }

    static bool route_hint_active(const V02RouteConfigView& route) {
        return route_hint_oracle_active(route) || route_hint_parsed_active(route) ||
               route_hint_kv_exact_active(route) || route_hint_kv_hash_active(route);
    }
};

}  // namespace dle
