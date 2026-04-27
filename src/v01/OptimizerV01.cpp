#include "v01/OptimizerV01.hpp"

#include "common/CSVLogger.hpp"
#include "common/Metrics.hpp"

namespace dle {

OptimizerV01::OptimizerV01(const V01Params& params) : params_(params), graph_(params) {}

int OptimizerV01::run() {
    CSVLogger logger(params_.csv_path);
    logger.write_header(v01_csv_header());

    for (int cycle = 0; cycle < params_.cycles; ++cycle) {
        logger.write_row(to_csv_row(graph_.run_cycle(cycle)));
    }

    return 0;
}

}  // namespace dle
