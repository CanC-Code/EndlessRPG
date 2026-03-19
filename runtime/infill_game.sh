#!/bin/bash
echo "Initializing Complete High-Fidelity Project Generation..."

# 1. DIRECTORY SCAFFOLDING
mkdir -p app/src/main/java/com/game/procedural
mkdir -p app/src/main/cpp
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p runtime

# 2. GRADLE & MANIFEST CONFIGURATION
cat << 'EOF' > settings.gradle
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = "EndlessRPG"
include ':app'
EOF

cat << 'EOF' > build.gradle
plugins { id 'com.android.application' version '8.2.0' apply false }
EOF

cat << 'EOF' > app/build.gradle
plugins { id 'com.android.application' }
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

cat << 'EOF' > app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="EndlessRPG" android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity android:name="com.game.procedural.MainActivity" android:exported="true" android:screenOrientation="landscape">
            <intent-filter><action android:name="android.intent.action.MAIN" /><category android:name="android.intent.category.LAUNCHER" /></intent-filter>
        </activity>
    </application>
</manifest>
EOF

# 3. JAVA LAYER: ORBITAL CAMERA & INPUT HANDLING
cat << 'EOF' > app/src/main/java/com/game/procedural/MainActivity.java
package com.game.procedural;
import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class MainActivity extends Activity implements GLSurfaceView.Renderer {
    private GLSurfaceView glView;
    private float tX = 0f, tY = 0f;
    private float camYaw = 0.7f, camPitch = 0.5f, camZoom = 12.0f;
    private float lastTouchX, lastTouchY;
    private ScaleGestureDetector scaleDetector;

    static { System.loadLibrary("procedural_engine"); }
    private native void onCreated();
    private native void onChanged(int w, int h);
    private native void onDraw(float x, float y, float yaw, float pitch, float zoom);
    private native void triggerAction(int id);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        glView = findViewById(R.id.game_surface);
        glView.setEGLContextClientVersion(3);
        glView.setEGLConfigChooser(8, 8, 8, 8, 16, 0); 
        glView.setRenderer(this);

        scaleDetector = new ScaleGestureDetector(this, new ScaleGestureDetector.SimpleOnScaleGestureListener() {
            @Override public boolean onScale(ScaleGestureDetector d) {
                camZoom /= d.getScaleFactor();
                camZoom = Math.max(4.0f, Math.min(30.0f, camZoom));
                return true;
            }
        });

        glView.setOnTouchListener((v, e) -> {
            scaleDetector.onTouchEvent(e);
            if (!scaleDetector.isInProgress() && e.getPointerCount() == 1 && e.getX() > v.getWidth()/2f) {
                if (e.getAction() == MotionEvent.ACTION_DOWN) { lastTouchX = e.getX(); lastTouchY = e.getY(); }
                else if (e.getAction() == MotionEvent.ACTION_MOVE) {
                    camYaw += (e.getX() - lastTouchX) * 0.01f;
                    camPitch = Math.max(0.1f, Math.min(1.5f, camPitch + (e.getY() - lastTouchY) * 0.01f));
                    lastTouchX = e.getX(); lastTouchY = e.getY();
                }
            }
            return true;
        });

        findViewById(R.id.thumbstick).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_MOVE) {
                tX = (e.getX() / v.getWidth()) * 2 - 1; tY = (e.getY() / v.getHeight()) * 2 - 1;
            } else { tX = 0f; tY = 0f; }
            return true;
        });
        
        findViewById(R.id.btn_sword).setOnClickListener(v -> triggerAction(1));
        findViewById(R.id.btn_shield).setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN) triggerAction(2);
            else if (e.getAction() == MotionEvent.ACTION_UP) triggerAction(3);
            return true;
        });
    }
    @Override public void onSurfaceCreated(GL10 gl, EGLConfig c) { onCreated(); }
    @Override public void onSurfaceChanged(GL10 gl, int w, int h) { onChanged(w, h); }
    @Override public void onDrawFrame(GL10 gl) { onDraw(tX, tY, camYaw, camPitch, camZoom); }
}
EOF

# 4. BLENDER PIPELINE: HIGH-FIDELITY ASSET GENERATION
cat << 'EOF' > runtime/build_models.py
import bpy
import bmesh
from math import radians

def export_model(name, r, g, b, build_func):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    build_func()
    obj = bpy.context.object
    bpy.ops.object.modifier_add(type='TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=obj.modifiers[-1].name)
    
    verts = []
    mesh = obj.data
    min_z = min((v.co.z for v in mesh.vertices), default=0)
    height = max((v.co.z for v in mesh.vertices), default=1) - min_z

    mesh.calc_loop_triangles()
    for tri in mesh.loop_triangles:
        for loop_idx in tri.loops:
            v = mesh.vertices[mesh.loops[loop_idx].vertex_index]
            verts.extend([v.co.x, v.co.z, -v.co.y])
            lum = 0.6 + (v.normal.z * 0.3)
            ao = 0.5 + (0.5 * ((v.co.z - min_z) / height)) if height > 0 else 1.0
            verts.extend([r*lum*ao, g*lum*ao, b*lum*ao])
    return verts

def build_hero():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=0.8, location=(0,0,0.8))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.25, location=(0,0,1.5))
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0,-0.2,1.2))
    bpy.context.object.scale = (0.3, 0.05, 0.6)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.join()

def build_tree():
    bpy.ops.mesh.primitive_cylinder_add(radius=0.15, depth=1.0, location=(0,0,0.5))
    bpy.ops.mesh.primitive_cone_add(radius1=0.8, depth=2.0, location=(0,0,2.0))
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.join()

models = [("HERO", 0.2, 0.4, 0.9, build_hero), ("TREE", 0.1, 0.5, 0.1, build_tree)]
with open("app/src/main/cpp/GeneratedModels.h", "w") as f:
    f.write("#pragma once\n")
    for n, r, g, b, func in models:
        d = export_model(n, r, g, b, func)
        f.write(f"const float M_{n}[] = {{ {', '.join(map(str, d))} }};\nconst int N_{n} = {len(d)//6};\n")
EOF

blender --background --python runtime/build_models.py

# 5. C++ ENGINE: CAMERA-RELATIVE MOVEMENT & ORBITAL MATH
cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <cmath>
#include "GeneratedModels.h"

struct Mat4 {
    float m[16] = {0};
    static Mat4 identity() { Mat4 r; r.m[0]=1; r.m[5]=1; r.m[10]=1; r.m[15]=1; return r; }
    static Mat4 perspective(float fov, float asp, float n, float f) {
        Mat4 r; float t = 1.0f / tan(fov/2.0f); r.m[0]=t/asp; r.m[5]=t; r.m[10]=(f+n)/(n-f); r.m[11]=-1; r.m[14]=(2*f*n)/(n-f); return r;
    }
    Mat4 mul(const Mat4& b) const {
        Mat4 r; for(int i=0; i<4; i++) for(int j=0; j<4; j++) for(int k=0; k<4; k++) r.m[i*4+j] += m[k*4+j]*b.m[i*4+k]; return r;
    }
    static Mat4 trans(float x, float y, float z) { Mat4 r=identity(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
    static Mat4 rotY(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[2]=-sin(a); r.m[8]=sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotX(float a) { Mat4 r=identity(); r.m[5]=cos(a); r.m[6]=sin(a); r.m[9]=-sin(a); r.m[10]=cos(a); return r; }
};

const char* vS = "#version 300 es\nlayout(location=0) in vec3 p; layout(location=1) in vec3 c; uniform mat4 m, v, pr; out vec3 vc; void main(){ gl_Position=pr*v*m*vec4(p,1.0); vc=c; }";
const char* fS = "#version 300 es\nprecision mediump float; in vec3 vc; out vec4 o; void main(){ o=vec4(vc,1.0); }";

GLuint prog, vaoHero, vaoTree, vaoGround;
float px=0, pz=0, pf=0, wt=0;
volatile bool slash=false, block=false;
Mat4 proj;

GLuint createVAO(const float* d, int n) {
    GLuint vao, vbo; glGenVertexArrays(1,&vao); glGenBuffers(1,&vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER,vbo); glBufferData(GL_ARRAY_BUFFER, n*24, d, GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,0,24,0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,0,24,(void*)12); glEnableVertexAttribArray(1);
    return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        GLuint vs=glCreateShader(GL_VERTEX_SHADER); glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        GLuint fs=glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog); glUseProgram(prog);
        glEnable(GL_DEPTH_TEST); vaoHero=createVAO(M_HERO, N_HERO); vaoTree=createVAO(M_TREE, N_TREE);
        float g[]={-100,0,-100,0.2,0.5,0.2, 100,0,-100,0.2,0.5,0.2, -100,0,100,0.2,0.5,0.2, 100,0,-100,0.2,0.5,0.2, 100,0,100,0.2,0.5,0.2, -100,0,100,0.2,0.5,0.2};
        vaoGround=createVAO(g,6);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
        glViewport(0,0,w,h); proj=Mat4::perspective(1.0f, (float)w/h, 0.1f, 100.0f);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch, jfloat zoom) {
        if(fabs(ix)>0.05f || fabs(iy)>0.05f) {
            float s=sin(yaw), c=cos(yaw), dx=ix*c-(-iy)*s, dz=ix*s+(-iy)*c;
            px+=dx*0.15f; pz-=dz*0.15f; pf=atan2(-dx,dz); wt+=0.2f;
        }
        glClearColor(0.4f,0.7f,1.0f,1.0f); glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glUniformMatrix4fv(glGetUniformLocation(prog,"pr"),1,0,proj.m);
        Mat4 view = Mat4::trans(0,0,-zoom).mul(Mat4::rotX(-pitch)).mul(Mat4::rotY(-yaw)).mul(Mat4::trans(-px,-1,-pz));
        glUniformMatrix4fv(glGetUniformLocation(prog,"v"),1,0,view.m);
        
        glUniformMatrix4fv(glGetUniformLocation(prog,"m"),1,0,Mat4::identity().m);
        glBindVertexArray(vaoGround); glDrawArrays(GL_TRIANGLES,0,6);

        glBindVertexArray(vaoTree);
        for(int i=-3; i<=3; i++) for(int j=-3; j<=3; j++) {
            float wx=floor(px/8.f)*8.f+i*8.f, wz=floor(pz/8.f)*8.f+j*8.f;
            if(fmod(wx*1.2f+wz*0.7f, 6.f)>4.5f) {
                Mat4 m=Mat4::trans(wx,0,wz); glUniformMatrix4fv(glGetUniformLocation(prog,"m"),1,0,m.m);
                glDrawArrays(GL_TRIANGLES,0,N_TREE);
            }
        }
        Mat4 hero=Mat4::trans(px,sin(wt)*0.08f,pz).mul(Mat4::rotY(pf));
        glUniformMatrix4fv(glGetUniformLocation(prog,"m"),1,0,hero.m);
        glBindVertexArray(vaoHero); glDrawArrays(GL_TRIANGLES,0,N_HERO);
    }
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) slash=true; else if(id==2) block=true; else block=false;
    }
}
EOF

# 6. CMAKE GENERATION
cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
target_link_libraries(procedural_engine log GLESv3)
EOF

echo "Project Generation Complete."
