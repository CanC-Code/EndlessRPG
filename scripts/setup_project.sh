#!/bin/bash
# File: scripts/setup_project.sh

mkdir -p app/src/main/res/layout
mkdir -p app/src/main/java/com/game/procedural

# 1. Android Manifest (Fixed Namespace)
cat << 'EOF' > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="EndlessRPG" android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name="com.game.procedural.MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# 2. Enhanced HUD Layout
cat << 'EOF' > app/src/main/res/layout/activity_main.xml
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="match_parent">
    <android.opengl.GLSurfaceView android:id="@+id/gl_surface"
        android:layout_width="match_parent" android:layout_height="match_parent" />
    
    <ImageView android:id="@+id/img_compass" android:layout_width="60dp"
        android:layout_height="60dp" android:layout_alignParentRight="true"
        android:layout_margin="20dp" android:src="@android:drawable/ic_menu_compass" />
        
    <Button android:id="@+id/btn_compass_toggle" android:layout_width="wrap_content"
        android:layout_height="wrap_content" android:layout_below="@id/img_compass"
        android:layout_alignParentRight="true" android:text="Lock" />

    <RelativeLayout android:layout_width="120dp" android:layout_height="120dp"
        android:layout_alignParentBottom="true" android:layout_margin="30dp">
        <ImageView android:id="@+id/joystick_bg" android:layout_width="match_parent"
            android:layout_height="match_parent" android:background="#44FFFFFF"/>
        <ImageView android:id="@+id/joystick_knob" android:layout_width="50dp"
            android:layout_height="50dp" android:layout_centerInParent="true"
            android:background="#88FFFFFF" />
    </RelativeLayout>
</RelativeLayout>
EOF
