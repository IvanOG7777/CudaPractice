//
// Created by elder on 7/20/2026.
//

#include <iostream>

#include <glad/glad.h>
#include "GLFW/glfw3.h"

#include <cuda_gl_interop.h>

constexpr int TX = 32, TY = 32;
constexpr int W = 1920, H = 1080;

__device__ unsigned char clip (int n) {
    return n > 255 ? 255 : (n < 0 ? 0 : n);
}

// position is normalized when passed
__global__ void kernelFlashLight(uchar4 *d_out, int width, int height, float2 cursorPosition, float2 pixelPosition) {
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;

    if (col >= width || row >= height) return;

    int i = row * width + col;

    float distanceToPixelX = cursorPosition.x - pixelPosition.x;
    float distanceToPixelY = cursorPosition.y - pixelPosition.y;

    float currentDistance = std::sqrtf((col - cursorPosition.x) * (col - cursorPosition.x) + (row - cursorPosition.y) * (row - cursorPosition.y));

    float disX = std::sqrtf((currentDistance - distanceToPixelX) * (currentDistance - distanceToPixelX));
    float disY = std::sqrtf((currentDistance - distanceToPixelY) * (currentDistance - distanceToPixelY));

    unsigned char intensity = clip (static_cast<int>(255 - (disX + disY)));

    d_out[i].x = intensity;
    d_out[i].y = 0;
    d_out[i].z = intensity;
    d_out[i].w = 255;
}

float2 pickPixel(float2 position) {
    float normalX = position.x;
    float normalY = position.y;

    return {normalX, normalY};
}

struct SceneState {
    int *pixelPicked;
    float2 *playerBMousePosition;
    float2 *playerAMousePosition;
    float2 *chosenPixelCoordinates;
};

// Allows player A to pick pixel, then sets flag to true
void cursorButtonCallback(GLFWwindow *window, int button, int action, int mods) {
    auto *state = static_cast<SceneState *>(glfwGetWindowUserPointer(window));
    auto *playerAPosition = state->playerAMousePosition;

    if (*state->pixelPicked == 0 && button == GLFW_MOUSE_BUTTON_LEFT && action == GLFW_PRESS) {
        *state->chosenPixelCoordinates = pickPixel(*playerAPosition);
        *state->pixelPicked = 1;
        std:: cout << "Player A picked a pixel\n";
        printf("Chosen pixel coordinates is: (%f, %f)", state->chosenPixelCoordinates->x, state->chosenPixelCoordinates->y);
    }

}

// Gets cursor positon
void cursorPositionCallback(GLFWwindow *window, double posX, double posY) {
    auto *state = static_cast<SceneState *>(glfwGetWindowUserPointer(window));

    if (*state->pixelPicked == 0) {
        state->playerAMousePosition->x = static_cast<float>(posX);
        state->playerAMousePosition->y = static_cast<float>(posY);
        std:: cout << "Player A moving mouse\n";
    } else {
        state->playerBMousePosition->x = static_cast<float>(posX);
        state->playerBMousePosition->y = static_cast<float>(posY);
        std:: cout << "Player B moving mouse\n";
    }
}

const char *vertexShader = R"GLSL(
    #version 330 core

    layout (location = 0) in vec2 aPos; // send x/y data to aPos
    layout (location = 1) in vec2 aTexCoord; // send x/y data to aTexCoord

    out vec2 vTexCoord; // send out to fragment

     void main () {
        gl_Position = vec4(aPos, 0.0, 1.0); // send data off to fragment
        vTexCoord = aTexCoord; // send data off to fragment
     }
)GLSL";

const char *fragmentShader = R"GLSL(
    #version 330 core

    in vec2 vTexCoord; // take in vTexCoord from shader
    out vec4 FragColor; // color fragment out

    uniform sampler2D uTex;

    void main() {
        FragColor = texture(uTex, vTexCoord);
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
        glfwTerminate();
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
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(coordinates), coordinates,GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)(2 * sizeof(float)));

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
    float2 chosenPixelCoordinates = {};
    int chosenPixel = 0;

    state.chosenPixelCoordinates = &chosenPixelCoordinates;
    state.playerAMousePosition = &playerACursor;
    state.playerBMousePosition = &playerBCursor;
    state.pixelPicked = &chosenPixel;

    glfwSetWindowUserPointer(window, &state);
    glfwSetCursorPosCallback(window, cursorPositionCallback);
    glfwSetMouseButtonCallback(window, cursorButtonCallback);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    while (!glfwWindowShouldClose(window)) {

        size_t numBytes = 0;
        cudaGraphicsMapResources(1, &cudaPBO, nullptr);
        cudaGraphicsResourceGetMappedPointer((void**)&deviceColorOut, &numBytes, cudaPBO); // get device pointer to map opengl pbo memory to it


        std:: cout << "Still waiting for player a to pick pixel" << std:: endl;
        if (*state.pixelPicked == 1) {
            std:: cout << "Are we entering this statemtn? " << std:: endl;
            kernelFlashLight<<<gridSize, blockSize>>>(deviceColorOut, W, H, playerBCursor, chosenPixelCoordinates);

            // rebind buffer and textures and let opengl render
            glBindBuffer(GL_PIXEL_UNPACK_BUFFER, PBO); // bind buffer to "unpack" data from cpu to gpu
            glBindTexture(GL_TEXTURE_2D, tex); // bind tex to be a 2d texture
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
            glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0); // unbind pbo

            glClear(GL_COLOR_BUFFER_BIT);

            glUseProgram(program); // reuse program
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, tex);
            glBindVertexArray(VAO);
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        }
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    return 0;
}