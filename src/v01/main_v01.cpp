#include <exception>
#include <iostream>

#include "common/CLI.hpp"
#include "common/Params.hpp"
#include "v01/OptimizerV01.hpp"

int main(int argc, char** argv) {
    try {
        const dle::CliArgs args = dle::parse_cli_args(argc, argv);
        if (args.find("help") != args.end()) {
            dle::print_v01_help(std::cout);
            return 0;
        }

        dle::V01Params params;
        dle::apply_v01_overrides(params, args);

        dle::OptimizerV01 optimizer(params);
        return optimizer.run();
    } catch (const std::exception& ex) {
        std::cerr << "dmv01 error: " << ex.what() << '\n';
        return 1;
    }
}
