cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")

# 1. Source files - Ensure Character.cpp is listed!
add_library(procedural_engine SHARED
    Engine.cpp
    EGLCore.cpp
    Renderer.cpp
    RenderLoop.cpp
    AssetManager.cpp
    Character.cpp
)

# 2. Libraries - Clean and explicit linking
target_link_libraries(procedural_engine
    android
    EGL       # REQUIRED for eglSwapBuffers/eglMakeCurrent
    GLESv3    # For OpenGL ES 3.1
    log       # For debugging
    atomic
    m         # Math library
)
