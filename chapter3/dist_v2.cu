//
// Created by elder on 7/15/2026.
//

#include <iostream>
#include "kernel.h"

constexpr int THREADS_PER_BLOCK = 32;

__device__ float distance(float x1, float x2) {
    return std::sqrtf((x2-x1) * (x2 - x1));
}

__global__ void distanceKernel(float *d_out, float *d_in, float ref) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;

    const float x = d_in[i];

    d_out[i] = distance(x, ref);

    printf("i = %2d: dist from %f to %f is %f.\n", i, ref, x, d_out[i]);
}

void distanceArray(float *out, float *in, float ref, int length) {

    float *d_in = nullptr;
    float *d_out = nullptr;

    cudaMalloc(&d_in, length * sizeof(float));
    cudaMalloc(&d_out, length * sizeof(float));

    cudaMemcpy(d_in, in, length * sizeof(float), cudaMemcpyHostToDevice);

    distanceKernel<<<length / THREADS_PER_BLOCK, THREADS_PER_BLOCK>>>(d_out, d_in, ref);

    cudaMemcpy(out, d_out, length * sizeof(float), cudaMemcpyDeviceToHost);

    cudaFree(d_in);
    cudaFree(d_out);

}

int main() {
    int length = 64;
    float ref = 0.5f;
    float *out = static_cast<float *>(malloc(length * sizeof(float)));
    float *in = static_cast<float *>(malloc(length * sizeof(float)));

    for (int i = 0; i < length; i++) {
        in[i] = static_cast<float>(i) / static_cast<float>(length - 1);
    }

    distanceArray(out, in, ref, length);

    std::free(in);
    std::free(out);
}
