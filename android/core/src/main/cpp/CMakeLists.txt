cmake_minimum_required(VERSION 3.22.1)

project("core")

message("CMAKE_SOURCE_DIR ${CMAKE_SOURCE_DIR}")

message("CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE}")

if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    add_compile_options(-O3 -flto -g0 -fno-exceptions -fno-rtti)
    add_link_options(-flto -Wl,--gc-sections,--strip-all)
endif ()

add_library(${CMAKE_PROJECT_NAME} SHARED
        jni_helper.cpp
        core.cpp)

# libclash.so is loaded dynamically via dlopen/dlsym at runtime.
# No compile-time link dependency. The -ldl flag provides dlopen/dlsym.
target_link_libraries(${CMAKE_PROJECT_NAME}
        dl)
