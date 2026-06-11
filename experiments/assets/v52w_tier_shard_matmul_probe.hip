#include <hip/hip_runtime.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

__global__ void matmul_vec_kernel(const float* weight, const float* input, float* output, int k) {
    int row = blockIdx.x * blockDim.x + threadIdx.x;
    if (row < k) {
        float sum = 0.0f;
        for (int col = 0; col < k; ++col) {
            sum += weight[row * k + col] * input[col];
        }
        output[row] = sum;
    }
}

static int host_matmul_reference(const float* weight, const float* input, float* output, int k) {
    for (int row = 0; row < k; ++row) {
        float sum = 0.0f;
        for (int col = 0; col < k; ++col) {
            sum += weight[row * k + col] * input[col];
        }
        output[row] = sum;
    }
    return 0;
}

int main(int argc, char** argv) {
    if (argc < 5) {
        std::fprintf(stderr, "usage: %s <k> <shard_path> <page_offset> <decode_step_id>\n", argv[0]);
        return 1;
    }

    int k = std::atoi(argv[1]);
    if (k <= 0 || k > 32) {
        k = 8;
    }
    const char* shard_path = argv[2];
    std::uint64_t page_offset = std::strtoull(argv[3], nullptr, 10);
    const char* step_id = argv[4];
    const std::size_t header_bytes = 16;
    const std::size_t need_bytes = header_bytes + static_cast<std::size_t>(k) * static_cast<std::size_t>(k) * sizeof(float);

    int fd = ::open(shard_path, O_RDONLY);
    if (fd < 0) {
        std::fprintf(stderr, "open failed: %s\n", shard_path);
        return 2;
    }
    off_t file_size = ::lseek(fd, 0, SEEK_END);
    if (file_size < 0 || static_cast<std::uint64_t>(file_size) < page_offset + need_bytes) {
        std::fprintf(stderr, "shard file too small for page offset %llu\n", static_cast<unsigned long long>(page_offset));
        ::close(fd);
        return 3;
    }
    void* mapped = ::mmap(nullptr, static_cast<std::size_t>(file_size), PROT_READ, MAP_PRIVATE, fd, 0);
    ::close(fd);
    if (mapped == MAP_FAILED) {
        std::fprintf(stderr, "mmap failed\n");
        return 4;
    }

    const unsigned char* page = static_cast<const unsigned char*>(mapped) + page_offset;
    const std::uint32_t* header = reinterpret_cast<const std::uint32_t*>(page);
    if (header[3] != 0xC001D00D) {
        std::fprintf(stderr, "page header magic mismatch\n");
        ::munmap(mapped, static_cast<std::size_t>(file_size));
        return 5;
    }

    float weight_host[32 * 32] = {};
    float input_host[32] = {};
    float output_host[32] = {};
    float expected_host[32] = {};
    const std::size_t weight_elems = static_cast<std::size_t>(k) * static_cast<std::size_t>(k);
    for (std::size_t i = 0; i < weight_elems; ++i) {
        weight_host[i] = static_cast<float>(page[header_bytes + i]) / 255.0f;
    }
    for (int i = 0; i < k; ++i) {
        input_host[i] = static_cast<float>((i % 3) + 1) * 0.25f;
    }
    host_matmul_reference(weight_host, input_host, expected_host, k);

    float *d_weight = nullptr, *d_input = nullptr, *d_output = nullptr;
    const std::size_t weight_bytes = static_cast<std::size_t>(k) * static_cast<std::size_t>(k) * sizeof(float);
    const std::size_t vec_bytes = static_cast<std::size_t>(k) * sizeof(float);
    if (hipMalloc(&d_weight, weight_bytes) != hipSuccess ||
        hipMalloc(&d_input, vec_bytes) != hipSuccess ||
        hipMalloc(&d_output, vec_bytes) != hipSuccess) {
        std::fprintf(stderr, "hipMalloc failed\n");
        ::munmap(mapped, static_cast<std::size_t>(file_size));
        return 6;
    }
    if (hipMemcpy(d_weight, weight_host, weight_bytes, hipMemcpyHostToDevice) != hipSuccess ||
        hipMemcpy(d_input, input_host, vec_bytes, hipMemcpyHostToDevice) != hipSuccess ||
        hipMemset(d_output, 0, vec_bytes) != hipSuccess) {
        std::fprintf(stderr, "hipMemcpy H2D or hipMemset failed\n");
        ::munmap(mapped, static_cast<std::size_t>(file_size));
        return 7;
    }

    int threads = 64;
    int blocks = (k + threads - 1) / threads;
    hipLaunchKernelGGL(matmul_vec_kernel, dim3(blocks), dim3(threads), 0, 0, d_weight, d_input, d_output, k);
    if (hipDeviceSynchronize() != hipSuccess) {
        std::fprintf(stderr, "hipDeviceSynchronize failed\n");
        ::munmap(mapped, static_cast<std::size_t>(file_size));
        return 8;
    }
    if (hipMemcpy(output_host, d_output, vec_bytes, hipMemcpyDeviceToHost) != hipSuccess) {
        std::fprintf(stderr, "hipMemcpy D2H failed\n");
        ::munmap(mapped, static_cast<std::size_t>(file_size));
        return 9;
    }

    for (int i = 0; i < k; ++i) {
        float delta = output_host[i] - expected_host[i];
        if (delta < -1e-3f || delta > 1e-3f) {
            std::fprintf(stderr, "verification failed row=%d got=%f expected=%f\n", i, output_host[i], expected_host[i]);
            ::munmap(mapped, static_cast<std::size_t>(file_size));
            return 10;
        }
    }

    hipFree(d_weight);
    hipFree(d_input);
    hipFree(d_output);
    ::munmap(mapped, static_cast<std::size_t>(file_size));
    std::printf(
        "v52w_matmul_probe_ok step=%s k=%d shard=%s offset=%llu y0=%f\n",
        step_id,
        k,
        shard_path,
        static_cast<unsigned long long>(page_offset),
        output_host[0]
    );
    return 0;
}
