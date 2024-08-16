cmake_minimum_required(VERSION 3.14)

project(MyMetalProject)

set(CMAKE_CXX_STANDARD 17)

find_library(METAL_FRAMEWORK Metal)
find_library(FOUNDATION_FRAMEWORK Foundation)
find_library(QUARTZCORE_FRAMEWORK QuartzCore)

add_executable(MyMetalProject main.cpp)

target_link_libraries(MyMetalProject
    ${METAL_FRAMEWORK}
    ${FOUNDATION_FRAMEWORK}
    ${QUARTZCORE_FRAMEWORK})
