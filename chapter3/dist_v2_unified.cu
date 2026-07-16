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

// function can only be called and ran on the gpu
// give it two numbers returns dist
__device__ float distance(float x1, float x2) {
    return std::sqrtf((x2-x1) * (x2-x1));
}

// function that can be called from the host cpu and executed on device gpu
__global__ void distanceKernel(float *d_out, float *d_in, float ref) {
    // think of this block as a for loop, where each i is a place in gpu memory than can access the data at d_out[i]
    const int i = blockIdx.x * blockDim.x + threadIdx.x; // get our current thread index

    float x = d_in[i]; // get val from d_in

    d_out[i] = distance(x, ref); // call dist on the gpu on x and ref

    printf("i = %2d: dist from %f to %f is %f.\n", i, ref, x, d_out[i]); //print output
}

int main() {
    float ref = 0.5f;

    float *in = nullptr;
    float *out = nullptr;

    // Allocate N * sizeof(float) bytes of memory for both cpu and gpu to use
    cudaMallocManaged(&in, N * sizeof(float));
    cudaMallocManaged(&out, N * sizeof(float));

    // inits in to scale(1, N)
    for (int i = 0; i < N; i++) {
        in[i] = scale(i, N);
    }

    // call function and run on 2 block, with 32 threads on each
    distanceKernel<<<N / THREADS_PER_BLOCK, THREADS_PER_BLOCK>>>(out, in, ref);

    cudaDeviceSynchronize();// wait for gpu to finish work

    // free memory
    cudaFree(in);
    cudaFree(out);

    return 0;
}