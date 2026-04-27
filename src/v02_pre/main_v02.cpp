#include <exception>
#include <iostream>

#include "common/CLI.hpp"
#include "common/Params.hpp"
#include "v02_pre/OptimizerV02.hpp"

int main(int argc, char** argv) {
    try {
        const dle::CliArgs args = dle::parse_cli_args(argc, argv);
        if (args.find("help") != args.end()) {
            dle::print_v02_help(std::cout);
            return 0;
        }

        dle::V02PreParams params;
        dle::apply_v02_overrides(params, args);

        dle::OptimizerV02 optimizer(params);
        return optimizer.run();
    } catch (const std::exception& ex) {
        std::cerr << "dmv02 error: " << ex.what() << '\n';
        return 1;
    }
}
