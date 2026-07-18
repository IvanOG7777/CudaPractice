//
// Created by elder on 7/16/2026.
//

#include <iostream>
#include <random>

#include <glad/glad.h>
#include <GLFW/glfw3.h>

#include <cuda_runtime.h>
#include <curand_kernel.h>
#include <cuda_gl_interop.h>


constexpr int TX = 32, TY = 32;
constexpr int W = 500, H = 500;

__device__ unsigned char clip(int n) {
    return n > 255 ? 255 : (n < 0 ? 0 : n); // nested ternery operator return 255, 0 or n
}

__global__ void kernel2d(uchar4 *d_out, int width, int height, float2 pos) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (col >= width || row >= height) return;

    int i = row * width + col;

    // calculate current distance from origin point
    float distance = std::sqrtf((col - pos.x) * (col - pos.x) + (row - pos.y) * (row - pos.y));

    const auto intensity = clip(static_cast<int>(255 - distance)); // clip its brightness intensity (clip only called on device)

    // pass intensity on red and green channels only (makes yellow)
    d_out[i].x = intensity;
    d_out[i].y = intensity;
    d_out[i].z = 0;
    d_out[i].w = 255;
}

// shaders
const char *vertexShader = R"GLSL(
    #version 330 core

    layout (location = 0) in vec2 aPos;
    layout (location = 1) in vec2 aTexCoord;

    out vec2 vTexCoord;

     void main () {
        gl_Position = vec4(aPos, 0.0, 1.0);
        vTexCoord = aTexCoord;
     }
)GLSL";

const char *fragmentShader = R"GLSL(
    #version 330 core

    in vec2 vTexCoord;
    out vec4 FragColor;

    uniform sampler2D uTex;

    void main() {
        FragColor = texture(uTex, vTexCoord);
    }
)GLSL";

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

    dim3 gridSize(bx,by);

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

    GLuint PBO = 0, tex = 0, VAO = 0, VBO = 0;

    glGenBuffers(1, &PBO);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, PBO);
    glBufferData(GL_PIXEL_UNPACK_BUFFER, W*H*sizeof(uchar4), nullptr, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);

    cudaGraphicsResource *cuda_pbo = nullptr;
    cudaGraphicsGLRegisterBuffer(&cuda_pbo, PBO, cudaGraphicsRegisterFlagsWriteDiscard);

    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glBindTexture(GL_TEXTURE_2D, 0);

    float coordinates[] = {
        -1.0f, -1.0f,  0.0f, 1.0f, // bottom-left
        1.0f, -1.0f,  1.0f, 1.0f, // bottom-right
        -1.0f,  1.0f,  0.0f, 0.0f, // top-left
        1.0f,  1.0f,  1.0f, 0.0f, // top-right
    };

    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);

    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(coordinates), coordinates, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)(2 * sizeof(float)));
    glBindVertexArray(0);

    glUseProgram(program);
    glUniform1i(glGetUniformLocation(program, "uTex"), 0);
    glUseProgram(0);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);



    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    while (!glfwWindowShouldClose(window)) {

        size_t numBytes = 0;
        cudaGraphicsMapResources(1, &cuda_pbo, nullptr); // gives cuda vbo temp access to opengl pbo, allows cuda to write into it
        cudaGraphicsResourceGetMappedPointer((void**)&device_out_color, &numBytes, cuda_pbo); // get device pointer to map opengl pbo memory to it

        kernel2d<<<gridSize, blockSize>>>(device_out_color, W, H, { W/ 2.0f, H/ 2.0f}); // run kernel about window origin

        cudaGraphicsUnmapResources(1, &cuda_pbo, nullptr); // returns ownership of memory back to opengl

        // rebind buffer and textures and let opengl render
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, PBO);
        glBindTexture(GL_TEXTURE_2D, tex);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);

        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(program);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, tex);
        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    cudaGraphicsUnregisterResource(cuda_pbo);
    glDeleteBuffers(1, &PBO);
    glDeleteBuffers(1, &VBO);
    glDeleteVertexArrays(1, &VAO);
    glDeleteTextures(1, &tex);
    glDeleteProgram(program);

    glfwTerminate();
    return 0;
}
