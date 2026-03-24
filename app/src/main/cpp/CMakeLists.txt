cmake_minimum_required(VERSION 3.22.1)

project("procedural_engine")

# 1. Define the main engine library with all architectural components.
# Including RenderLoop.cpp ensures the visual cycle is part of the binary.
add_library(
        procedural_engine
        SHARED
        Engine.cpp
        AssetManager.cpp
        Renderer.cpp
        EGLCore.cpp
        RenderLoop.cpp) # <-- Final component added

# 2. Search for native Android system libraries.
find_library(log-lib log)
find_library(android-lib android)
find_library(egl-lib EGL)
find_library(gles3-lib GLESv3)

# 3. Link libraries to our engine.
target_link_libraries(
        procedural_engine
        ${log-lib}
        ${android-lib}
        ${egl-lib}
        ${gles3-lib})
