#!/bin/bash
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p runtime/

# Generate basic Android Manifest
cat << 'EOF' > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.game.procedural">
    <application android:label="Procedural3D" android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name=".MainActivity" android:exported="true" android:screenOrientation="landscape">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# Create root build.gradle
cat << 'EOF' > build.gradle
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:8.2.0' }
}
allprojects {
    repositories { google(); mavenCentral() }
}
EOF

# Create app build.gradle with C++ support
cat << 'EOF' > app/build.gradle
apply plugin: 'com.android.application'

android {
    namespace 'com.game.procedural'
    compileSdk 34
    defaultConfig {
        applicationId "com.game.procedural"
        minSdk 24
        targetSdk 34
        externalNativeBuild { cmake { cppFlags "-std=c++17" } }
    }
    externalNativeBuild { cmake { path "src/main/cpp/CMakeLists.txt" } }
}
EOF

# Append this to scripts/setup_project.sh
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">
    
    <android.opengl.GLSurfaceView
        android:id="@+id/game_surface"
        android:layout_width="match_parent"
        android:layout_height="match_parent" />

    <ImageView
        android:id="@+id/thumbstick"
        android:layout_width="150dp"
        android:layout_height="150dp"
        android:layout_alignParentBottom="true"
        android:layout_margin="30dp"
        android:src="@drawable/thumbstick_base" />

    <LinearLayout
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_alignParentBottom="true"
        android:layout_alignParentRight="true"
        android:layout_margin="30dp"
        android:orientation="horizontal">
        
        <Button android:id="@+id/btn_shield" android:text="B" android:layout_width="80dp" android:layout_height="80dp" />
        <Button android:id="@+id/btn_sword" android:text="A" android:layout_width="80dp" android:layout_height="80dp" android:layout_marginLeft="20dp" />
    </LinearLayout>
</RelativeLayout>
EOF
