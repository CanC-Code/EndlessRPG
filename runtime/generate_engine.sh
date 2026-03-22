#!/bin/bash
# File: runtime/generate_engine.sh
# Purpose: HD Realistic Render Engine with true-direction walking math.

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

struct Vec3 { float x, y, z; };
Vec3 sub(Vec3 a, Vec3 b) { return {a.x-b.x, a.y-b.y, a.z-b.z}; }
Vec3 cross(Vec3 a, Vec3 b) { return {a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x}; }
float dot(Vec3 a, Vec3 b) { return a.x*b.x + a.y*b.y + a.z*b.z; }
Vec3 norm(Vec3 a) { float l = sqrt(dot(a,a)); return l>0 ? Vec3{a.x/l, a.y/l, a.z/l} : Vec3{0,1,0}; }

struct Mat4 {
    float m[16] = {0};
    static Mat4 identity() { Mat4 r; r.m[0]=1; r.m[5]=1; r.m[10]=1; r.m[15]=1; return r; }
    static Mat4 perspective(float f, float a, float n, float fr) {
        Mat4 r; float t = 1.0f/tan(f/2.0f); 
        r.m[0]=t/a; r.m[5]=t; r.m[10]=-(fr+n)/(fr-n); r.m[11]=-1.0f; r.m[14]=-(2.0f*fr*n)/(fr-n); 
        return r;
    }
    static Mat4 lookAt(Vec3 eye, Vec3 target, Vec3 up) {
        Vec3 f = norm(sub(target, eye));
        Vec3 s = norm(cross(f, up));
        Vec3 u = cross(s, f);
        Mat4 r = identity();
        r.m[0]=s.x; r.m[4]=s.y; r.m[8]=s.z;
        r.m[1]=u.x; r.m[5]=u.y; r.m[9]=u.z;
        r.m[2]=-f.x; r.m[6]=-f.y; r.m[10]=-f.z;
        r.m[12]= -dot(s,eye); r.m[13]= -dot(u,eye); r.m[14]= dot(f,eye);
        return r;
    }
    Mat4 mul(const Mat4& b) const {
        Mat4 r; for(int i=0; i<4; i++) for(int j=0; j<4; j++) for(int k=0; k<4; k++) r.m[i*4+j]+=m[k*4+j]*b.m[i*4+k]; return r;
    }
    static Mat4 trans(float x, float y, float z) { Mat4 r=identity(); r.m[12]=x; r.m[13]=y; r.m[14]=z; return r; }
    static Mat4 rotY(float a) { Mat4 r=identity(); r.m[0]=cos(a); r.m[2]=-sin(a); r.m[8]=sin(a); r.m[10]=cos(a); return r; }
    static Mat4 rotX(float a) { Mat4 r=identity(); r.m[5]=cos(a); r.m[6]=sin(a); r.m[9]=-sin(a); r.m[10]=cos(a); return r; }
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
    glBufferData(GL_ARRAY_BUFFER, n*44, d, GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,44,(void*)0); glEnableVertexAttribArray(0);  
    glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,44,(void*)12); glEnableVertexAttribArray(1); 
    glVertexAttribPointer(2,3,GL_FLOAT,GL_FALSE,44,(void*)24); glEnableVertexAttribArray(2); 
    return vao;
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onCreated(JNIEnv*, jobject) {
        const char* vS = "#version 300 es\n"
            "layout(location=0) in vec3 p; layout(location=1) in vec3 n; layout(location=2) in vec3 c;\n"
            "uniform mat4 m,v,pr; uniform float uType; uniform float uTime;\n"
            "out vec3 vPos; out vec3 vNorm; out vec3 vCol;\n"
            "void main(){\n"
            "  vec3 pos = p;\n"
            "  if(uType == 1.0) pos.y += sin(pos.x*0.4)*cos(pos.z*0.4)*1.5;\n"
            "  if(uType == 2.0 && pos.y > 0.05) {\n"
            "      float sway = (pos.y * pos.y); \n" 
            "      pos.x += sin(uTime * 3.0 + m[3][0] + m[3][2]) * 0.2 * sway;\n"
            "      pos.z += cos(uTime * 2.5 + m[3][0] + m[3][2]) * 0.2 * sway;\n"
            "  }\n"
            "  vec4 w = m * vec4(pos, 1.0);\n"
            "  vPos = w.xyz; vNorm = mat3(m) * n; vCol = c;\n"
            "  gl_Position = pr * v * w;\n"
            "}";
        
        // PURE REALISM SHADER (No sketching, just HD light, shadows, and fog)
        const char* fS = "#version 300 es\n"
            "precision highp float;\n"
            "in vec3 vPos; in vec3 vNorm; in vec3 vCol;\n"
            "uniform vec3 uCamPos; uniform float uType;\n"
            "out vec4 o;\n"
            "void main(){\n"
            "  vec3 norm = normalize(vNorm);\n"
            "  vec3 lightDir = normalize(vec3(0.5, 1.0, 0.4));\n"
            "  \n"
            "  float ambient = 0.35;\n"
            "  float diff = max(dot(norm, lightDir), 0.0);\n"
            "  vec3 diffuse = diff * vCol;\n"
            "  \n"
            "  // Subsurface scattering approximation for grass/leaves (light passing through)\n"
            "  if(uType == 2.0) {\n"
            "      float backLight = max(dot(norm, -lightDir), 0.0) * 0.4;\n"
            "      diffuse += vCol * backLight * vec3(0.8, 1.0, 0.4);\n"
            "  }\n"
            "  \n"
            "  vec3 col = (ambient * vCol) + diffuse;\n"
            "  \n"
            "  // HD Atmospheric Fog\n"
            "  float dist = length(vPos - uCamPos);\n"
            "  float fog = smoothstep(15.0, 45.0, dist);\n"
            "  vec3 sky = vec3(0.6, 0.75, 0.9);\n"
            "  o = vec4(mix(col, sky, fog), 1.0);\n"
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

        glClearColor(0.6f, 0.75f, 0.9f, 1.0f); // Clean, realistic daytime sky
        glEnable(GL_DEPTH_TEST);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onChanged(JNIEnv*, jobject, jint w, jint h) {
        glViewport(0,0,w,h);
        float asp = (h <= 0) ? 1.0f : (float)w/h; 
        proj = Mat4::perspective(1.1f, asp, 0.1f, 100.0f);
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*, jobject, jint id) {
        if(id==1) slashT=1.0f;
        if(id==2) block=true;
        if(id==3) block=false;
        if(id==4 && jumpT<=0) jumpT=1.0f;
        if(id==6) bashT=1.0f;
    }

    JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_onDraw(JNIEnv*, jobject, jfloat ix, jfloat iy, jfloat yaw, jfloat pitch, jfloat zoom) {
        wt += 0.05f; 
        if(slashT > 0) slashT -= 0.05f;
        if(jumpT > 0) jumpT -= 0.04f;
        if(bashT > 0) bashT -= 0.08f;
        
        // ORIENTATION FIX: Character rotation precisely matches the movement vector!
        if(fabs(ix)>0.0f || fabs(iy)>0.0f) {
            float speed = 0.12f;
            float moveX = (ix * cos(yaw) + iy * sin(yaw)) * speed;
            float moveZ = (-ix * sin(yaw) + iy * cos(yaw)) * speed;
            px += moveX; pz += moveZ; 
            pf = atan2(moveX, moveZ); // Math mathematically aligned so torso faces exact walking trajectory.
        }
        
        glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glUseProgram(prog);
        glUniformMatrix4fv(glGetUniformLocation(prog,"pr"),1,GL_FALSE,proj.m);
        glUniform1f(glGetUniformLocation(prog, "uTime"), wt);
        
        float jumpY = (jumpT > 0) ? 4.0f * jumpT * (1.0f - jumpT) : 0.0f;
        float th = getTerrainHeight(px, pz);
        float pHead = th + 1.5f + jumpY; 

        bool isFPS = (zoom < 2.0f);
        float actualZoom = isFPS ? 0.0f : zoom;
        float camX = px + actualZoom * sin(yaw) * cos(pitch);
        float camY = pHead + actualZoom * sin(pitch);
        float camZ = pz + actualZoom * cos(yaw) * cos(pitch);

        if (!isFPS) {
            float camTh = getTerrainHeight(camX, camZ);
            if (camY < camTh + 0.4f) { camY = camTh + 0.4f; }
        }

        glUniform3f(glGetUniformLocation(prog, "uCamPos"), camX, camY, camZ);
        Mat4 v = Mat4::lookAt({camX, camY, camZ}, {px, pHead - (isFPS ? 0.0f : 0.4f), pz}, {0, 1, 0});
        glUniformMatrix4fv(glGetUniformLocation(prog,"v"),1,GL_FALSE,v.m);
        
        GLint lm=glGetUniformLocation(prog,"m"), lt=glGetUniformLocation(prog,"uType");

        // 1. TERRAIN
        glUniform1f(lt, 1.0f);
        for(int i=-4; i<=4; i++) for(int j=-4; j<=4; j++) {
            float tx=floor(px/16.f)*16.f+i*16.f, tz=floor(pz/16.f)*16.f+j*16.f;
            Mat4 tm=Mat4::trans(tx,0,tz);
            glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoTerrain); glDrawArrays(GL_TRIANGLES,0,N_TERRAIN);
        }

        // 2. CLUTTER
        for(int i=-16; i<=16; i++) for(int j=-16; j<=16; j++) {
            float tx=floor(px/1.5f)*1.5f+i*1.5f, tz=floor(pz/1.5f)*1.5f+j*1.5f;
            float hsh = hash(tx, tz);
            float ty = getTerrainHeight(tx, tz);
            Mat4 tm=Mat4::trans(tx, ty, tz).mul(Mat4::rotY(hsh * 6.28f));
            
            if(hsh > 0.97f) {
                glUniform1f(lt, 0.0f); glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoTree); glDrawArrays(GL_TRIANGLES,0,N_TREE);
            } else if (hsh > 0.90f) {
                glUniform1f(lt, 0.0f); glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoRock); glDrawArrays(GL_TRIANGLES,0,N_ROCK);
            } else if (hsh > 0.65f) {
                glUniform1f(lt, 2.0f); glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoWheat); glDrawArrays(GL_TRIANGLES,0,N_WHEAT);
            } else if (hsh > 0.15f) {
                glUniform1f(lt, 2.0f); glUniformMatrix4fv(lm,1,GL_FALSE,tm.m); glBindVertexArray(vaoGrass); glDrawArrays(GL_TRIANGLES,0,N_GRASS);
            }
        }

        // 3. HD CHARACTER RENDERING
        if (!isFPS) {
            glUniform1f(lt, 0.0f);
            Mat4 tBase = Mat4::trans(px, th+1.0f+jumpY, pz).mul(Mat4::rotY(pf));

            glUniformMatrix4fv(lm,1,GL_FALSE,tBase.m); glBindVertexArray(vaoTorso); glDrawArrays(GL_TRIANGLES,0,N_TORSO);
            Mat4 mHead = tBase.mul(Mat4::trans(0, 0.8f, 0));
            glUniformMatrix4fv(lm,1,GL_FALSE,mHead.m); glBindVertexArray(vaoHead); glDrawArrays(GL_TRIANGLES,0,N_HEAD);

            // RIGHT ARM & SHIELD
            float sRot = block ? -1.5f : (bashT > 0 ? -1.8f : sin(wt*4.0f)*0.2f);
            Mat4 mRArm = tBase.mul(Mat4::trans(-0.38f, 0.6f, 0)).mul(Mat4::rotX(sRot));
            glUniformMatrix4fv(lm,1,GL_FALSE,mRArm.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
            
            Mat4 mRFore = mRArm.mul(Mat4::trans(0, -0.35f, 0)).mul(Mat4::rotX(block ? -0.8f : 0.0f)); 
            glUniformMatrix4fv(lm,1,GL_FALSE,mRFore.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);

            Mat4 mShield = mRFore.mul(Mat4::trans(-0.05f, -0.15f, 0)); 
            glUniformMatrix4fv(lm,1,GL_FALSE,mShield.m); glBindVertexArray(vaoShield); glDrawArrays(GL_TRIANGLES,0,N_SHIELD);

            // LEFT ARM & SWORD
            float swRot = (slashT > 0) ? -2.5f * sin(slashT * 3.14f) : -sin(wt*4.0f)*0.2f;
            Mat4 mLArm = tBase.mul(Mat4::trans(0.38f, 0.6f, 0)).mul(Mat4::rotX(swRot));
            glUniformMatrix4fv(lm,1,GL_FALSE,mLArm.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
            
            Mat4 mLFore = mLArm.mul(Mat4::trans(0, -0.35f, 0)).mul(Mat4::rotX((slashT > 0) ? -0.5f : 0.0f)); 
            glUniformMatrix4fv(lm,1,GL_FALSE,mLFore.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);

            Mat4 mSword = mLFore.mul(Mat4::trans(0, -0.35f, 0));
            glUniformMatrix4fv(lm,1,GL_FALSE,mSword.m); glBindVertexArray(vaoSword); glDrawArrays(GL_TRIANGLES,0,N_SWORD);

            // LEGS
            Mat4 mRLeg = tBase.mul(Mat4::trans(-0.15f, 0.0f, 0)).mul(Mat4::rotX(-sin(wt*4.0f)*0.6f));
            glUniformMatrix4fv(lm,1,GL_FALSE,mRLeg.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
            Mat4 mRLegLow = mRLeg.mul(Mat4::trans(0, -0.35f, 0));
            glUniformMatrix4fv(lm,1,GL_FALSE,mRLegLow.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);

            Mat4 mLLeg = tBase.mul(Mat4::trans(0.15f, 0.0f, 0)).mul(Mat4::rotX(sin(wt*4.0f)*0.6f));
            glUniformMatrix4fv(lm,1,GL_FALSE,mLLeg.m); glBindVertexArray(vaoUpLimb); glDrawArrays(GL_TRIANGLES,0,N_UP_LIMB);
            Mat4 mLLegLow = mLLeg.mul(Mat4::trans(0, -0.35f, 0));
            glUniformMatrix4fv(lm,1,GL_FALSE,mLLegLow.m); glBindVertexArray(vaoLowLimb); glDrawArrays(GL_TRIANGLES,0,N_LOW_LIMB);
        }
    }
}
EOF
