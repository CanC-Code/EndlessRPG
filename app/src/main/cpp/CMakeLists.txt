cmake_minimum_required(VERSION 3.22.1)

# Define the name of the project
project("procedural_engine")

# Define the shared library and all C++ source files required to build it
add_library(procedural_engine SHARED
    Engine.cpp
    EGLCore.cpp
    Renderer.cpp
    RenderLoop.cpp
    AssetManager.cpp
    Character.cpp  # Added to support the new modular character system
)

# Link the necessary Android and OpenGL libraries
target_link_libraries(procedural_engine
    android    # For native window and asset handling
    GLESv3     # For OpenGL ES 3.1+ functionality
    log        # For __android_log_print debugging
)
