#pragma once

#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>

namespace dle {

class CSVLogger {
  public:
    explicit CSVLogger(const std::string& path) {
        if (path.empty()) {
            out_ = &std::cout;
            return;
        }

        file_.open(path, std::ios::out | std::ios::trunc);
        if (!file_) {
            throw std::runtime_error("failed to open CSV output: " + path);
        }
        out_ = &file_;
    }

    void write_header(const std::string& header) { write_line(header); }

    void write_row(const std::string& row) { write_line(row); }

  private:
    void write_line(const std::string& line) {
        (*out_) << line << '\n';
        out_->flush();
    }

    std::ofstream file_;
    std::ostream* out_ = nullptr;
};

}  // namespace dle
