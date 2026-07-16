//
// Created by elder on 7/15/2026.
//

#include <iostream>
#include "kernel.h"

constexpr int N = 64;
constexpr int THREADS_PER_BLOCK = 32;

float scale(int i, int n) {
    return static_cast<float>(i) / static_cast<float>(n - 1);
}

__device__ float distance(float x1, float x2) {
    return std::sqrtf((x2-x1) * (x2-x1));
}

__global__ void distanceKernel(float *d_out, float *d_in, float ref) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;

    float x = d_in[i];

    d_out[i] = distance(x, ref);

    printf("i = %2d: dist from %f to %f is %f.\n", i, ref, x, d_out[i]);
}

int main() {
    float ref = 0.5f;
    float *in = nullptr;
    float *out = nullptr;

    cudaMallocManaged(&in, N * sizeof(float));
    cudaMallocManaged(&out, N * sizeof(float));

    for (int i = 0; i < N; i++) {
        in[i] = scale(i, N);
    }

    distanceKernel<<<N / THREADS_PER_BLOCK, THREADS_PER_BLOCK>>>(out, in, ref);

    cudaDeviceSynchronize();

    cudaFree(in);
    cudaFree(out);

    return 0;
}