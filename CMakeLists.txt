cmake_minimum_required(VERSION 3.28)
project(CudaPractice LANGUAGES C CXX CUDA)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CUDA_STANDARD 20)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

set(CMAKE_CUDA_ARCHITECTURES 86)

add_executable(dist_v1
        chapter3/dist_v1.cu
)

add_executable(dist_v2
        chapter3/dist_v2.cu
)

add_executable(dist_v2_unified
        chapter3/dist_v2_unified.cu
)

add_executable(changedNumOfElements
        chapter3/changedNumOfElements.cu
)

add_executable(distArray
        chapter3/distArray.cu
)

add_executable(2dKernel
        chapter4/Source/2dKernel.cu
)

add_executable(dist_2d
        chapter4/Source/dist_2d.cu
)

add_executable(dist_2d_color
        chapter4/Source/dis_2d_color.cu
        chapter4/Source/glad.c
)

add_executable(stability
        chapter4/Source/stability.cu
        chapter4/Source/glad.c
)

target_include_directories(dist_2d_color PRIVATE
        ${CMAKE_SOURCE_DIR}/chapter4/Libraries/include
)

target_link_libraries(dist_2d_color PRIVATE
        ${CMAKE_SOURCE_DIR}/chapter4/Libraries/lib/glfw3.lib
        opengl32
)


set_target_properties(
        dist_v1
        dist_v2
        dist_v2_unified
        changedNumOfElements
        distArray
        PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON
)