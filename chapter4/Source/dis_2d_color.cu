//
// Created by elder on 7/16/2026.
//

#include <iostream>
#include <random>
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

__global__ void kernelMakePosition(float2 *d_out, int width, int height, float2 origin) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    int i = row * width + col;

    const int radius = 5;

    std::random_device rd;
    std::mt19937 genAngle(rd());

    std::uniform_real_distribution<> angleDist(0.0f, 1.0f);

    auto randAngle = static_cast<float>(angleDist(genAngle));

    float x = radius * std::cosf(randAngle);
    float y = radius * std::sinf(randAngle);

    d_out[i].x = x;
    d_out[i].y = y;

    printf("i = %d, d_out[i] = (%.2f, %.2f)\n", i, d_out[i].x, d_out[i].y);
}

const char *vertexShader = R"GLSL(
    #version 330 core

    layout (location = 0) in vec3 aPos;

    uniform vec3 uColor;

    out vec4 vertexColor;

     void main () {
        gl_position vec4(aPos, 1.0);
        vertexColor = vec4(uColor, 1.0);
     }
)GLSL";

const char *fragmentShader = R"GLSL(
    #version 330 core

    out vec4 FragColor;

    in vertexColor;

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
    uchar4 *device_in = nullptr;
    uchar4 *device_out = nullptr;

    // allocation of memory
    uchar4 *host_in = static_cast<uchar4 *>(malloc(H * W * sizeof(uchar4)));
    uchar4 *host_out = static_cast<uchar4 *>(malloc(H * W * sizeof(uchar4)));

    cudaMalloc(&device_in, H * W * sizeof(uchar4));
    cudaMalloc(&device_out, H * W * sizeof(uchar4));

    dim3 blockSize(TX, TY);

    auto bx = (W + blockSize.x - 1) / blockSize.x;
    auto by = (H + blockSize.y - 1) / blockSize.y;

    dim3 gridSize(bx,by);

    float2 *host_out2 = static_cast<float2 *>(malloc(H * W * sizeof(float2)));
    float2 *device_out2 = nullptr;
    cudaMalloc(&device_out2, H * W * sizeof(float2));

    kernelMakePosition<<<gridSize, blockSize>>>(device_out2, W, H, {0.0f, 0.0f});

    cudaDeviceSynchronize();

    cudaMemcpy(host_out2, device_out2, H*W*sizeof(float2), cudaMemcpyDeviceToHost);

    return 0;


    // GLuint VAO = 0, PBO = 0;
    //
    // auto vs = glCreateShader(GL_VERTEX_SHADER);
    // auto fs = glCreateShader(GL_FRAGMENT_SHADER);
    //
    // glShaderSource(vs, 1, &vertexShader, nullptr);
    // glCompileShader(vs);
    //
    // glShaderSource(fs, 1, &fragmentShader, nullptr);
    // glCompileShader(fs);
    //
    // auto program = glCreateProgram();
    // glAttachShader(program, vs);
    // glAttachShader(program, fs);
    // glLinkProgram(program);
    //
    // glDeleteShader(vs);
    // glDeleteShader(fs);
    //
    // GLuint uColorLoc = glGetUniformLocation(program, "uColor");
    //
    // if (!gladLoadGLLoader(
    //     reinterpret_cast<GLADloadproc>(glfwGetProcAddress))) {
    //     std::cerr << "Failed to initialize GLAD\n";
    //     glfwTerminate();
    //     return -1;
    // }
    //
    //
    // glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    // while (!glfwWindowShouldClose(window)) {
    //     glClear(GL_COLOR_BUFFER_BIT);
    //
    //     kernel2d<<<gridSize, blockSize>>>(device_out, W, H, {0.0f, 0.0f});
    //
    //     cudaDeviceSynchronize();
    //
    //     cudaMemcpy(host_out, device_out, H*W*sizeof(uchar4), cudaMemcpyDeviceToHost);
    //
    //     glGenVertexArrays(1, &VAO);
    //     glGenBuffers(1, &PBO);
    //
    //     glBindVertexArray(VAO);
    //
    //     glBindBuffer(GL_PIXEL_PACK_BUFFER, PBO);
    //
    //     glBufferData(GL_PIXEL_UNPACK_BUFFER, W*H*sizeof(uchar4), &host_out[0], GL_STREAM_DRAW);
    //     glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(uchar4), (void *)0);
    //
    //     glEnableVertexAttribArray(0);
    //
    //     glBindBuffer(GL_ARRAY_BUFFER, 0);
    //     glBindVertexArray(0);
    //
    //     glUniform3f(uColorLoc, 1.0f, 1.0f, 1.0f);
    //
    //
    //     glfwSwapBuffers(window);
    //     glfwPollEvents();
    // }
    //
    // glfwTerminate();
    return 0;
}
