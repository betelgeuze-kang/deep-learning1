#include <hip/hip_runtime.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>

__global__ void axpy_kernel(const float* x, float* y, int n, float a) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        y[idx] = a * x[idx] + y[idx];
    }
}

int main(int argc, char** argv) {
    int n = 256;
    float a = 1.25f;
    if (argc > 1) {
        n = std::atoi(argv[1]);
        if (n <= 0 || n > 4096) {
            n = 256;
        }
    }

    float* host_x = new float[n];
    float* host_y = new float[n];
    for (int i = 0; i < n; ++i) {
        host_x[i] = static_cast<float>(i % 17) * 0.01f;
        host_y[i] = 0.0f;
    }

    float *d_x = nullptr, *d_y = nullptr;
    if (hipMalloc(&d_x, n * sizeof(float)) != hipSuccess ||
        hipMalloc(&d_y, n * sizeof(float)) != hipSuccess) {
        std::fprintf(stderr, "hipMalloc failed\n");
        return 2;
    }
    if (hipMemcpy(d_x, host_x, n * sizeof(float), hipMemcpyHostToDevice) != hipSuccess ||
        hipMemcpy(d_y, host_y, n * sizeof(float), hipMemcpyHostToDevice) != hipSuccess) {
        std::fprintf(stderr, "hipMemcpy H2D failed\n");
        return 3;
    }

    int threads = 64;
    int blocks = (n + threads - 1) / threads;
    hipLaunchKernelGGL(axpy_kernel, dim3(blocks), dim3(threads), 0, 0, d_x, d_y, n, a);
    if (hipDeviceSynchronize() != hipSuccess) {
        std::fprintf(stderr, "hipDeviceSynchronize failed\n");
        return 4;
    }

    if (hipMemcpy(host_y, d_y, n * sizeof(float), hipMemcpyDeviceToHost) != hipSuccess) {
        std::fprintf(stderr, "hipMemcpy D2H failed\n");
        return 5;
    }

    float expected = a * host_x[0] + 0.0f;
    if (host_y[0] != expected) {
        std::fprintf(stderr, "verification failed: got %f expected %f\n", host_y[0], expected);
        return 6;
    }

    hipFree(d_x);
    hipFree(d_y);
    delete[] host_x;
    delete[] host_y;
    std::printf("v52v_axpy_probe_ok n=%d y0=%f\n", n, host_y[0]);
    return 0;
}
