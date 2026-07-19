//
// Created by elder on 7/18/2026.
//

#include <iostream>

#include <glad/glad.h>
#include <GLFW/glfw3.h>

constexpr int TX = 32;
constexpr int TY = 32;
constexpr int W = 1920;
constexpr int H = 1080;

constexpr float LENGTH = 5.0f;

constexpr float DT = 0.0005f;

constexpr float FINAL_TIME = 10.0f;

constexpr float DAMPING = 0.1f;

__device__ float2 pixelToState(int x, int y, int width, int height, float length) {
    float2 position{};

    float normalX = (static_cast<float>(x) - 0.0f) / (static_cast<float>(width) - 1.0f);
    float normalY = (static_cast<float>(y) - 0.0f) / (static_cast<float>(height) - 1.0f);

    // maps x and y to be between -length and length
    float mappedX = -length + normalX * (length - (-length));
    float mappedY = -length + normalY * (length - (-length));

    position.x = mappedX;
    position.y = mappedY;

    return position;
}

__device__ float2 step(float position, float velocity, float damping, float dt) {
    float2 newValues{};

    float newPosition = position + dt * velocity;
    float newVelocity = velocity + dt * (-position - (2 * damping * velocity));

    newValues.x = newPosition;
    newValues.y = newVelocity;

    return newValues;
}

__device__ float2 oscillator(float initPosition, float initVelocity, float damping, float dt, float finalTime) {

    float currentPosition = initPosition;
    float currentVelocity = initVelocity;
    float2 stepVals = {currentPosition, currentVelocity};
    float i = 0.0f;
    while (i < finalTime) {
        stepVals = step(currentPosition, currentVelocity, damping, dt);
        currentPosition = stepVals.x;
        currentVelocity = stepVals.y;

        i += dt;
    }

    return stepVals;
}

__device__ unsigned char clip (int n) { // used to rbg channel intensity
    return n > 255 ? 255 : (n < 0 ? 0 : n); // nested ternery operator return 255, 0 or n
}

__global__ void stabilityKernel(uchar4 *d_out, int width, int height) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (col >= width || row >= height) return;

    int i = row * width + col;

    float2 initState = pixelToState(col,row, width, height, LENGTH);

    float2 pos = oscillator(initState.x, initState.y, DAMPING, DT, FINAL_TIME);

    float dist_0 = std::sqrt(initState.x * initState.x + initState.y * initState.y);
    if (dist_0 == 0.0f) dist_0 = 0.01f; // in case of divide by 0 case at center

    float dist_f = std::sqrt(pos.x * pos.x + pos.y * pos.y);
    float dist_r = dist_f / dist_0;

    d_out[i].x = clip(dist_r * 255);
    d_out[i].y = ((col == width/2) || (row == height/2)) ? 255 : 0;
    d_out[i].z = clip((1/dist_r) * 255);
    d_out[i].w = 255;
}

int main() {

    if (!glfwInit()) {
        std::cerr << "GLFW INIT ERROR \n";
        return -1;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow *window = glfwCreateWindow(W, H, "CUDA 2D Color", nullptr, nullptr);

    if (window == nullptr) {
        std::cerr << "WINDOW IS NULLPTR" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
    if (!gladLoadGLLoader((GLADloadproc) glfwGetProcAddress)) {
        std::cerr << "GLAD INIT ERROR\n";
        return -1;
    }

    // device pointer
    uchar4 *device_out_color = nullptr;


    dim3 blockSize(TX, TY);

    auto bx = (W + blockSize.x - 1) / blockSize.x;
    auto by = (H + blockSize.y - 1) / blockSize.y;

    dim3 gridSize(bx, by);

    GLuint VAO = 0, VBO = 0, PBO = 0, tex = 0;

    glGenBuffers(1, &PBO);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, PBO); // bind buffer to "unpack" data from cpu to gpu
    glBufferData(GL_PIXEL_UNPACK_BUFFER, W*H*sizeof(uchar4), nullptr, GL_DYNAMIC_DRAW); // note that buffer data will be unpacked. We are sending off W*H*sizeof(uchar4) bytes. No init data and we are dynamically drawing
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0); // unbind buffer

    return 0;
}
