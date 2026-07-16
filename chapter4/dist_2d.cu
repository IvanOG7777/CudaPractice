//
// Created by elder on 7/16/2026.
//

#include <iostream>

constexpr int W = 500;
constexpr int H = 500;
constexpr int TX = 32;
constexpr int TY = 32;

__global__ void distanceKernel(float *d_out, int width, int height, float2 pos) {
    //calculate current row/col
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    int  i = row * width + col; // calculate index

    if (col >= width || row >= height) return; // if col or row is bigger than set block and threads retunr out of call

    // distance formula
    auto distance = std::sqrtf((static_cast<float>(col) - pos.x)*(static_cast<float>(col) - pos.x) + (static_cast<float>(row) - pos.y) * (static_cast<float>(row) - pos.y));

    //assign to array
    d_out[i] = distance;

    printf("i = %d: d_out[i]: %.3f\n", i, d_out[i]);
}

int main() {

    dim3 blockSize(TX, TY); // creates a block with TX*TX threads. in this case 1024 threads
    auto bx = (W +blockSize.x - 1)/blockSize.x; // calculates to 16
    auto by = (H +blockSize.y - 1)/blockSize.y; // calculates to 16

    dim3 gridSize(bx, by); //clears a 16x16 block grid of TX*TY threads each

    float *out = static_cast<float *>(malloc(W*H*sizeof(float)));
    float *d_out = nullptr;
    cudaMalloc(&d_out, H*W*sizeof(float));

    //<<<256, 1024>>> total of 262144 threads
    distanceKernel<<<gridSize, blockSize>>>(d_out, W, H, {0.0f, 0.0f});

    cudaDeviceSynchronize();

    cudaMemcpy(out, d_out, H*W*(sizeof(float)), cudaMemcpyDeviceToHost);

    cudaFree(d_out);
    free(out);
}