cmake_minimum_required(VERSION 3.28)
project(CudaPractice LANGUAGES C CXX CUDA)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CUDA_STANDARD 20)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

set(CMAKE_CUDA_ARCHITECTURES 86)

add_executable(stability
        chapter4/Source/stability.cu
        chapter4/Source/glad.c
)

add_executable(hotterColderFlashlightGame
        chapter4/Source/hotterColderFlashlightGame.cu
        chapter4/Source/glad.c
)

add_executable(firstOrderODE
        chapter4/Source/firstOrderODE.cu
        chapter4/Source/glad.c
)

target_include_directories(stability PRIVATE
        ${CMAKE_SOURCE_DIR}/chapter4/Libraries/include
)

target_link_libraries(stability PRIVATE
        ${CMAKE_SOURCE_DIR}/chapter4/Libraries/lib/glfw3.lib
        opengl32
)

target_include_directories(hotterColderFlashlightGame PRIVATE
        ${CMAKE_SOURCE_DIR}/chapter4/Libraries/include
)

target_link_libraries(hotterColderFlashlightGame PRIVATE
        ${CMAKE_SOURCE_DIR}/chapter4/Libraries/lib/glfw3.lib
        opengl32
)


target_include_directories(firstOrderODE PRIVATE
        ${CMAKE_SOURCE_DIR}/chapter4/Libraries/include
)

target_link_libraries(firstOrderODE PRIVATE
        ${CMAKE_SOURCE_DIR}/chapter4/Libraries/lib/glfw3.lib
        opengl32
)