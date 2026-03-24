cmake_minimum_required(VERSION 3.22.1)

# Define the name of the project
project("procedural_engine")

# Define the shared library and all C++ source files
# Ensure Character.cpp is included here
add_library(procedural_engine SHARED
    Engine.cpp
    EGLCore.cpp
    Renderer.cpp
    RenderLoop.cpp
    AssetManager.cpp
    Character.cpp
)

# Link the necessary Android and OpenGL libraries
# This list must be clean of any extra brackets or parentheses
target_link_libraries(procedural_engine
    android
    EGL
    GLESv3
    log
    atomic
    m
)
