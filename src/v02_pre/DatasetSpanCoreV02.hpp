#pragma once

#include "v02_pre/ByteDataset.hpp"

namespace dle {

class DatasetSpanCoreV02 {
  public:
    static int span_offset_for_query(
        const ByteDataset::Window& window,
        const ByteDataset::KVQuery& query,
        int route_span_hints) {
        if (route_span_hints == 0 || !query.hit || query.value_pos < 0) {
            return 0;
        }
        for (const auto& record : window.kv_records) {
            if (record.key != query.key || record.marker_pos >= query.query_pos ||
                record.value_pos < 0 || record.value_len <= 0) {
                continue;
            }
            const int span_end = record.value_pos + record.value_len;
            if (query.value_pos >= record.value_pos && query.value_pos < span_end) {
                return query.value_pos - record.value_pos;
            }
        }
        return 0;
    }

    static int record_value_pos_at_span_offset(
        const ByteDataset::KVRecord& record,
        int span_offset,
        int n) {
        if (span_offset < 0 || record.value_pos < 0 || record.value_len <= 0 ||
            span_offset >= record.value_len) {
            return -1;
        }
        const int value_pos = record.value_pos + span_offset;
        return value_pos >= 0 && value_pos < n ? value_pos : -1;
    }
};

}  // namespace dle
