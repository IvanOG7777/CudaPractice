//
// Created by elder on 7/20/2026.
//

#include <iostream>

#include <glad/glad.h>
#include "GLFW/glfw3.h"

constexpr int TX = 32, TY = 32;
constexpr int W = 1920, H = 1080;

__device__ unsigned char clip (int n) {
    return n > 255 ? 255 : (n < 0 ? 0 : n);
}

__device__ float distance(int x, int y) {
    return std::sqrtf(static_cast<float>(x * x) - static_cast<float>(y *y));
}

__global__ void kernelFlashLight(uchar4 *d_out, int width, int height) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (col >= width || row >= height) return;

    int i = row * width + col;

    float currentDistance = distance(col, row);

    unsigned char intensity = clip (static_cast<int>(255 - currentDistance));

    d_out[i].x = intensity;
    d_out[i].y = 0;
    d_out[i].z = intensity;
    d_out[i].w = 255;
}

struct SceneState {
    float2 *mousePosition;
};

// I would need a bool for setPixel user a picks storing the fact that the specific pixel has been chosen
// I think I would need to pass this this the kernel as well or at least the bool for the specific pixel

void cursorButtonCallback(GLFWwindow *window, int button, int action, int mods) {

}

void cursorPositionCallback(GLFWwindow *window, double posX, double posY) {
    auto *state = static_cast<SceneState *>(glfwGetWindowUserPointer(window));

    state->mousePosition->x = static_cast<float>(posX);
    state->mousePosition->y = static_cast<float>(posY);
}

int main() {
    return 0;
}