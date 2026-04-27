#pragma once

#include "common/Params.hpp"
#include "v02_pre/ByteDataset.hpp"
#include "v02_pre/GraphV02.hpp"

namespace dle {

class OptimizerV02 {
  public:
    explicit OptimizerV02(const V02PreParams& params);

    int run();

  private:
    V02PreParams params_;
    ByteDataset dataset_;
    GraphV02 graph_;
};

}  // namespace dle
