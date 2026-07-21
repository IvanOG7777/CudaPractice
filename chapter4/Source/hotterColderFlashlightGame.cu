//
// Created by elder on 7/20/2026.
//

#include <cuda_gl_interop.h>
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

// position is normalized when passed
__global__ void kernelFlashLight(uchar4 *d_out, int width, int height, float2 pixelPosition) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (col >= width || row >= height) return;

    int i = row * width + col;

    float currentDistance = distance(static_cast<int>(col * pixelPosition.x), static_cast<int>(row * pixelPosition.y);

    unsigned char intensity = clip (static_cast<int>(255 - currentDistance));

    d_out[i].x = intensity;
    d_out[i].y = 0;
    d_out[i].z = intensity;
    d_out[i].w = 255;
}

// normalize screen coordinates between -1 <-> in x/y axis
float2 pickPixel(int width, int height, float2 position) {
    float normalX = (position.x - 0.0f) / (static_cast<float>(width) - 1.0f);
    float normalY = (position.y - 0.0f) / (static_cast<float>(height) - 1.0f);

    return {normalX, normalY};
}

struct SceneState {
    float2 *currentMousePosition;
    float2 *playerAMousePosition;
    float2 *chosenPixelCoordinates;
    bool pixelPicked;
};

// Allows player A to pick pixel, then sets flag to true
void cursorButtonCallback(GLFWwindow *window, int button, int action, int mods) {
    auto *state = static_cast<SceneState *>(glfwGetWindowUserPointer(window));
    auto *playerAPosition = state->playerAMousePosition;

    if (state->pixelPicked == false && button == GLFW_MOUSE_BUTTON_LEFT && action == GLFW_PRESS) {
        *state->chosenPixelCoordinates = pickPixel(W, H, *playerAPosition);
        state->pixelPicked = true;
    }

}

// Gets cursor positon
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

const char *vertexShader = R"GLSL(
    version #330 core

    layout (location = 0) in vec2 aPos;
    layout (location = 1) in vec2 aTexCoord;

    out vec2 uTexCoord;

    void main() {
        gl_Position = vec4(aPos, 0.0, 1.0);
        uTexCoord = aTexCoord;
    }
)GLSL";

const char *fragmentShader = R"GLSL(
    version #330 core

    in vec2 uTexCoord;
    out vec4 FragColor;

    uniform sampler2D uTex;

    void main() {
        FragColor = texture(uTex, uTexCoord);
    }
)GLSL";

int main() {

    if (!glfwInit()) {
        std:: cerr << "FAILED TO LOAD GLFW\n";
        return -1;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow *window  = glfwCreateWindow(W, H, "Hotter Colder Game", nullptr, nullptr);
    if (window == nullptr) {
        std:: cerr << "WINDOW IS NULLPTR\n";
        return -1;
    }

    glfwMakeContextCurrent(window);

    if (!gladLoadGLLoader((GLADloadproc) glfwGetProcAddress)) {
        std::cerr << "GLAD INIT ERROR\n";
        return -1;
    }

    uchar4 *deviceColorOut = nullptr;

    dim3 blockSize(TX, TY);

    auto bx = (W + blockSize.x - 1) / blockSize.x;
    auto by = (H + blockSize.y - 1) / blockSize.y;

    dim3 gridSize(bx, by);

    GLuint PBO = 0, tex = 0, VAO = 0, VBO = 0;

    glGenBuffers(1, &PBO);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, PBO);
    glBufferData(GL_PIXEL_UNPACK_BUFFER, W*H*sizeof(uchar4), nullptr, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);

    cudaGraphicsResource *cudaPBO = nullptr;
    cudaGraphicsGLRegisterBuffer(&cudaPBO, PBO, cudaGraphicsRegisterFlagsWriteDiscard);

    glGenTextures(1, &tex); // create texture object at &tex
    glBindTexture(GL_TEXTURE_2D, tex); // bind tex to be a 2d texture
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glBindTexture(GL_TEXTURE_2D, 0); // unbind tex

    float coordinates[] = {
        // screen position   /  texture positon
        -1.0f, -1.0f,  0.0f, 1.0f, // bottom-left
        1.0f, -1.0f,  1.0f, 1.0f, // bottom-right
        -1.0f,  1.0f,  0.0f, 0.0f, // top-left
        1.0f,  1.0f,  1.0f, 0.0f, // top-right
    };

    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);

    glBindVertexArray(VAO);
    glBindBuffer(GL_VERTEX_ARRAY, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(coordinates), coordinates,GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void *) (2 * sizeof(float)));

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
    float2 playerACursor = {W/2.0f, H/2.0f};
    float2 playerBCursor = {W/2.0f, H/2.0f};
    bool chosenPixel = false;

    glfwSetWindowUserPointer(window, &state);
    glfwSetCursorPosCallback(window, cursorPositionCallback);
    glfwSetMouseButtonCallback(window, cursorButtonCallback);

    while (!glfwWindowShouldClose(window)) {

        size_t numBytes = 0;
        cudaGraphicsMapResources(1, &cudaPBO, nullptr);
        cudaGraphicsResourceGetMappedPointer((void**)&deviceColorOut, &numBytes, cudaPBO); // get device pointer to map opengl pbo memory to it



        kernelFlashLight<<<>>>()
    }

    return 0;
}