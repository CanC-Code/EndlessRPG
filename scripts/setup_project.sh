#!/bin/bash
# File: scripts/setup_project.sh
set -e

echo "[setup_project.sh] Configuring Android Project & GLM..."

# Create project structure
mkdir -p app/src/main/cpp/include
mkdir -p app/src/main/java/com/game/procedural

# Fetch GLM (Essential for Realistic Math)
if [ ! -d "app/src/main/cpp/include/glm" ]; then
    git clone --depth 1 https://github.com/g-truc/glm.git /tmp/glm_repo
    mv /tmp/glm_repo/glm app/src/main/cpp/include/glm
    rm -rf /tmp/glm_repo
fi

# Generate CMakeLists.txt
cat <<EOF > app/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")
include_directories(src/main/cpp/include)
add_library(game_engine SHARED src/main/cpp/native-lib.cpp)
target_link_libraries(game_engine GLESv3 log)
EOF

# Generate build.gradle (App)
cat <<EOF > app/build.gradle
plugins { id 'com.android.application' }
android {
    namespace 'com.game.procedural'
    compileSdk 34
    defaultConfig {
        applicationId "com.game.procedural"
        minSdk 24
        targetSdk 34
        externalNativeBuild { cmake { cppFlags "-std=c++17" } }
        ndk { abiFilters 'arm64-v8a' }
    }
    externalNativeBuild { cmake { path "CMakeLists.txt" } }
}
EOF

# Generate Settings & Project Gradle
echo "include ':app'" > settings.gradle
cat <<EOF > build.gradle
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.2.2' }
}
allprojects { repositories { google(); mavenCentral() } }
EOF
