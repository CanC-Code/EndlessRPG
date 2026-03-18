#!/bin/bash
# 1. Create the Directory Structure
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p runtime/

# 2. CRITICAL FIX: Create settings.gradle
# This tells Gradle that the 'app' folder is a buildable module.
cat << 'EOF' > settings.gradle
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "EndlessRPG"
include ':app'
EOF

# 3. Create Root build.gradle
cat << 'EOF' > build.gradle
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.2.0' }
}
EOF

# 4. Create App build.gradle
cat << 'EOF' > app/build.gradle
apply plugin: 'com.android.application'

android {
    namespace 'com.game.procedural'
    compileSdk 34
    defaultConfig {
        applicationId "com.game.procedural"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"

        externalNativeBuild {
            cmake {
                cppFlags "-std=c++17"
            }
        }
    }
    buildTypes {
        release {
            minifyEnabled false
        }
    }
    externalNativeBuild {
        cmake {
            path "src/main/cpp/CMakeLists.txt"
        }
    }
}
EOF

# 5. Create MainActivity.java (Required for the build to succeed)
cat << 'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;
import android.app.Activity;
import android.os.Bundle;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
    }
}
EOF

# 6. Create C++ and CMake Placeholders
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
find_library(log-lib log)
target_link_libraries(procedural_engine ${log-lib})
EOF

cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
extern "C" JNIEXPORT jstring JNICALL
Java_com_game_procedural_MainActivity_stringFromJNI(JNIEnv* env, jobject) {
    return env->NewStringUTF("C++ Engine Ready");
}
EOF

# 7. Create layout/activity_main.xml
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    <android.opengl.GLSurfaceView
        android:id="@+id/game_surface"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />
</RelativeLayout>
EOF

# 8. Create AndroidManifest.xml
cat << 'EOF' > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.game.procedural">
    <application android:label="EndlessRPG" android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name=".MainActivity" android:exported="true" android:screenOrientation="landscape">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

echo "Project scaffolded successfully."
