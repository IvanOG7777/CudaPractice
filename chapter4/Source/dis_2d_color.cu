//
// Created by elder on 7/16/2026.
//

#include <iostream>
#include <GLFW/glfw3.h>

#include <glm/glm/glm.hpp>
#include <glm/glm/gtc/type_ptr.hpp>

constexpr int TX = 32, TY = 32;
constexpr int W = 500, H = 500;

__device__ char clip(int n) {
    return n > 255 ? 255 : (n < 0 ? 0 : n); // nested ternery operator return 255, 0 or n
}

__global__ void kernel2d(uchar4 *d_out, int width, int height, float2 pos) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    int i = row * width + col;

    if (col >= width || row >= height) return;

    auto distance = std::sqrtf((col - pos.x) * (col - pos.x) + (row - pos.y) * (row - pos.y));

    const auto intensity = clip(static_cast<int>(255 - distance));

    d_out[i].x = intensity;
    d_out[i].y = intensity;
    d_out[i].z = 0;
    d_out[i].w = 255;
}

int main() {

    if (!glfwInit()) {
        return -1;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow *window = glfwCreateWindow(W, H, "CUDA 2D Color", nullptr, nullptr);

    if (window == nullptr) {
        std:: cerr << "WINDOW IS NULLPTR" << std:: endl;
        glfwTerminate();
    }

    glfwMakeContextCurrent(window);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    while (!glfwWindowShouldClose(window)) {
        glClear(GL_COLOR_BUFFER_BIT);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwTerminate();
    return 0;
}