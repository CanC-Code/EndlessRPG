#!/bin/bash
# File: runtime/generate_engine.sh
# Purpose: Render pipeline with advanced LookAt camera, collision, and corrected kinematics.

cat << 'EOF' > app/src/main/cpp/CMakeLists.txt
cmake_minimum_required(VERSION 3.22.1)
project("procedural_engine")
add_library(procedural_engine SHARED native-lib.cpp)
target_link_libraries(procedural_engine log GLESv3)
EOF

cat << 'EOF' > app/src/main/cpp/native-lib.cpp
#include <jni.h>
#include <GLES3/gl3.h>
#include <cmath>
#include "models/AllModels.h"

struct Mat4 {
    float m[16] = {0};
    static Mat4 identity() { Mat4 r; r.m[0]=1; r.m[5]=1; r.m[10]=1; r.m[15]=1; return r; }
    static Mat4 perspective(float f, float a, float n, float fr) {
        Mat4 r; float t = 1.0f/tan(f/2.0f); 
        r.m[0]=t/a; r.m[5]=t; r.m[10]=-(fr+n)/(fr-n); r.m[11]=-1.0f; r.m[14]=-(2.0f*fr*n)/(fr-n); 
        return r;
    }
    // Advanced LookAt Matrix for Free Camera
    static Mat4 lookAt(float ex, float ey, float ez, float cx, float cy, float cz, float ux, float uy, float uz) {
        float fx = cx - ex, fy = cy - ey, fz = cz - ez;
        float rlf = 1.0f / sqrt(fx*fx + fy*fy + fz*fz);
        fx *= rlf; fy *= rlf; fz *= rlf;
        float sx = fy*uz - fz*uy, sy = fz*ux - fx*uz, sz = fx*uy - fy*ux;
        float rls = 1.0f / sqrt(sx*sx + sy*sy + sz*sz);
        sx *= rls; sy *= rls; sz *= rls;
        float ux2 = sy*fz - sz*fy, uy2 = sz*fx - sx*fz, uz2 = sx*fy - sy*fx;
        Mat4 m = identity();
        m.m[0] = sx; m.m[4] = sy; m.m[8] = sz;
        m.m[1] = ux2; m.m[5] = uy2; m.m[9] = uz2;
        m.m[2] = -fx; m.m[6] = -fy; m.m[10] = -fz;
        m.m[12] = -(sx*ex + sy*ey + sz*ez); m.m[13] = -(ux2*ex + uy2*ey + uz2*ez); m.m[14] = -(-fx*ex + -fy*ey + -fz*ez);
        return m;
    }
    Mat4 mul(const Mat4& b) const {
        Mat4 r; for(int i=0; i<4; i++) for(int j=0; j<4; j++) for(int k=0; k<4; k++) r.m[i*4+j]+=m[k*4+j]*b.m[i*4+k]; return r;
    }
    static Mat4 trans(float x, float y, float z) { Mat4 r=identity(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
    static Mat4 rotY(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[2]=-sin(a); r.m[8]=sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotX(float a) { Mat4 r=identity(); r.m[5]=cos(a); r.m[6]=sin(a); r.m[9]=-sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotZ(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[1]=sin(a); r.m[4]=-sin(a); r.m[5]=cos(a); return r; }
};

float getTerrainHeight(float x, float z) { return sin(x * 0.4f) * cos(z * 0.4f) * 1.5f; }
float hash(float x, float z) { float n = sin(x * 12.9898f + z * 78.233f) * 43758.5453f; return n - floor(n); }

GLuint prog, vaoTorso, vaoHead, vaoUpLimb, vaoLowLimb, vaoSword, vaoShield, vaoTree, vaoTerrain;
GLuint vaoRock, vaoGrass, vaoWheat;
Mat4 proj; 
float px=0, py=0, pz=0, pf=0, wt=0;
float jumpT=0, slashT=0, bashT=0; 
bool block=false;

GLuint createVAO(const float* d, int n) {
    GLuint vao, vbo; glGenVertexArrays(1,&vao); glGenBuffers(1,&vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER, n*32, d, GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,32,0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,32,(void*)12); glEnableVertexAttribArray(1);
    glVertexAttribPointer(2,2,GL_FLOAT,GL_FALSE,32,(void*)24); glEnableVertexAttribArray(2);
    return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        const char* vS = "#version 300 es\n"
            "layout(location=0) in vec3 p; layout(location=1) in vec3 c; layout(location=2) in vec2 uv;\n"
            "uniform mat4 m,v,pr; uniform float isT;\n"
            "out vec3 vc; out vec4 wPos;\n"
            "void main(){\n"
            "  vec4 w=m*vec4(p,1.0);\n"
            "  if(isT>0.5) w.y += sin(w.x*0.4)*cos(w.z*0.4)*1.5;\n"
            "  wPos = w;\n"
            "  gl_Position=pr*v*w; vc=c;\n"
            "}";
        
        // Removed Hatch Shader. Using beautiful soft shading.
        const char* fS = "#version 300 es\n"
            "precision highp float;\n"
            "in vec3 vc; in vec4 wPos;\n"
            "uniform float isT;\n"
            "out vec4 o;\n"
            "void main(){\n"
            "  vec3 col = vc;\n"
            "  if(isT>0.5) { col = vec3(0.4, 0.5, 0.3) * vc; }\n" // Organic ground
            "  o = vec4(col, 1.0);\n"
            "}";

        GLuint vs=glCreateShader(GL_VERTEX_SHADER), fs=glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(vs,1,&vS,0); glCompileShader(vs);
        glShaderSource(fs,1,&fS,0); glCompileShader(fs);
        prog=glCreateProgram(); glAttachShader(prog,vs); glAttachShader(prog,fs); glLinkProgram(prog);

        vaoTorso = createVAO(M_TORSO, N_TORSO); vaoHead = createVAO(M_HEAD, N_HEAD);
        vaoUpLimb = createVAO(M_UP_LIMB, N_UP_LIMB); vaoLowLimb = createVAO(M_LOW_LIMB, N_LOW_LIMB);
        vaoSword = createVAO(M_SWORD, N_SWORD); vaoShield = createVAO(M_SHIELD, N_SHIELD);
        vaoRock = createVAO(M_ROCK, N_ROCK); vaoGrass = createVAO(M_GRASS, N_GRASS);
        vaoWheat = createVAO(M_WHEAT, N_WHEAT); vaoTree = createVAO(M_TREE, N_TREE);
        vaoTerrain = createVAO(M_TERRAIN, N_TERRAIN);

        glClearColor(0.5f, 0.7f, 0.9f, 1.0f); // Clean Sky
        glEnable(GL_DEPTH_TEST);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
        glViewport(0,0,w,h);
        float asp = (h <= 0) ? 1.0f : (float)w/h; 
        proj = Mat4::perspective(1.0f, asp, 0.1f, 100.0f);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) slashT=1.0f;
        if(id==2) block=true;
        if(id==3) block=false;
        if(id==4 && jumpT<=0) jumpT=1.0f;
        if(id==6) bashT=1.0f;
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch, jfloat zoom) {
        if(slashT > 0) slashT -= 0.05f;
        if(jumpT > 0) jumpT -= 0.04f;
        if(bashT > 0) bashT -= 0.08f;
        
        if(fabs(ix)>0.0f || fabs(iy)>0.0f) {
            float s=sin(yaw), c=cos(yaw), dx=ix*c-(-iy)*s, dz=ix*s+(-iy)*c;
            px+=dx*0.1f; pz-=dz*0.1f; pf=atan2(-dx,dz); wt+=0.15f;
        } else { wt=0; }
        
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glUseProgram(prog);
        glUniformMatrix4fv(glGetUniformLocation(prog,"pr"),1,GL_FALSE,proj.m);
        
        float jumpY = (jumpT > 0) ? 4.0f * jumpT * (1.0f - jumpT) : 0.0f;
        float th = getTerrainHeight(px, pz);

        // --- CAMERA SYSTEM WITH TERRAIN COLLISION & FIRST PERSON SNAP ---
        bool isFPS = (zoom < 1.5f); // Snap to First Person Mode
        float safeZoom = isFPS ? 0.0f : zoom;
        
        // Target is the player's chest/head
        float targetY = th + 1.2f + jumpY;
        
        // Calculate Camera Orbit Position
        float camX = px - sin(yaw) * cos(pitch) * safeZoom;
        float camZ = pz - cos(yaw) * cos(pitch) * safeZoom;
        float camY = targetY + sin(pitch) * safeZoom;

        // TERRAIN COLLISION: Push camera up if it clips into a hill!
        float camTh = getTerrainHeight(camX, camZ);
        if (camY < camTh + 0.5f && !isFPS) { camY = camTh + 0.5f; }
        if (isFPS) { camY = th + 1.6f + jumpY; } // Eye level

        // Apply True LookAt Matrix
        Mat4 v = Mat4::lookAt(camX, camY, camZ, px, targetY, pz, 0, 1, 0);
        glUniformMatrix4fv(glGetUniformLocation(prog,"v"),1,GL_FALSE,v.m);
        
        GLint lm=glGetUniformLocation(prog,"m"), lt=glGetUniformLocation(prog,"isT");
        Mat4 tBase = Mat4::trans(px, th+1.0f+jumpY, pz).mul(Mat4::rotY(pf));

        // 1. RENDER TERRAIN
        glUniform1f(lt, 1.0f);
        for(int i=-3; i<=3; i++) for(int j=-3; j<=3; j++) {
            float tx=floor(px/16.f)*16.f+i*16.f, tz=floor(pz/16.f)*16.f+j*16.f;
            Mat4 tm=Mat4::trans(tx,0,tz);
            glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoTerrain); glDrawArrays(GL_TRIANGLES,0,N_TERRAIN);
        }

        // 2. RENDER CLUTTER
        glUniform1f(lt, 0.0f);
        for(int i=-16; i<=16; i++) for(int j=-16; j<=16; j++) {
            float tx=floor(px/2.f)*2.f+i*2.f, tz=floor(pz/2.f)*2.f+j*2.f;
            float hsh = hash(tx, tz);
            float ty = getTerrainHeight(tx, tz);
            Mat4 tm=Mat4::trans(tx, ty, tz).mul(Mat4::rotY(hsh * 6.28f));
            
            if(hsh > 0.95f) {
                glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoTree); glDrawArrays(GL_TRIANGLES,0,N_TREE);
            } else if (hsh > 0.90f) {
                glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoRock); glDrawArrays(GL_TRIANGLES,0,N_ROCK);
            } else if (hsh > 0.60f) {
                glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoWheat); glDrawArrays(GL_TRIANGLES,0,N_WHEAT);
            } else if (hsh > 0.10f) {
                glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoGrass); glDrawArrays(GL_TRIANGLES,0,N_GRASS);
            }
        }

        // 3. RENDER CHARACTER
        // In First-Person, we hide the Head and Torso to prevent internal clipping!
        if (!isFPS) {
            glUniformMatrix4fv(lm,1,GL_FALSE,tBase.m); glBindVertexArray(vaoTorso); glDrawArrays(GL_TRIANGLES,0,N_TORSO);
            Mat4 mHead = tBase.mul(Mat4::trans(0, 0.8f, 0));
            glUniformMatrix4fv(lm,1,GL_FALSE,mHead.m); glBindVertexArray(vaoHead); glDrawArrays(GL_TRIANGLES,0,N_HEAD);
        }

        // RIGHT ARM & SHIELD (Fixed Block Alignment)
        float sRot = block ? -1.5f : (bashT > 0 ? -1.8f : sin(wt)*0.5f);
        Mat4 mRArm = tBase.mul(Mat4::trans(-0.35f, 0.6f, 0)).mul(Mat4::rotX(sRot));
        glUniformMatrix4fv(lm,1,GL_FALSE,mRArm.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        
        Mat4 mRFore = mRArm.mul(Mat4::trans(0, -0.35f, 0)).mul(Mat4::rotX(block ? -1.2f : 0.0f)); // Hard elbow bend to block!
        glUniformMatrix4fv(lm,1,GL_FALSE,mRFore.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);

        // Shield mounts on outside of forearm, facing outwards
        Mat4 mShield = mRFore.mul(Mat4::trans(-0.1f, -0.15f, 0)).mul(Mat4::rotZ(1.57f)).mul(Mat4::rotY(-1.57f)); 
        glUniformMatrix4fv(lm,1,GL_FALSE,mShield.m); glBindVertexArray(vaoShield); glDrawArrays(GL_TRIANGLES,0,N_SHIELD);

        // LEFT ARM & SWORD (Fixed Grip)
        float swRot = (slashT > 0) ? -2.5f * sin(slashT * 3.14f) : -sin(wt)*0.5f;
        Mat4 mLArm = tBase.mul(Mat4::trans(0.35f, 0.6f, 0)).mul(Mat4::rotX(swRot));
        glUniformMatrix4fv(lm,1,GL_FALSE,mLArm.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);

        Mat4 mLFore = mLArm.mul(Mat4::trans(0, -0.35f, 0)).mul(Mat4::rotX((slashT > 0) ? -0.8f : 0.0f)); 
        glUniformMatrix4fv(lm,1,GL_FALSE,mLFore.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);

        // Sword held securely in hand, points forward on X-rotation
        Mat4 mSword = mLFore.mul(Mat4::trans(0, -0.35f, 0)).mul(Mat4::rotX(1.57f));
        glUniformMatrix4fv(lm,1,GL_FALSE,mSword.m); glBindVertexArray(vaoSword); glDrawArrays(GL_TRIANGLES,0,N_SWORD);

        // LEGS (Only render if not in First Person, or look down to see them!)
        Mat4 mRLeg = tBase.mul(Mat4::trans(-0.15f, 0.0f, 0)).mul(Mat4::rotX(-sin(wt)*0.8f));
        glUniformMatrix4fv(lm,1,GL_FALSE,mRLeg.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        Mat4 mRLegLow = mRLeg.mul(Mat4::trans(0, -0.35f, 0));
        glUniformMatrix4fv(lm,1,GL_FALSE,mRLegLow.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);

        Mat4 mLLeg = tBase.mul(Mat4::trans(0.15f, 0.0f, 0)).mul(Mat4::rotX(sin(wt)*0.8f));
        glUniformMatrix4fv(lm,1,GL_FALSE,mLLeg.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
        Mat4 mLLegLow = mLLeg.mul(Mat4::trans(0, -0.35f, 0));
        glUniformMatrix4fv(lm,1,GL_FALSE,mLLegLow.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);
    }
}
EOF
