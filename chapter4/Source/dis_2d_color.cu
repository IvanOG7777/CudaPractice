//
// Created by elder on 7/16/2026.
//

#include <iostream>
#include <random>

#include <cuda_runtime.h>
#include <curand_kernel.h>

#include <glad/glad.h>
#include <GLFW/glfw3.h>

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

__device__ float2 generatePosition(curandState *state, float2 origin, float radius) {
    float randVal = curand_uniform(state); // get rand number from 0.0 to 1.0

    float angle = randVal * 2.0f * 3.141592653589793f;

    float2 position;

    position.x = origin.x + radius * std::cosf(angle);
    position.y = origin.y + radius * std::sinf(angle);

    return position;
}

__global__ void kernelMakePosition(float2 *d_out, int width, int height, float2 origin, unsigned long long seed) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (col >= width || row >= height) return;

    int i = row * width + col;

    curandState state; // global state
    curand_init(seed, i, 0, &state); // local state per thread

    d_out[i] = generatePosition(&state, origin, 0.5f);

    printf("i = %d, d_out[i] = (%.2f, %.2f)\n", i, d_out[i].x, d_out[i].y);
}

const char *vertexShader = R"GLSL(
    #version 330 core

    layout (location = 0) in vec2 aPos;

    uniform vec3 uColor;

    out vec4 vertexColor;

     void main () {
        gl_Position = vec4(aPos, 0.0, 1.0);
        gl_PointSize = 2.0;
        vertexColor = vec4(uColor, 1.0);
     }
)GLSL";

const char *fragmentShader = R"GLSL(
    #version 330 core

    in vec4 vertexColor;
    out vec4 FragColor;

    void main() {
        FragColor = vertexColor;
    }
)GLSL";

int main() {

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    if (!glfwInit()) {
        std::cerr << "GLFW INIT ERROR \n";
        return -1;
    }

    GLFWwindow *window = glfwCreateWindow(W, H, "CUDA 2D Color", nullptr, nullptr);

    if (window == nullptr) {
        std::cerr << "WINDOW IS NULLPTR" << std::endl;
        glfwTerminate();
    }
    glfwMakeContextCurrent(window);
    if (!gladLoadGLLoader((GLADloadproc) glfwGetProcAddress)) {
        std::cerr << "GLAD INIT ERROR\n";
        return -1;
    }

    // device in and out array pointers
    uchar4 *device_out_color = nullptr;
    float2 *device_out_position = nullptr;

    // allocation of memory
    uchar4 *host_out_color = static_cast<uchar4 *>(malloc(H * W * sizeof(uchar4)));
    float2 *host_out_position = static_cast<float2 *>(malloc(H * W * sizeof(float2)));

    cudaMalloc(&device_out_color, H * W * sizeof(uchar4));
    cudaMalloc(&device_out_position, H * W * sizeof(float2));

    dim3 blockSize(TX, TY);

    auto bx = (W + blockSize.x - 1) / blockSize.x;
    auto by = (H + blockSize.y - 1) / blockSize.y;

    dim3 gridSize(bx,by);


    GLuint VAO = 0, VBO = 0;

    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);

    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);

    glBufferData(GL_ARRAY_BUFFER, W*H*sizeof(float2), host_out_position, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(float2), (void*)0);

    glEnableVertexAttribArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    auto vs = glCreateShader(GL_VERTEX_SHADER);
    auto fs = glCreateShader(GL_FRAGMENT_SHADER);

    glShaderSource(vs, 1, &vertexShader, nullptr);
    glCompileShader(vs);

    glShaderSource(fs, 1, &fragmentShader, nullptr);
    glCompileShader(fs);

    auto program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);

    glDeleteShader(vs);
    glDeleteShader(fs);


    GLuint uColorLoc = glGetUniformLocation(program, "uColor");


    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    while (!glfwWindowShouldClose(window)) {
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(program);

        kernelMakePosition<<<gridSize, blockSize>>>(device_out_position, W, H, {0.0f, 0.0f}, 1234ULL);
        kernel2d<<<gridSize, blockSize>>>(device_out_color, W, H, {0.0f, 0.0f});

        cudaDeviceSynchronize();

        cudaMemcpy(host_out_color, device_out_color, H*W*sizeof(uchar4), cudaMemcpyDeviceToHost);
        cudaMemcpy(host_out_position, device_out_position, H*W*sizeof(float2), cudaMemcpyDeviceToHost);

        glUniform3f(uColorLoc, )



        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwTerminate();
    return 0;
}
