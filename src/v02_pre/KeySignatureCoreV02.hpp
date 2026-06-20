#pragma once

#include <algorithm>
#include <cctype>
#include <cstddef>
#include <string>

namespace dle {

class KeySignatureCoreV02 {
  public:
    static int digit_count(const std::string& key) {
        int count = 0;
        for (const unsigned char byte : key) {
            if (std::isdigit(byte)) {
                ++count;
            }
        }
        return count;
    }

    static int common_prefix_count(const std::string& lhs, const std::string& rhs) {
        const auto limit = std::min(lhs.size(), rhs.size());
        std::size_t count = 0;
        while (count < limit && lhs[count] == rhs[count]) {
            ++count;
        }
        return static_cast<int>(count);
    }

    static int common_suffix_count(const std::string& lhs, const std::string& rhs) {
        const auto limit = std::min(lhs.size(), rhs.size());
        std::size_t count = 0;
        while (count < limit &&
               lhs[lhs.size() - 1U - count] == rhs[rhs.size() - 1U - count]) {
            ++count;
        }
        return static_cast<int>(count);
    }

    static double key_shape_score(
        const std::string& query_key,
        const std::string& record_key) {
        const auto max_len = static_cast<double>(
            std::max<std::size_t>(1U, std::max(query_key.size(), record_key.size())));
        double score = 0.0;
        if (query_key.size() == record_key.size()) {
            score += 4.0;
        }
        if (digit_count(query_key) == digit_count(record_key)) {
            score += 1.0;
        }
        score += static_cast<double>(common_prefix_count(query_key, record_key)) / max_len;
        score += static_cast<double>(common_suffix_count(query_key, record_key)) / max_len;
        return score;
    }

    static double byte_signature_shape_score(
        const std::string& query_signature,
        const std::string& record_signature) {
        const auto max_len = static_cast<double>(
            std::max<std::size_t>(
                1U,
                std::max(query_signature.size(), record_signature.size())));
        const auto limit = std::min(query_signature.size(), record_signature.size());
        int positional_matches = 0;
        for (std::size_t index = 0; index < limit; ++index) {
            if (query_signature[index] == record_signature[index]) {
                ++positional_matches;
            }
        }
        double score = query_signature.size() == record_signature.size() ? 1.0 : 0.0;
        score += 2.0 * static_cast<double>(positional_matches) / max_len;
        score += static_cast<double>(
                     common_prefix_count(query_signature, record_signature)) /
                 max_len;
        score += static_cast<double>(
                     common_suffix_count(query_signature, record_signature)) /
                 max_len;
        return score;
    }
};

}  // namespace dle
