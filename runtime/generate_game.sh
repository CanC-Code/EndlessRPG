#!/bin/bash
echo "Generating Game Content..."

# 1. Generate UI Assets with ImageMagick (Circle for thumbstick, Sword icon)
convert -size 200x200 xc:none -fill "rgba(255,255,255,0.5)" -draw "circle 100,100 100,20" app/src/main/res/drawable/thumbstick_base.png
convert -size 100x100 xc:none -fill "white" -draw "rectangle 45,10 55,90" -draw "rectangle 20,70 80,80" app/src/main/res/drawable/sword_icon.png

# 2. Generate C++ World Seed Data
# This allows each build to potentially have a hardcoded unique seed or logic
SEED=$RANDOM
cat << EOF > app/src/main/cpp/WorldConfig.h
#ifndef WORLD_CONFIG_H
#define WORLD_CONFIG_H
#define WORLD_SEED $SEED
#define PLAYER_START_STRENGTH 10
#endif
EOF

# 3. Create basic C++ Render Logic (Placeholder for OpenGL)
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
find_library(log-lib log)
find_library(gles3-lib GLESv3)
target_link_libraries(procedural_engine ${log-lib} ${gles3-lib})
EOF

cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include "WorldConfig.h"
#include <GLES3/gl3.h>

extern "C" JNIEXPORT jstring JNICALL
Java_com_game_procedural_MainActivity_getWorldInfo(JNIEnv* env, jobject) {
    return env->NewStringUTF("World Seed Initialized...");
}
EOF
