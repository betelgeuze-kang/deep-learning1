#pragma once

#include "common/Params.hpp"
#include "v01/GraphV01.hpp"

namespace dle {

class OptimizerV01 {
  public:
    explicit OptimizerV01(const V01Params& params);

    int run();

  private:
    V01Params params_;
    GraphV01 graph_;
};

}  // namespace dle
