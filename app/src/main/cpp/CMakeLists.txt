cmake_minimum_required(VERSION 3.22.1)
project(ProceduralEngine)

add_library(procedural_engine SHARED
    NativeEngine.cpp
    Renderer.cpp
    Character.cpp
    AssetManager.cpp
    EGLCore.cpp
    # RenderLoop.cpp is safely removed to prevent threading conflicts
)

target_link_libraries(procedural_engine
    android
    log
    GLESv3
    EGL
)
