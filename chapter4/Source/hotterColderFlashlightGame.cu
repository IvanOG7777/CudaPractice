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

float2 pickPixel(int width, int height, float2 position) {
    float normalX = (position.x - 0.0f) / (static_cast<float>(width) - 1.0f);
    float normalY = (position.y - 0.0f) / (static_cast<float>(height) - 1.0f);

    return {normalX, normalY};
}

struct SceneState {
    float2 *currentMousePosition;
    float2 *playerAMousePosition;
    bool pixelPicked;
};

// I would need a bool for setPixel user a picks storing the fact that the specific pixel has been chosen
// I think I would need to pass this the kernel as well or at least the bool for the specific pixel

void cursorButtonCallback(GLFWwindow *window, int button, int action, int mods) {
    auto *state = static_cast<SceneState *>(glfwGetWindowUserPointer(window));
    auto *position = state->currentMousePosition;

    if (state->pixelPicked == false && button == GLFW_MOUSE_BUTTON_LEFT && action == GLFW_PRESS) {
        pickPixel(W, H, *position);
        state->pixelPicked = true;
    }

}

void cursorPositionCallback(GLFWwindow *window, double posX, double posY) {
    auto *state = static_cast<SceneState *>(glfwGetWindowUserPointer(window));

    if (state->pixelPicked == false) {
        state->playerAMousePosition->x = static_cast<float>(posX);
        state->playerAMousePosition->y = static_cast<float>(posY);
    } else {
        state->currentMousePosition->x = static_cast<float>(posX);
        state->currentMousePosition->y = static_cast<float>(posY);
    }
}

int main() {
    return 0;
}