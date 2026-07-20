//
// Created by elder on 7/18/2026.
//

#include <iostream>

#include <glad/glad.h>
#include <GLFW/glfw3.h>

#include <cuda_runtime.h>
#include <curand_kernel.h>
#include <cuda_gl_interop.h>

constexpr int TX = 32;
constexpr int TY = 32;
constexpr int W = 1920;
constexpr int H = 1080;

constexpr float LENGTH = 5.0f;

constexpr float DT = 0.005f;

constexpr float FINAL_TIME = 10.0f;

// or system from text book
constexpr float DAMPING = 2.0f;

 __device__ float2 pixelToState(int x, int y, int width, int height, float length) {
    float2 position{};

    float normalX = (static_cast<float>(x) - 0.0f) / (static_cast<float>(width) - 1.0f);
    float normalY = (static_cast<float>(y) - 0.0f) / (static_cast<float>(height) - 1.0f);

    // maps x and y to be between -length and length
    float mappedX = -length + normalX * (length - (-length));
    float mappedY = -length + normalY * (length - (-length));

    // move osculated position with mouse
    // mappedX -= cursorPosition.x;
    // mappedY -= cursorPosition.y;

    position.x = mappedX;
    position.y = mappedY;

    return position;
}

__device__ float2 step(float position, float velocity, float damping, float dt) {
    float2 newValues{};

    float newPosition = position + dt * velocity;
    // float newVelocity = velocity + dt * (-position - (2 * damping * velocity));

    // van der pol equation. constant 1 is the P variable from the equation
    float newVelocity = velocity + dt * (damping * (0.2f - (position * position)) * velocity - position);

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

__global__ void stabilityKernel(uchar4 *d_out, int width, int height, float2 position) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (col >= width || row >= height) return;

    int i = row * width + col;

    float normalPosX = (position.x - 0.0f) / (static_cast<float>(width) - 1.0f);
    float normalPosY = (position.y - 0.0f) / (static_cast<float>(height) - 1.0f);

    float mappedPosX = -LENGTH + normalPosX * (LENGTH - (-LENGTH));
    float mappedPosY = -LENGTH + normalPosY * (LENGTH - (-LENGTH));

    float2 initState = pixelToState(col,row, width, height, LENGTH);

    float2 pos = oscillator(initState.x, initState.y, DAMPING, DT, FINAL_TIME);

    float dist_0 = std::sqrt((initState.x * initState.x) + (initState.y * initState.y));

    float dist_f = std::sqrt(pos.x * pos.x + pos.y * pos.y);
    float dist_r = dist_f / dist_0;

    d_out[i].x = clip(dist_r * 255);
    d_out[i].y = ((col == width/2) || (row == height/2)) ? 255 : 0; // does the brightness of the cross across screen
    d_out[i].z = clip((1/dist_r) * 255);
    d_out[i].w = 255;
}

const char *vertexShader = R"GLSL(
    #version 330 core

    layout (location = 0) in vec2 aPos;
    layout (location = 1) in vec2 aTexCoord;

    out vec2 uTexCoord;

    void main () {
        gl_Position = vec4(aPos, 0.0, 1.0);
        uTexCoord = aTexCoord;
    }
)GLSL";

const char *fragmentShader = R"GLSL(
    #version 330 core

    in vec2 uTexCoord;
    out vec4 FragColor;

    uniform sampler2D uTex;

    void main () {
        FragColor = texture(uTex, uTexCoord);
    }
)GLSL";

struct SceneState {
    float2 *cursorPositon;
};

void cursorPositionCallback(GLFWwindow *window, double posX, double posY) {
    auto *state = static_cast<SceneState *>(glfwGetWindowUserPointer(window));

    state->cursorPositon->x = static_cast<float>(posX);
    state->cursorPositon->y = static_cast<float>(posY);
}

int main() {
    if (!glfwInit()) {
        std::cerr << "GLFW INIT ERROR \n";
        return -1;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow *window = glfwCreateWindow(W, H, "Stability Oscillator", nullptr, nullptr);

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

    cudaGraphicsResource *cudaPBO = nullptr;
    cudaGraphicsGLRegisterBuffer(&cudaPBO, PBO, cudaGraphicsRegisterFlagsWriteDiscard);

    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glBindTexture(GL_TEXTURE_2D, 0); // unbind tex

    float coordinates[] = {
        -1.0f, -1.0f, 0.0f, 1.0f,
        1.0f, -1.0f, 1.0f, 1.0f,
        -1.0f,  1.0f,  0.0f, 0.0f,
        1.0f,  1.0f,  1.0f, 0.0f,
    };

    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);

    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(coordinates), coordinates, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)0); // read first two floats per vertex (4 float in each). no offset, send to aPos
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)(2 * sizeof(float))); // read last two floats per vertex (4 floats in each), offset by 8 bytes, send to TexCoord
    glBindVertexArray(0);

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

    glUseProgram(program);
    glUniform1i(glGetUniformLocation(program, "uTex"), 0);
    glUseProgram(0);

    SceneState state{};
    float2 cursorPosition = {W/2.0f, H/2.0f};
    state.cursorPositon = &cursorPosition;

    glfwSetWindowUserPointer(window, &state);
    glfwSetCursorPosCallback(window, cursorPositionCallback);

    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    while (!glfwWindowShouldClose(window)) {

        size_t numBytes = 0;
        cudaGraphicsMapResources(1, &cudaPBO, nullptr);
        cudaGraphicsResourceGetMappedPointer((void**)&device_out_color, &numBytes, cudaPBO);

        stabilityKernel<<<gridSize, blockSize>>>(device_out_color, W, H, cursorPosition);

        cudaGraphicsUnmapResources(1, &cudaPBO, nullptr);

        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, PBO);
        glBindTexture(GL_TEXTURE_2D, tex); // bind tex to be a 2d texture
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0); // unbind pbo

        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(program); // reuse program
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, tex);
        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    cudaGraphicsUnregisterResource(cudaPBO);
    glDeleteBuffers(1, &PBO);
    glDeleteBuffers(1, &VBO);
    glDeleteVertexArrays(1, &VAO);
    glDeleteTextures(1, &tex);
    glDeleteProgram(program);

    glfwTerminate();

    return 0;
}
