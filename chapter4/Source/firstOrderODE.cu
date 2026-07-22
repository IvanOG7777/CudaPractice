//
// Created by elder on 7/21/2026.
//

#include <iostream>

#include <glad/glad.h>
#include <GLFW/glfw3.h>

constexpr int TX = 32;
constexpr int TY = 32;
constexpr int W = 1920;
constexpr int H = 1080;

constexpr float LENGTH = 5.0f;

constexpr float DT = 0.005f;

constexpr float FINAL_TIME = 10.0f;

// or system from text book
constexpr float DAMPING = 2.0f;

__global__ void kernelSimpleOscillator(uchar4 *d_out, int width, int height) {

}

__global__ void kernelDampedOscillator(uchar4 *d_out, int width, int height) {

}

__global__ void kernelUnstableOscillator(uchar4 *d_out, int width, int height) {

}

__global__ void kernelStableNode(uchar4 *d_out, int width, int height) {

}

__global__ void kernelUnstableNode(uchar4 *d_out, int width, int height) {

}

__global__ void kernelNonlinearPendulum(uchar4 *d_out, int width, int height) {

}


int main() {

    return 0;
}