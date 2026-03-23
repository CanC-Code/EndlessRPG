#!/bin/bash
# File: scripts/setup_project.sh
# EndlessRPG v6 - Project Scaffolding with Automatic Dependency Management
set -e

CPP_DIR="app/src/main/cpp"
GLM_DIR="$CPP_DIR/glm"

echo "[setup_project.sh] Scaffolding Android project..."

# 1. Dependency Management: Fetch GLM if missing
if [ ! -d "$GLM_DIR" ]; then
    echo "[setup_project.sh] GLM not found. Downloading header-only library..."
    mkdir -p $CPP_DIR/tmp
    # Fetching latest stable GLM headers
    curl -L https://github.com/g-truc/glm/archive/refs/tags/1.0.1.tar.gz -o $CPP_DIR/tmp/glm.tar.gz
    tar -xzf $CPP_DIR/tmp/glm.tar.gz -C $CPP_DIR/tmp
    # Move only the 'glm' header folder to the include path
    mv $CPP_DIR/tmp/glm-1.0.1/glm $GLM_DIR
    rm -rf $CPP_DIR/tmp
    echo "[setup_project.sh] GLM headers installed successfully."
fi

# 2. Generate CMakeLists.txt with proper Include Paths
echo "[setup_project.sh] Generating CMakeLists.txt..."
cat <<EOF > app/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("game_engine")

# Add GLM and generated headers to the include path
include_directories(
    src/main/cpp
    src/main/cpp/glm
    src/main/cpp/models
    src/main/cpp/shaders
)

add_library(game_engine SHARED src/main/cpp/native-lib.cpp)

# Link standard Android libraries
find_library(log-lib log)
find_library(android-lib android)
find_library(gles-lib GLESv3)

target_link_libraries(game_engine 
    \${log-lib} 
    \${android-lib} 
    \${gles-lib}
)
EOF

# 3. Generate Android Manifest (standard RPG setup)
cat <<EOF > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.game.procedural">
    <uses-feature android:glEsVersion="0x00030000" android:required="true" />
    <application android:label="EndlessRPG" android:hasCode="true">
        <activity android:name=".MainActivity" android:exported="true" android:screenOrientation="landscape">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

echo "[setup_project.sh] Success: Project scaffolded with GLM and GLES3 support."
