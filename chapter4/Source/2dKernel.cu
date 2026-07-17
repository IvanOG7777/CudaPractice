//
// Created by elder on 7/16/2026.
//

#include  <iostream>

constexpr int TX = 32;
constexpr int TY = 32;
constexpr int W = 500;
constexpr int H = 500;

__global__ void kernel2D(float *d_out, int height, int width, float2 pos) {
    const int col = blockIdx.x * blockDim.x + threadIdx.x;
    const int row = blockIdx.y * blockDim.y + threadIdx.y;

    const int i = row * width + col;

    if (col >= width || row >= height) return;

    d_out[i] = (pos.x * static_cast<float>(col)) + (pos.y * static_cast<float>(row));

    // printf("i = %d, value at d_out[i] is: %.2f\n", i, d_out[i]);
}

__global__ void kernel2DColor(uchar4 *d_out, int height, int width) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    int i = row * width + col;

    if (col >= width || row >= height) return;

    float horizontalPercentage = static_cast<float>(col) / static_cast<float>(width-1); // will go from 0-1 on the horizontal axis
    float verticalPercentage = static_cast<float>(row) / static_cast<float>(height-1); // will go from 0-1 on the vertical axis

    d_out[i].x = static_cast<unsigned char>(255*horizontalPercentage);

    d_out[i].y = static_cast<unsigned char>(255*verticalPercentage);

    d_out[i].z = static_cast<unsigned char>(255*horizontalPercentage+verticalPercentage);

    d_out[i].w = 255;

    printf("i = %d, value at d_out[i] is: (%d , %d , %d)\n", i, d_out[i].x, d_out[i].y, d_out[i].z);
}

int main() {
    dim3 blockSize(TX, TY);

    int bx = (W + blockSize.x - 1)/blockSize.x;
    int by = (H + blockSize.y - 1)/blockSize.y;

    dim3 gridSize(bx, by);

    float *host_out = static_cast<float*>(malloc(H*W*sizeof(float)));
    float *device_out = nullptr;
    cudaMalloc(&device_out, H*W*sizeof(float));

    uchar4 *host_out_color = static_cast<uchar4 *>(malloc(W*H*sizeof(uchar4)));
    uchar4 *device_out_color = nullptr;
    cudaMalloc(&device_out_color, W*H*sizeof(uchar4));

    float2 position = {1.0 ,2.0f};

    kernel2D<<<gridSize, blockSize>>>(device_out, H, W, position);

    kernel2DColor<<<gridSize, blockSize>>>(device_out_color, H, W);

    cudaDeviceSynchronize();

    cudaMemcpy(host_out, device_out, H*W*sizeof(float), cudaMemcpyDeviceToHost);
    cudaMemcpy(host_out_color, device_out_color, H*W*sizeof(uchar4), cudaMemcpyDeviceToHost);

    cudaFree(device_out);
    cudaFree(device_out_color);
    free(host_out);
    free(host_out_color);

    return 0;
}
