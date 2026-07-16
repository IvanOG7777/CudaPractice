//
// Created by elder on 7/15/2026.
//

#include <iostream>

constexpr int N = 64;
constexpr int THREADS_PER_BLOCK = 32;

__device__ float scale(int i, int n) {
    return static_cast<float>(i) / static_cast<float>(n - 1);
}

__device__ float distance(float x1, float x2) {
    return sqrtf((x2 - x1) * (x2 - x1));
}


__global__ void distanceKernel(float *d_out, float ref, int length) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    const float x = scale(i, length);
    d_out[i] = distance(x, ref);
    printf("i = %2d: dist from %f to %f is %f.\n", i, ref, x, d_out[i]);
}

int main() {
    float ref = 0.5f;
    float *d_out = 0;

    cudaMalloc(&d_out, N * sizeof(float));

    distanceKernel<<<N / THREADS_PER_BLOCK, THREADS_PER_BLOCK>>>(d_out, ref, N);

    cudaFree(d_out);
    return 0;
}
