#include <hip/hip_runtime.h>

#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>

__global__ void q4_dequant_matvec_kernel(const unsigned char* q4, const float* input, float* output, int m, int k) {
    int row = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= m) {
        return;
    }
    float sum = 0.0f;
    int base = row * k;
    for (int col = 0; col < k; ++col) {
        int weight_index = base + col;
        unsigned char byte = q4[weight_index >> 1];
        int nibble = (weight_index & 1) ? ((byte >> 4) & 0x0F) : (byte & 0x0F);
        float w = (static_cast<float>(nibble) - 8.0f) / 8.0f;
        sum += w * input[col];
    }
    output[row] = sum;
}

static float host_dequant(unsigned char byte, int high_nibble) {
    int nibble = high_nibble ? ((byte >> 4) & 0x0F) : (byte & 0x0F);
    return (static_cast<float>(nibble) - 8.0f) / 8.0f;
}

static int check_hip(hipError_t status, const char* label) {
    if (status != hipSuccess) {
        std::fprintf(stderr, "%s failed: %s\n", label, hipGetErrorString(status));
        return 0;
    }
    return 1;
}

int main(int argc, char** argv) {
    int m = 1024;
    int k = 4096;
    int iterations = 20;
    if (argc > 1) {
        m = std::atoi(argv[1]);
    }
    if (argc > 2) {
        k = std::atoi(argv[2]);
    }
    if (argc > 3) {
        iterations = std::atoi(argv[3]);
    }
    if (m <= 0 || m > 8192 || k <= 0 || k > 8192 || iterations <= 0 || iterations > 200) {
        std::fprintf(stderr, "invalid args m=%d k=%d iterations=%d\n", m, k, iterations);
        return 1;
    }

    int device_count = 0;
    if (!check_hip(hipGetDeviceCount(&device_count), "hipGetDeviceCount") || device_count <= 0) {
        return 2;
    }
    hipDeviceProp_t props;
    if (!check_hip(hipGetDeviceProperties(&props, 0), "hipGetDeviceProperties")) {
        return 3;
    }

    const std::size_t weights = static_cast<std::size_t>(m) * static_cast<std::size_t>(k);
    const std::size_t q4_bytes = (weights + 1) / 2;
    std::vector<unsigned char> host_q4(q4_bytes);
    std::vector<float> host_input(k);
    std::vector<float> host_output(m, 0.0f);
    std::vector<float> expected(m, 0.0f);
    for (std::size_t i = 0; i < q4_bytes; ++i) {
        unsigned char lo = static_cast<unsigned char>((i * 7 + 3) & 0x0F);
        unsigned char hi = static_cast<unsigned char>((i * 11 + 5) & 0x0F);
        host_q4[i] = static_cast<unsigned char>(lo | (hi << 4));
    }
    for (int i = 0; i < k; ++i) {
        host_input[i] = static_cast<float>((i % 13) + 1) * 0.03125f;
    }
    for (int row = 0; row < m; ++row) {
        float sum = 0.0f;
        int base = row * k;
        for (int col = 0; col < k; ++col) {
            int weight_index = base + col;
            sum += host_dequant(host_q4[weight_index >> 1], weight_index & 1) * host_input[col];
        }
        expected[row] = sum;
    }

    unsigned char* d_q4 = nullptr;
    float* d_input = nullptr;
    float* d_output = nullptr;
    if (!check_hip(hipMalloc(&d_q4, q4_bytes), "hipMalloc q4") ||
        !check_hip(hipMalloc(&d_input, static_cast<std::size_t>(k) * sizeof(float)), "hipMalloc input") ||
        !check_hip(hipMalloc(&d_output, static_cast<std::size_t>(m) * sizeof(float)), "hipMalloc output")) {
        return 4;
    }

    auto h2d_start = std::chrono::steady_clock::now();
    if (!check_hip(hipMemcpy(d_q4, host_q4.data(), q4_bytes, hipMemcpyHostToDevice), "hipMemcpy q4 H2D") ||
        !check_hip(hipMemcpy(d_input, host_input.data(), static_cast<std::size_t>(k) * sizeof(float), hipMemcpyHostToDevice), "hipMemcpy input H2D") ||
        !check_hip(hipMemset(d_output, 0, static_cast<std::size_t>(m) * sizeof(float)), "hipMemset output")) {
        return 5;
    }
    auto h2d_stop = std::chrono::steady_clock::now();
    double h2d_ms = std::chrono::duration<double, std::milli>(h2d_stop - h2d_start).count();

    int threads = 128;
    int blocks = (m + threads - 1) / threads;
    hipLaunchKernelGGL(q4_dequant_matvec_kernel, dim3(blocks), dim3(threads), 0, 0, d_q4, d_input, d_output, m, k);
    if (!check_hip(hipGetLastError(), "warmup kernel launch")) {
        return 6;
    }
    if (!check_hip(hipDeviceSynchronize(), "hipDeviceSynchronize warmup")) {
        return 7;
    }

    hipEvent_t start_event;
    hipEvent_t stop_event;
    if (!check_hip(hipEventCreate(&start_event), "hipEventCreate start") ||
        !check_hip(hipEventCreate(&stop_event), "hipEventCreate stop")) {
        return 8;
    }
    if (!check_hip(hipEventRecord(start_event, nullptr), "hipEventRecord start")) {
        return 9;
    }
    for (int i = 0; i < iterations; ++i) {
        hipLaunchKernelGGL(q4_dequant_matvec_kernel, dim3(blocks), dim3(threads), 0, 0, d_q4, d_input, d_output, m, k);
        if (!check_hip(hipGetLastError(), "timed kernel launch")) {
            return 10;
        }
    }
    if (!check_hip(hipEventRecord(stop_event, nullptr), "hipEventRecord stop") ||
        !check_hip(hipEventSynchronize(stop_event), "hipEventSynchronize stop")) {
        return 11;
    }
    float total_kernel_ms = 0.0f;
    if (!check_hip(hipEventElapsedTime(&total_kernel_ms, start_event, stop_event), "hipEventElapsedTime")) {
        return 12;
    }

    auto d2h_start = std::chrono::steady_clock::now();
    if (!check_hip(hipMemcpy(host_output.data(), d_output, static_cast<std::size_t>(m) * sizeof(float), hipMemcpyDeviceToHost), "hipMemcpy D2H")) {
        return 13;
    }
    auto d2h_stop = std::chrono::steady_clock::now();
    double d2h_ms = std::chrono::duration<double, std::milli>(d2h_stop - d2h_start).count();

    float max_abs_delta = 0.0f;
    for (int row = 0; row < m; ++row) {
        float delta = std::fabs(host_output[row] - expected[row]);
        if (delta > max_abs_delta) {
            max_abs_delta = delta;
        }
    }
    if (max_abs_delta > 0.02f) {
        std::fprintf(stderr, "verification failed max_abs_delta=%f output0=%f expected0=%f\n", max_abs_delta, host_output[0], expected[0]);
        return 14;
    }

    double avg_kernel_ms = static_cast<double>(total_kernel_ms) / static_cast<double>(iterations);
    double ops = static_cast<double>(m) * static_cast<double>(k) * 2.0;
    double gflops = ops / (avg_kernel_ms * 1.0e6);
    double bytes_touched = static_cast<double>(q4_bytes) + static_cast<double>(k) * sizeof(float) + static_cast<double>(m) * sizeof(float);
    double bandwidth_gbps = bytes_touched / (avg_kernel_ms / 1000.0) / 1.0e9;

    std::printf(
        "v61l_gpu_page_dequant_matmul_ok device_count=%d device_id=0 m=%d k=%d q4_bytes=%zu weights=%zu iterations=%d avg_kernel_ms=%.6f h2d_ms=%.6f d2h_ms=%.6f max_abs_delta=%.8f gflops=%.6f bandwidth_gbps=%.6f output0=%.6f\n",
        device_count,
        m,
        k,
        q4_bytes,
        weights,
        iterations,
        avg_kernel_ms,
        h2d_ms,
        d2h_ms,
        max_abs_delta,
        gflops,
        bandwidth_gbps,
        host_output[0]
    );

    hipEventDestroy(start_event);
    hipEventDestroy(stop_event);
    hipFree(d_q4);
    hipFree(d_input);
    hipFree(d_output);
    return 0;
}
