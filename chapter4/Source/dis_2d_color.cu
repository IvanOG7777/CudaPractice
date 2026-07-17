//
// Created by elder on 7/16/2026.
//

#include <iostream>
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

const char *vertexShader = R"GLSL(
    #version 330 core

    layout (location = 0) in vec3 aPos;

    uniform vec3 aColor;

    out vec4 vertexColor;

     void main () {
        gl_position vec4(aPos, 1.0);
        vertexColor = vec4(aColor, 1.0);
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

    std::cout << "BX: " << bx << std::endl;
    std::cout << "BY: " << by << std::endl;

    return 0;


    GLuint VAO = 0, VBO = 0;

    glBindVertexArray(VAO);
    glBindBuffer(1, VBO);

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

    if (!gladLoadGLLoader(
        reinterpret_cast<GLADloadproc>(glfwGetProcAddress))) {
        std::cerr << "Failed to initialize GLAD\n";
        glfwTerminate();
        return -1;
    }
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    while (!glfwWindowShouldClose(window)) {
        glClear(GL_COLOR_BUFFER_BIT);

        // kernel2d<<<>>>(device_out, W, H, {0.0f, 0.0f});

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwTerminate();
    return 0;
}
