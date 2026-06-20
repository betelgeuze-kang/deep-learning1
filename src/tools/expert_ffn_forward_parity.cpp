#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {

struct Args {
  int hidden = 0;
  int intermediate = 0;
  std::string w1_path;
  std::string w2_path;
  std::string w3_path;
  std::string input_path;
  std::string output_path;
};

void usage() {
  std::cerr
      << "usage: expert_ffn_forward_parity --hidden N --intermediate M "
      << "--w1 W1.f32 --w2 W2.f32 --w3 W3.f32 --input X.f32 --output Y.f32\n";
}

bool read_i32(const std::string& value, int& out) {
  try {
    size_t consumed = 0;
    const int parsed = std::stoi(value, &consumed);
    if (consumed != value.size() || parsed <= 0) {
      return false;
    }
    out = parsed;
    return true;
  } catch (...) {
    return false;
  }
}

bool parse_args(int argc, char** argv, Args& args) {
  for (int i = 1; i < argc; ++i) {
    const std::string key = argv[i];
    if (i + 1 >= argc) {
      return false;
    }
    const std::string value = argv[++i];
    if (key == "--hidden") {
      if (!read_i32(value, args.hidden)) {
        return false;
      }
    } else if (key == "--intermediate") {
      if (!read_i32(value, args.intermediate)) {
        return false;
      }
    } else if (key == "--w1") {
      args.w1_path = value;
    } else if (key == "--w2") {
      args.w2_path = value;
    } else if (key == "--w3") {
      args.w3_path = value;
    } else if (key == "--input") {
      args.input_path = value;
    } else if (key == "--output") {
      args.output_path = value;
    } else {
      return false;
    }
  }
  return args.hidden > 0 && args.intermediate > 0 && !args.w1_path.empty() &&
         !args.w2_path.empty() && !args.w3_path.empty() && !args.input_path.empty() &&
         !args.output_path.empty();
}

bool read_f32_file(const std::string& path, size_t count, std::vector<float>& out) {
  out.assign(count, 0.0f);
  std::ifstream input(path, std::ios::binary);
  if (!input) {
    std::cerr << "failed to open input file: " << path << "\n";
    return false;
  }
  input.read(reinterpret_cast<char*>(out.data()), static_cast<std::streamsize>(count * sizeof(float)));
  if (input.gcount() != static_cast<std::streamsize>(count * sizeof(float))) {
    std::cerr << "short input file: " << path << "\n";
    return false;
  }
  char extra = 0;
  if (input.read(&extra, 1)) {
    std::cerr << "input file has trailing bytes: " << path << "\n";
    return false;
  }
  return true;
}

bool write_f32_file(const std::string& path, const std::vector<float>& values) {
  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  if (!output) {
    std::cerr << "failed to open output file: " << path << "\n";
    return false;
  }
  output.write(reinterpret_cast<const char*>(values.data()),
               static_cast<std::streamsize>(values.size() * sizeof(float)));
  return static_cast<bool>(output);
}

float silu(float value) {
  return value / (1.0f + std::exp(-value));
}

}  // namespace

int main(int argc, char** argv) {
  Args args;
  if (!parse_args(argc, argv, args)) {
    usage();
    return 2;
  }

  const size_t hidden = static_cast<size_t>(args.hidden);
  const size_t intermediate = static_cast<size_t>(args.intermediate);
  std::vector<float> w1;
  std::vector<float> w2;
  std::vector<float> w3;
  std::vector<float> x;
  if (!read_f32_file(args.w1_path, intermediate * hidden, w1) ||
      !read_f32_file(args.w2_path, hidden * intermediate, w2) ||
      !read_f32_file(args.w3_path, intermediate * hidden, w3) ||
      !read_f32_file(args.input_path, hidden, x)) {
    return 1;
  }

  std::vector<float> gated(intermediate, 0.0f);
  for (size_t row = 0; row < intermediate; ++row) {
    float gate_dot = 0.0f;
    float up_dot = 0.0f;
    for (size_t col = 0; col < hidden; ++col) {
      gate_dot += w1[row * hidden + col] * x[col];
      up_dot += w3[row * hidden + col] * x[col];
    }
    gated[row] = silu(gate_dot) * up_dot;
  }

  std::vector<float> output(hidden, 0.0f);
  for (size_t row = 0; row < hidden; ++row) {
    float sum = 0.0f;
    for (size_t col = 0; col < intermediate; ++col) {
      sum += w2[row * intermediate + col] * gated[col];
    }
    output[row] = sum;
  }

  if (!write_f32_file(args.output_path, output)) {
    std::cerr << "failed to write output file: " << args.output_path << "\n";
    return 1;
  }
  return 0;
}
