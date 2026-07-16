cmake_minimum_required(VERSION 3.28)
project(CudaPractice LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CUDA_STANDARD 20)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

set(CMAKE_CUDA_ARCHITECTURES 86)

add_executable(dist_v1
        dist_v1.cu
)

add_executable(dist_v2
        dist_v2.cu
)

add_executable(dist_v2_unified
        dist_v2_unified.cu
)

add_executable(changedNumOfElements
        changedNumOfElements.cu
)


set_target_properties(
        dist_v1
        dist_v2
        dist_v2_unified
        changedNumOfElements
        PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON
)