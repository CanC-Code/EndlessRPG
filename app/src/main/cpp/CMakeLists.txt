cmake_minimum_required(VERSION 3.22.1)

project("procedural_engine")

# Define the main engine library
add_library(
        procedural_engine
        SHARED
        Engine.cpp)

# Search for native Android libraries
find_library(log-lib log)
find_library(android-lib android)
find_library(egl-lib EGL)
find_library(gles3-lib GLESv3)

# Link libraries to our engine
target_link_libraries(
        procedural_engine
        ${log-lib}
        ${android-lib}
        ${egl-lib}
        ${gles3-lib})
