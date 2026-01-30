cmake_minimum_required(VERSION 3.5)

project(native_buffer)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(native_buffer SHARED
    native_buffer.cpp
)

# N-API (ArkTS) bridge library
target_link_libraries(native_buffer PUBLIC
    ace_napi.z
)
