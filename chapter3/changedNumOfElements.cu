//
// Created by elder on 7/15/2026.
//

#include <iostream>

//testing with different N values;
//128 * float = 256 bytes;
//1024 * float = 512 bytes;
//63 * float = 252 bytes;
//65 * float = 260 bytes;

//With N = 63 blocks is 1. With only 32 threads on it
//With N = 65 blocks is 2. With 32 threads per block
//With N = 128 blocks is 4. With 32 threads per block
//With N = 1024 blocks is 32. With 32 threads per block


// For N = 63, since 63/2 rounds to 1 we can only process elements 0-31. We are essentially ignoring elements 32-62
// For N = 65, since 64/2 rounds to 2 we can only process elements 0-63. 2*32 bytes worth of data we miss out on a single byte of data. In order to have all 65 bytes done we would either need another block or more threads per block

// In this example if N can be divided evenly by THREADS_PER_BLOCK we can accommodate N amount of bytes

constexpr  int N = 1024;
constexpr int THREADS_PER_BLOCK = 32;

float scale(int i, int n) {
    return static_cast<float>(i) / static_cast<float>(n - 1);
}

__device__ float distance(float x1, float x2) {
    return std::sqrtf((x2-x1) * (x2 - x1));
}

__global__ void distanceKernel(float *d_out, float *d_in, float ref) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;

    float x = d_in[i];

    d_out[i] = distance(x, ref);

    printf("i = %2d: dist from %f to %f is %f.\n", i, ref, x, d_out[i]); //print output
}

int main() {

    float *in = nullptr;
    float *out = nullptr;
    float ref = 0.5f;

    cudaMallocManaged(&in, N * sizeof(float));
    cudaMallocManaged(&out, N * sizeof(float));

    std:: cout << "Allocation size: " << N * sizeof(float) << std:: endl;

    std:: cout << "Size of in and out after allocation of memory" << std:: endl;
    std:: cout << "In: " << sizeof(in) << std:: endl;
    std:: cout << "Out: " << sizeof(out) << std:: endl;
    std:: cout << std:: endl;

    for (int i = 0; i < N; i++) {
        in[i] = scale(i, N);
    }

    auto blocks = N / THREADS_PER_BLOCK;
    std:: cout << "Blocks: " << blocks << std:: endl;
    std:: cout << "Threads: " << THREADS_PER_BLOCK << std:: endl;

    distanceKernel<<<blocks, THREADS_PER_BLOCK>>>(out, in, ref);

    cudaDeviceSynchronize();

    for (int i = 0; i < N; i++) {
        std:: cout << i << " " << out[i] << std:: endl;
    }

    cudaFree(in);
    cudaFree(out);

    return 0;
}