#!/bin/bash
echo "Setting up project structure..."
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable

# AndroidManifest.xml
cat << 'EOF' > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="EndlessRPG" android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name="com.game.procedural.MainActivity" android:exported="true" android:screenOrientation="landscape">
            <intent-filter><action android:name="android.intent.action.MAIN" /><category android:name="android.intent.category.LAUNCHER" /></intent-filter>
        </activity>
    </application>
</manifest>
EOF

# UI Resources
cat << 'EOF' > app/src/main/res/drawable/thumbstick_base.xml
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#44FFFFFF"/><stroke android:width="2dp" android:color="#FFFFFFFF"/>
</shape>
EOF
cat << 'EOF' > app/src/main/res/drawable/action_btn.xml
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#88000000"/><stroke android:width="2dp" android:color="#CCCCCC"/>
</shape>
EOF
