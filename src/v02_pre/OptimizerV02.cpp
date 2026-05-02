#include "v02_pre/OptimizerV02.hpp"

#include "common/CSVLogger.hpp"
#include "common/Metrics.hpp"

namespace dle {

OptimizerV02::OptimizerV02(const V02PreParams& params)
    : params_(params), dataset_(params), graph_(params) {}

int OptimizerV02::run() {
    CSVLogger logger(params_.csv_path);
    logger.write_header(v02_csv_header());

    for (int epoch = 0; epoch < params_.epochs; ++epoch) {
        const auto window = dataset_.window_for_epoch(epoch, params_.N);
        graph_.begin_epoch(epoch, window);
        logger.write_row(to_csv_row(graph_.run_epoch(epoch, dataset_.oracle_table())));
        graph_.apply_contrastive_learning();
    }

    return 0;
}

}  // namespace dle
