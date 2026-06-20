#include "v02_pre/DatasetSpanCoreV02.hpp"

#include <stdexcept>
#include <string>

namespace {

void require_equal(int actual, int expected, const std::string& message) {
    if (actual != expected) {
        throw std::runtime_error(message);
    }
}

}  // namespace

int main() {
    using namespace dle;

    ByteDataset::Window window;
    ByteDataset::KVRecord first;
    first.key = "alpha";
    first.marker_pos = 2;
    first.value_pos = 10;
    first.value_len = 4;
    window.kv_records.push_back(first);

    ByteDataset::KVRecord later_same_key;
    later_same_key.key = "alpha";
    later_same_key.marker_pos = 8;
    later_same_key.value_pos = 20;
    later_same_key.value_len = 3;
    window.kv_records.push_back(later_same_key);

    ByteDataset::KVQuery query;
    query.key = "alpha";
    query.query_pos = 7;
    query.value_pos = 12;
    query.hit = true;

    require_equal(
        DatasetSpanCoreV02::span_offset_for_query(window, query, 1),
        2,
        "span offset should bind to the matching earlier record");

    ByteDataset::Window empty_window;
    require_equal(
        DatasetSpanCoreV02::span_offset_for_query(empty_window, query, 1),
        0,
        "empty kv_records must default to zero");

    ByteDataset::KVQuery different_key_query = query;
    different_key_query.key = "beta";
    require_equal(
        DatasetSpanCoreV02::span_offset_for_query(window, different_key_query, 1),
        0,
        "different keys must default to zero");

    ByteDataset::KVQuery span_end_query = query;
    span_end_query.value_pos = 14;
    require_equal(
        DatasetSpanCoreV02::span_offset_for_query(window, span_end_query, 1),
        0,
        "query value at span_end must be excluded");

    ByteDataset::Window overlapping_window;
    overlapping_window.kv_records.push_back(first);
    ByteDataset::KVRecord overlapping;
    overlapping.key = "alpha";
    overlapping.marker_pos = 3;
    overlapping.value_pos = 11;
    overlapping.value_len = 4;
    overlapping_window.kv_records.push_back(overlapping);
    require_equal(
        DatasetSpanCoreV02::span_offset_for_query(overlapping_window, query, 1),
        2,
        "first matching record order must be preserved");

    require_equal(
        DatasetSpanCoreV02::span_offset_for_query(window, query, 0),
        0,
        "disabled route span hints should default to zero");

    query.hit = false;
    require_equal(
        DatasetSpanCoreV02::span_offset_for_query(window, query, 1),
        0,
        "missing query hit should default to zero");

    query.hit = true;
    query.value_pos = 20;
    require_equal(
        DatasetSpanCoreV02::span_offset_for_query(window, query, 1),
        0,
        "future marker records must not provide span offsets");

    require_equal(
        DatasetSpanCoreV02::record_value_pos_at_span_offset(first, 0, 16),
        10,
        "span offset zero value position drifted");
    require_equal(
        DatasetSpanCoreV02::record_value_pos_at_span_offset(first, 3, 16),
        13,
        "last in-range span offset value position drifted");
    require_equal(
        DatasetSpanCoreV02::record_value_pos_at_span_offset(first, 4, 16),
        -1,
        "span offset at value_len must be rejected");
    require_equal(
        DatasetSpanCoreV02::record_value_pos_at_span_offset(first, -1, 16),
        -1,
        "negative span offset must be rejected");
    require_equal(
        DatasetSpanCoreV02::record_value_pos_at_span_offset(first, 3, 13),
        -1,
        "value position outside n must be rejected");
    require_equal(
        DatasetSpanCoreV02::record_value_pos_at_span_offset(first, 0, 0),
        -1,
        "non-positive n must reject otherwise valid value positions");

    ByteDataset::KVRecord invalid;
    invalid.key = "alpha";
    invalid.value_pos = -1;
    invalid.value_len = 4;
    require_equal(
        DatasetSpanCoreV02::record_value_pos_at_span_offset(invalid, 0, 16),
        -1,
        "negative value_pos must be rejected");
    invalid.value_pos = 1;
    invalid.value_len = 0;
    require_equal(
        DatasetSpanCoreV02::record_value_pos_at_span_offset(invalid, 0, 16),
        -1,
        "non-positive value_len must be rejected");

    return 0;
}
