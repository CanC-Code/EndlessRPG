cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")

add_library(procedural_engine SHARED
    Engine.cpp
    AssetManager.cpp
    EGLCore.cpp
    Renderer.cpp
    RenderLoop.cpp)

find_library(log-lib log)
find_library(android-lib android)
find_library(egl-lib EGL)
find_library(gles3-lib GLESv3)

target_link_libraries(procedural_engine
    ${log-lib} ${android-lib} ${egl-lib} ${gles3-lib})
