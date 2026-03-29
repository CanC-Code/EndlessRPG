# Specify the minimum CMake version required
cmake_minimum_required(VERSION 3.22.1)

# Declare the project name to satisfy CMake warnings
project(ProceduralEngine)

# Add your C++ source files to be compiled into the shared library
add_library(procedural_engine SHARED
    NativeEngine.cpp
    Renderer.cpp
    Character.cpp
    AssetManager.cpp
    EGLCore.cpp
    RenderLoop.cpp
)

# Link the required Android Native libraries
target_link_libraries(procedural_engine
    android
    log
    GLESv3
    EGL       # <--- THIS IS THE CRITICAL FIX! It links the EGL context library.
)
