//
// Created by elder on 7/15/2026.
//
#include <iostream>

constexpr int N = 64;
constexpr int THREADS_PER_BLOCK = 32;

float scale (int i, int n) {
    return static_cast<float>(i) / static_cast<float>(n - 1);
}

__device__ float distance(float x1, float x2) {
    return std::sqrtf((x2 - x1) * (x2 - x1));
}

__global__ void distanceKernel(float *out, float *in, float ref) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    float x = in[i];

    out[i] = distance(x, ref);
}

void distanceArray(float *out, float *in, float ref, int length) {

    float *device_out = nullptr;
    float *device_in = nullptr;

    cudaMalloc(&device_in, length * sizeof(float));
    cudaMalloc(&device_out, length * sizeof(float));

    cudaMemcpy(device_in, in, length * sizeof(float), cudaMemcpyHostToDevice);

    distanceKernel<<<length / THREADS_PER_BLOCK, THREADS_PER_BLOCK>>>(device_out, device_in, ref);

    cudaMemcpy(out, device_out, length * sizeof(float), cudaMemcpyHostToDevice);

    cudaFree(device_in);
    cudaFree(device_out);
}

int main() {

}