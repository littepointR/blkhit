cmake_minimum_required(VERSION 3.10)
project(blkhit_raylib C)

set(CMAKE_C_STANDARD 11)

# Find raylib
find_package(raylib 5.0 QUIET)
if (NOT raylib_FOUND)
    message(WARNING "raylib not found, please install: brew install raylib")
endif()

add_executable(blkhit main.c)

if (raylib_FOUND)
    target_link_libraries(blkhit raylib m)
    target_include_directories(blkhit PRIVATE ${RAYLIB_INCLUDE_DIRS})
else()
    message(FATAL_ERROR "raylib is required. Install with: brew install raylib")
endif()
