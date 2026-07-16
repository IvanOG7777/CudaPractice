//
// Created by elder on 7/15/2026.
//
#include <iostream>

//changing THREADS_PER_BLOCK's value

// Similar to changedNumOfElements only Block * THREADS_PER_BLOCK of elements is computed

constexpr int THREADS_PER_BLOCK = 66;

float scale (int i, int n) {
    return static_cast<float>(i) / static_cast<float>(n - 1);
}

__device__ float distance(float x1, float x2) {
    return std::sqrtf((x2 - x1) * (x2 - x1));
}

__global__ void distanceKernel(float *d_out, float *d_in, float ref) {
    unsigned i = blockIdx.x * blockDim.x + threadIdx.x;

    float x = d_in[i];

    d_out[i] = distance(x, ref);

    printf("i = %2d: dist from %f to %f is %f.\n", i, ref, x, d_out[i]);
}

// function called by cpu
void distanceArray(float *host_out, float *host_in, float ref, int length) {

    float *device_out = nullptr;
    float *device_in = nullptr;

    // allocate device memory
    cudaMalloc(&device_in, length * sizeof(float));
    cudaMalloc(&device_out, length * sizeof(float));

    std:: cout << "Bytes allocated: " << length * sizeof(float) << std:: endl;

    cudaMemcpy(device_in, host_in, length * sizeof(float), cudaMemcpyHostToDevice); // copy array from host to gpu

    std:: cout << "Blocks: " << length/THREADS_PER_BLOCK << std:: endl;
    std:: cout << "Threads: " << THREADS_PER_BLOCK << std:: endl;

    distanceKernel<<<length / THREADS_PER_BLOCK, THREADS_PER_BLOCK>>>(device_out, device_in, ref); // run function of device arrays

    cudaDeviceSynchronize();

    cudaMemcpy(host_out, device_out, length * sizeof(float), cudaMemcpyDeviceToHost); // copy from gpu to cpu

    // free cuda memory
    cudaFree(device_in);
    cudaFree(device_out);
}

int main() {

    int length = 4096;
    float ref = 0.5f;
    float *in = static_cast<float *>(malloc(length * sizeof(float)));
    float *out = static_cast<float *>(malloc(length * sizeof(float)));

    for (int i = 0; i < length; i++) {
        in[i] = scale(i, length);
    }

    distanceArray(out, in, ref, length);
    std:: cout << std:: endl;
    std:: cout << std:: endl;
    std:: cout << std:: endl;

    for (int i = 0; i < length; i++) {
        std:: cout << "i: " << i << ", " << out[i] << std:: endl;
    }

    free(in);
    free(out);


}