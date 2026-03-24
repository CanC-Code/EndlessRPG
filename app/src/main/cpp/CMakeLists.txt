cmake_minimum_required(VERSION 3.22.1)

project("procedural_engine")

# 1. Define the main engine library and ALL its source components.
# This ensures the compiler stitches the Job System, Asset Manager, 
# and Grass Renderer into a single shared library (.so).
add_library(
        procedural_engine
        SHARED
        Engine.cpp
        AssetManager.cpp
        Renderer.cpp) # Includes our procedural grass logic

# 2. Search for the specific Android NDK system libraries.
find_library(log-lib log)           # For LOGI/LOGE debugging
find_library(android-lib android)   # Required for the AAssetManager (Shaders/Textures)
find_library(egl-lib EGL)           # Required for GPU Context management
find_library(gles3-lib GLESv3)     # Required for OpenGL ES 3.1+ (Compute Shaders)

# 3. Link the libraries together.
# This tells the NDK that 'procedural_engine' depends on these OS features.
target_link_libraries(
        procedural_engine
        ${log-lib}
        ${android-lib}
        ${egl-lib}
        ${gles3-lib})
