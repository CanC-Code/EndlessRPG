#!/bin/bash
# File: runtime/generate_engine.sh
# Generates app/src/main/cpp/native-lib.cpp
# Features:
#   - Infinite streaming terrain (chunks follow the player, no edge)
#   - Character grounded on terrain at all times
#   - Photorealistic PBR shading (hemisphere ambient + Lambertian + Blinn-Phong)
#   - Procedural sky dome with atmospheric scattering gradient
#   - Animated sun disc + directional light tied to sun position
#   - Moon disc (opposite sun), star-field (night only)
#   - Volumetric-style cloud layer (billboard quads, screen-space fading)
#   - Trees only planted on terrain surface, never in the air
#   - Full articulated character: torso, head, 4 limbs w/ knee bend, feet, sword, shield

set -e
mkdir -p app/src/main/cpp

cat << 'CPPEOF' > app/src/main/cpp/native-lib.cpp
// ════════════════════════════════════════════════════════════════
//  EndlessRPG  —  native-lib.cpp
//  OpenGL ES 3.0  |  Android NDK  |  JNI
//  v3.1 — Infinite world, sky dome, sun/moon/stars/clouds
//         Fixed: shield orientation, sword grip, sky/horizon seam,
//                world object day/night ambient scaling
// ════════════════════════════════════════════════════════════════
#include <jni.h>
#include <GLES3/gl3.h>
#include <android/log.h>
#include <cmath>
#include <cstring>
#include <vector>
#include <algorithm>
#include <array>

#include "models/AllModels.h"

#define TAG  "EndlessRPG"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

// ────────────────────────────────────────────────────────────────
//  Math primitives
// ────────────────────────────────────────────────────────────────
struct V3 { float x, y, z; };
struct V2 { float x, y; };
struct M4 { float m[16]; };

static M4 m4id() {
    M4 r; memset(r.m,0,64);
    r.m[0]=r.m[5]=r.m[10]=r.m[15]=1.f; return r;
}
static M4 m4mul(const M4& a, const M4& b){
    M4 r; memset(r.m,0,64);
    for(int i=0;i<4;i++) for(int j=0;j<4;j++)
        for(int k=0;k<4;k++) r.m[i*4+j]+=a.m[k*4+j]*b.m[i*4+k];
    return r;
}
static M4 m4persp(float fov,float asp,float zn,float zf){
    M4 r=m4id(); float f=1.f/tanf(fov*.5f);
    r.m[0]=f/asp; r.m[5]=f;
    r.m[10]=-(zf+zn)/(zf-zn); r.m[11]=-1.f;
    r.m[14]=-(2.f*zf*zn)/(zf-zn); r.m[15]=0.f; return r;
}
static V3 v3norm(V3 v){
    float l=sqrtf(v.x*v.x+v.y*v.y+v.z*v.z);
    return l>1e-6f?(V3{v.x/l,v.y/l,v.z/l}):V3{0,1,0};
}
static V3 v3cross(V3 a,V3 b){return{a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x};}
static float v3dot(V3 a,V3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
static M4 m4look(V3 eye,V3 at,V3 up){
    V3 f=v3norm({at.x-eye.x,at.y-eye.y,at.z-eye.z});
    V3 s=v3norm(v3cross(f,up));
    V3 u=v3cross(s,f);
    M4 r=m4id();
    r.m[0]=s.x;r.m[4]=s.y;r.m[8] =s.z;
    r.m[1]=u.x;r.m[5]=u.y;r.m[9] =u.z;
    r.m[2]=-f.x;r.m[6]=-f.y;r.m[10]=-f.z;
    r.m[12]=-v3dot(s,eye);r.m[13]=-v3dot(u,eye);r.m[14]=v3dot(f,eye);
    return r;
}
static M4 m4T(float x,float y,float z){M4 r=m4id();r.m[12]=x;r.m[13]=y;r.m[14]=z;return r;}
static M4 m4S(float x,float y,float z){M4 r=m4id();r.m[0]=x;r.m[5]=y;r.m[10]=z;return r;}
static M4 m4RX(float a){M4 r=m4id();r.m[5]=cosf(a);r.m[6]=sinf(a);r.m[9]=-sinf(a);r.m[10]=cosf(a);return r;}
static M4 m4RY(float a){M4 r=m4id();r.m[0]=cosf(a);r.m[2]=-sinf(a);r.m[8]=sinf(a);r.m[10]=cosf(a);return r;}
static M4 m4RZ(float a){M4 r=m4id();r.m[0]=cosf(a);r.m[1]=sinf(a);r.m[4]=-sinf(a);r.m[5]=cosf(a);return r;}
static inline float clamp01(float v){return v<0?0:v>1?1:v;}
static inline float lerp(float a,float b,float t){return a+t*(b-a);}

// ────────────────────────────────────────────────────────────────
//  Procedural terrain — 5-octave fBm, infinite
// ────────────────────────────────────────────────────────────────
static float hash(float x,float y){
    float s=sinf(x*127.1f+y*311.7f)*43758.5453f;
    return s-floorf(s);
}
static float vnoise(float x,float y){
    float ix=floorf(x),iy=floorf(y),fx=x-ix,fy=y-iy;
    float ux=fx*fx*(3.f-2.f*fx),uy=fy*fy*(3.f-2.f*fy);
    return lerp(lerp(hash(ix,iy),hash(ix+1,iy),ux),
                lerp(hash(ix,iy+1),hash(ix+1,iy+1),ux),uy);
}
static float terrH(float wx,float wz){
    float v=0,a=0.60f,s=0.10f;
    for(int i=0;i<6;i++){v+=a*vnoise(wx*s,wz*s);s*=2.05f;a*=0.50f;}
    return v*12.f-1.5f;   // range roughly -1.5 … 10.5
}
static V3 terrNormal(float wx,float wz){
    const float d=0.15f;
    float hL=terrH(wx-d,wz),hR=terrH(wx+d,wz);
    float hD=terrH(wx,wz-d),hU=terrH(wx,wz+d);
    return v3norm({(hL-hR)/(2*d),1.0f,(hD-hU)/(2*d)});
}

// ────────────────────────────────────────────────────────────────
//  GL helpers
// ────────────────────────────────────────────────────────────────
static GLuint compSh(GLenum t,const char* src){
    GLuint s=glCreateShader(t);
    glShaderSource(s,1,&src,nullptr); glCompileShader(s);
    GLint ok; glGetShaderiv(s,GL_COMPILE_STATUS,&ok);
    if(!ok){char b[1024];glGetShaderInfoLog(s,1024,nullptr,b);LOGE("Shader: %s",b);}
    return s;
}
static GLuint linkProg(const char* vs,const char* fs){
    GLuint p=glCreateProgram();
    glAttachShader(p,compSh(GL_VERTEX_SHADER,vs));
    glAttachShader(p,compSh(GL_FRAGMENT_SHADER,fs));
    glLinkProgram(p);
    GLint ok; glGetProgramiv(p,GL_LINK_STATUS,&ok);
    if(!ok){char b[512];glGetProgramInfoLog(p,512,nullptr,b);LOGE("Link: %s",b);}
    return p;
}
// VAO for pos(3)+col(3)  stride=24
static GLuint makeVAO6(const float* d,int n){
    GLuint vao,vbo;
    glGenVertexArrays(1,&vao); glGenBuffers(1,&vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER,(GLsizeiptr)(n*6*sizeof(float)),d,GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,24,(void*)0);  glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,24,(void*)12); glEnableVertexAttribArray(1);
    glBindVertexArray(0); return vao;
}
// VAO for raw float array (no stride template — caller gives byte stride)
static GLuint makeVAOraw(const float* d,size_t bytes,int stride,
                          int a0c,int a0off, int a1c,int a1off){
    GLuint vao,vbo;
    glGenVertexArrays(1,&vao); glGenBuffers(1,&vbo);
    glBindVertexArray(vao); glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER,(GLsizeiptr)bytes,d,GL_STATIC_DRAW);
    glVertexAttribPointer(0,a0c,GL_FLOAT,GL_FALSE,stride,(void*)(uintptr_t)a0off);
    glEnableVertexAttribArray(0);
    if(a1c>0){
        glVertexAttribPointer(1,a1c,GL_FLOAT,GL_FALSE,stride,(void*)(uintptr_t)a1off);
        glEnableVertexAttribArray(1);
    }
    glBindVertexArray(0); return vao;
}

// ════════════════════════════════════════════════════════════════
//  SHADERS
// ════════════════════════════════════════════════════════════════

// ── World objects (character, trees, rocks) ─────────────────────
// FIX: vCol is Lambertian+AO already baked; we scale by a hemisphere
//      ambient tint so objects respond to day/night, then add specular.
//      No second Lambertian multiply — that would double-darken everything.
static const char* WORLD_VS = R"GLSL(#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aCol;
uniform mat4 uMVP;
uniform mat4 uModel;
uniform vec3 uSunDir;
out vec3 vCol;
out vec3 vWorldPos;
out vec3 vNormal;
void main(){
    vec4 wp = uModel * vec4(aPos, 1.0);
    vWorldPos = wp.xyz;
    vCol      = aCol;
    // Derive surface normal from model's up direction for hemisphere
    // ambient and specular — baked colour already has diffuse encoded.
    vNormal   = normalize(mat3(uModel) * vec3(0.0, 1.0, 0.0));
    gl_Position = uMVP * vec4(aPos, 1.0);
}
)GLSL";

static const char* WORLD_FS = R"GLSL(#version 300 es
precision highp float;
in vec3 vCol;
in vec3 vWorldPos;
in vec3 vNormal;
uniform vec3  uSunDir;
uniform vec3  uSunColor;
uniform vec3  uAmbientSky;
uniform vec3  uAmbientGnd;
uniform vec3  uCamPos;
uniform float uFogNear;
uniform float uFogFar;
uniform vec3  uFogColor;
out vec4 FragColor;
void main(){
    // vCol already has Lambertian + AO baked in at model-build time.
    // Scale by hemisphere ambient so objects dim at night / brighten at noon.
    float hemi     = vNormal.y * 0.5 + 0.5;
    vec3  ambScale = mix(uAmbientGnd, uAmbientSky, hemi);
    // Normalise against noon reference so baked colours stay accurate at midday.
    vec3  ambTint  = ambScale / vec3(0.40, 0.50, 0.68);
    vec3  lit      = vCol * clamp(ambTint, 0.08, 1.4);

    // Subtle Blinn-Phong specular on top (not baked, so always additive)
    vec3  V   = normalize(uCamPos - vWorldPos);
    vec3  H   = normalize(uSunDir + V);
    float sp  = pow(max(dot(vNormal, H), 0.0), 48.0);
    lit      += uSunColor * 0.05 * sp;

    // Exponential quadratic fog
    float dist = length(uCamPos - vWorldPos);
    float fog  = clamp((dist - uFogNear) / (uFogFar - uFogNear), 0.0, 1.0);
    fog = fog * fog;
    vec3 color = mix(lit, uFogColor, fog);
    FragColor  = vec4(color, 1.0);
}
)GLSL";

// ── Sky dome ────────────────────────────────────────────────────
// FIX: uFogColor uniform added; horizon blended toward fog colour so
//      sky and terrain meet seamlessly at all times of day.
static const char* SKY_VS = R"GLSL(#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
uniform mat4 uVP;       // no model — always at origin
out vec3 vDir;
void main(){
    vDir = aPos;
    vec4 p = uVP * vec4(aPos * 500.0, 1.0);
    gl_Position = p.xyww;   // always at far plane
}
)GLSL";

static const char* SKY_FS = R"GLSL(#version 300 es
precision highp float;
in vec3 vDir;
uniform vec3  uSunDir;
uniform vec3  uMoonDir;
uniform float uDayFrac;   // 0=midnight, 0.5=noon, 1=midnight
uniform vec3  uFogColor;  // matches C++ fogCol — locks horizon colour
out vec4 FragColor;

vec3 skyColor(vec3 dir, vec3 sun, float dayFrac){
    float up      = max(dir.y, 0.0);
    float sun_ang = max(dot(dir, sun), 0.0);

    vec3 zenithDay   = vec3(0.18, 0.38, 0.80);
    vec3 horizDay    = vec3(0.60, 0.75, 0.92);
    vec3 zenithDusk  = vec3(0.08, 0.08, 0.25);
    vec3 horizDusk   = vec3(0.85, 0.40, 0.15);
    vec3 zenithNight = vec3(0.01, 0.01, 0.06);
    vec3 horizNight  = vec3(0.04, 0.04, 0.10);

    float dusk  = smoothstep(0.0, 0.18, dayFrac) * (1.0 - smoothstep(0.18, 0.36, dayFrac))
                + smoothstep(0.64, 0.82, dayFrac) * (1.0 - smoothstep(0.82, 1.0, dayFrac));
    float night = 1.0 - smoothstep(0.15, 0.35, dayFrac) * smoothstep(0.85, 0.65, dayFrac);
    float day   = 1.0 - dusk - night * 0.5;

    vec3 zenith = zenithDay*day + zenithDusk*dusk + zenithNight*night;
    vec3 horiz  = horizDay*day  + horizDusk*dusk  + horizNight*night;
    vec3 sky    = mix(horiz, zenith, up);

    // Mie scatter glow around sun
    float glow    = pow(sun_ang, 6.0) * 0.45;
    vec3  glowCol = mix(vec3(1.0, 0.85, 0.55), vec3(1.0, 0.95, 0.75), dayFrac);
    sky += glowCol * glow;
    return sky;
}

// Simple 2-level hash noise for stars
float starNoise(vec3 d){
    vec3  f = floor(d * 180.0);
    float s = sin(f.x*127.1 + f.y*311.7 + f.z*74.9)*43758.5;
    return s - floor(s);
}

void main(){
    vec3  dir     = normalize(vDir);
    float dayFrac = uDayFrac;

    // Base atmospheric sky
    vec3 col = skyColor(dir, uSunDir, dayFrac);

    // FIX: blend toward fogCol at the horizon so terrain fog seam disappears.
    // Quadratic ramp: at dir.y==0 blend is 0.85; at dir.y>0.17 blend is 0.
    float horizBlend = clamp(1.0 - dir.y * 6.0, 0.0, 1.0);
    horizBlend = horizBlend * horizBlend;
    col = mix(col, uFogColor, horizBlend * 0.85);

    // Sun disc
    float sunA = dot(dir, uSunDir);
    float disc  = smoothstep(0.9990, 0.9998, sunA);
    float halo  = pow(max(sunA, 0.0), 22.0) * 0.6;
    float night = 1.0 - smoothstep(0.1, 0.3, dayFrac) * smoothstep(0.9, 0.7, dayFrac);
    float dayt  = 1.0 - night;
    col += vec3(1.0, 0.97, 0.80) * disc * dayt;
    col += vec3(1.0, 0.85, 0.50) * halo * dayt;

    // Moon disc (opposite sun, visible at night)
    float moonA    = dot(dir, uMoonDir);
    float moonDisc = smoothstep(0.9993, 0.9999, moonA);
    col += vec3(0.85, 0.88, 0.95) * moonDisc * night;
    // Moon glow
    col += vec3(0.20, 0.22, 0.30) * pow(max(moonA, 0.0), 30.0) * night * 0.5;

    // Stars (only at night, only upward hemisphere)
    if(dir.y > 0.0 && night > 0.01){
        float star    = starNoise(dir);
        float twinkle = smoothstep(0.994, 1.0, star);
        col += vec3(0.9, 0.9, 1.0) * twinkle * night * dir.y;
    }

    FragColor = vec4(col, 1.0);
}
)GLSL";

// ── Cloud billboard ─────────────────────────────────────────────
static const char* CLOUD_VS = R"GLSL(#version 300 es
precision highp float;
layout(location=0) in vec2 aUV;
uniform vec3  uCloudPos;
uniform vec2  uSize;
uniform mat4  uVP;
uniform vec3  uCamRight;
uniform vec3  uCamUp;
out vec2 vUV;
void main(){
    vec3 wp = uCloudPos
            + uCamRight * (aUV.x - 0.5) * uSize.x
            + uCamUp    * (aUV.y - 0.5) * uSize.y;
    vUV = aUV;
    gl_Position = uVP * vec4(wp, 1.0);
}
)GLSL";

static const char* CLOUD_FS = R"GLSL(#version 300 es
precision highp float;
in vec2 vUV;
uniform float uAlpha;
out vec4 FragColor;
float hash2(vec2 p){ float s=sin(p.x*127.1+p.y*311.7)*43758.5; return s-floor(s); }
float noise2(vec2 p){
    vec2 i=floor(p),f=p-i,u=f*f*(3.0-2.0*f);
    return mix(mix(hash2(i),hash2(i+vec2(1,0)),u.x),
               mix(hash2(i+vec2(0,1)),hash2(i+vec2(1,1)),u.x),u.y);
}
void main(){
    vec2  c       = vUV - 0.5;
    float r       = length(c) * 2.0;
    float base    = max(0.0, 1.0 - r * r);
    float n       = noise2(vUV * 5.0) * 0.4 + noise2(vUV * 11.0) * 0.15;
    float density = clamp(base + n - 0.25, 0.0, 1.0);
    float alpha   = density * uAlpha;
    float lit     = 0.75 + vUV.y * 0.25;
    vec3  col     = vec3(lit);
    if(alpha < 0.01) discard;
    FragColor = vec4(col, alpha);
}
)GLSL";

// ── Terrain (own VAO with EBO, height-based vertex colour) ──────
static const char* TERR_VS = R"GLSL(#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aCol;
layout(location=2) in vec3 aNorm;
uniform mat4 uMVP;
uniform mat4 uModel;
out vec3 vCol;
out vec3 vWorldPos;
out vec3 vNormal;
void main(){
    vec4 wp   = uModel * vec4(aPos, 1.0);
    vWorldPos = wp.xyz;
    vCol      = aCol;
    vNormal   = normalize(mat3(uModel) * aNorm);
    gl_Position = uMVP * vec4(aPos, 1.0);
}
)GLSL";

// fragment is the same as WORLD_FS (reuse)

// ════════════════════════════════════════════════════════════════
//  Terrain streaming
// ════════════════════════════════════════════════════════════════
static const int   CHUNK  = 32;
static const float CELL   = 1.0f;
static const int   CRAD   = 4;

struct TerrainChunk {
    int cx, cz;
    GLuint vao=0, vbo=0, ebo=0;
    int idxCount=0;
    bool built=false;
};

static std::vector<TerrainChunk> g_chunks;
static GLuint g_terrProg = 0;

static void buildChunk(TerrainChunk& c){
    int N = CHUNK+1;
    float ox = c.cx * CHUNK * CELL;
    float oz = c.cz * CHUNK * CELL;

    std::vector<float>    verts;
    std::vector<uint32_t> idx;
    verts.reserve(N*N*9);
    idx  .reserve(CHUNK*CHUNK*6);

    for(int z=0;z<N;z++){
        for(int x=0;x<N;x++){
            float wx=ox+x*CELL, wz=oz+z*CELL;
            float wy=terrH(wx,wz);
            V3 n=terrNormal(wx,wz);

            // FIX: smoother grass→earth transition; lerp() used throughout
            float t=clamp01(wy/8.0f);
            float r,g,b;
            if(t<0.10f){                        // water/mud edge
                r=0.25f; g=0.18f; b=0.10f;
            } else if(t<0.42f){                 // lush grass (widened band)
                float f=(t-0.10f)/0.32f;
                r=0.13f+f*0.08f; g=0.43f-f*0.05f; b=0.10f+f*0.03f;
            } else if(t<0.68f){                 // dry grass / earth — smooth lerp
                float f=(t-0.42f)/0.26f;
                r=lerp(0.21f,0.50f,f); g=lerp(0.38f,0.22f,f); b=lerp(0.13f,0.10f,f);
            } else {                            // rock / snowcap approach
                float f=clamp01((t-0.68f)/0.32f);
                r=0.46f+f*0.22f; g=0.42f+f*0.20f; b=0.38f+f*0.22f;
            }
            // AO: slope darkening
            float slopeDark = n.y * 0.35f + 0.65f;
            r*=slopeDark; g*=slopeDark; b*=slopeDark;

            verts.push_back(wx); verts.push_back(wy); verts.push_back(wz);
            verts.push_back(r);  verts.push_back(g);  verts.push_back(b);
            verts.push_back(n.x);verts.push_back(n.y);verts.push_back(n.z);
        }
    }
    for(int z=0;z<CHUNK;z++) for(int x=0;x<CHUNK;x++){
        uint32_t s=z*N+x;
        idx.push_back(s);   idx.push_back(s+N); idx.push_back(s+1);
        idx.push_back(s+1); idx.push_back(s+N); idx.push_back(s+N+1);
    }
    c.idxCount=(int)idx.size();

    glGenVertexArrays(1,&c.vao); glGenBuffers(1,&c.vbo); glGenBuffers(1,&c.ebo);
    glBindVertexArray(c.vao);
    glBindBuffer(GL_ARRAY_BUFFER,c.vbo);
    glBufferData(GL_ARRAY_BUFFER,verts.size()*4,verts.data(),GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,c.ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER,idx.size()*4,idx.data(),GL_STATIC_DRAW);
    const int stride=36;
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,stride,(void*)0);  glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,stride,(void*)12); glEnableVertexAttribArray(1);
    glVertexAttribPointer(2,3,GL_FLOAT,GL_FALSE,stride,(void*)24); glEnableVertexAttribArray(2);
    glBindVertexArray(0);
    c.built=true;
}

static void streamChunks(float px,float pz){
    int pcx=(int)floorf(px/(CHUNK*CELL));
    int pcz=(int)floorf(pz/(CHUNK*CELL));

    g_chunks.erase(std::remove_if(g_chunks.begin(),g_chunks.end(),
        [&](TerrainChunk& c){
            bool far=abs(c.cx-pcx)>CRAD+1||abs(c.cz-pcz)>CRAD+1;
            if(far){glDeleteVertexArrays(1,&c.vao);glDeleteBuffers(1,&c.vbo);glDeleteBuffers(1,&c.ebo);}
            return far;
        }),g_chunks.end());

    for(int dz=-CRAD;dz<=CRAD;dz++) for(int dx=-CRAD;dx<=CRAD;dx++){
        int tx=pcx+dx,tz=pcz+dz;
        bool exists=false;
        for(auto& c:g_chunks) if(c.cx==tx&&c.cz==tz){exists=true;break;}
        if(!exists){
            g_chunks.push_back({tx,tz});
            buildChunk(g_chunks.back());
        }
    }
}

// ════════════════════════════════════════════════════════════════
//  Sky dome
// ════════════════════════════════════════════════════════════════
static GLuint g_skyProg=0, g_skyVAO=0;
static int g_skyIdxCount=0;

static void buildSkyDome(){
    std::vector<float>    verts;
    std::vector<uint32_t> idx;
    const int stacks=14, slices=24;
    for(int st=0;st<=stacks;st++){
        float phi=3.14159f*st/stacks;
        for(int sl=0;sl<=slices;sl++){
            float theta=2*3.14159f*sl/slices;
            verts.push_back(sinf(phi)*cosf(theta));
            verts.push_back(cosf(phi));
            verts.push_back(sinf(phi)*sinf(theta));
        }
    }
    for(int st=0;st<stacks;st++) for(int sl=0;sl<slices;sl++){
        uint32_t a=st*(slices+1)+sl;
        idx.push_back(a); idx.push_back(a+slices+1); idx.push_back(a+1);
        idx.push_back(a+1); idx.push_back(a+slices+1); idx.push_back(a+slices+2);
    }
    GLuint vbo,ebo;
    glGenVertexArrays(1,&g_skyVAO); glGenBuffers(1,&vbo); glGenBuffers(1,&ebo);
    glBindVertexArray(g_skyVAO);
    glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER,verts.size()*4,verts.data(),GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER,idx.size()*4,idx.data(),GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,12,(void*)0); glEnableVertexAttribArray(0);
    glBindVertexArray(0);
    g_skyIdxCount=(int)idx.size();
}

// ════════════════════════════════════════════════════════════════
//  Cloud billboard layer
// ════════════════════════════════════════════════════════════════
static GLuint g_cloudProg=0, g_cloudVAO=0;
static const float CLOUD_UV[]={0,0, 1,0, 1,1, 0,0, 1,1, 0,1};

struct Cloud { float wx,wy,wz, sizeX,sizeY, alpha; };

static std::vector<Cloud> g_clouds;
static float g_cloudOffX=0;

static void seedClouds(float px,float pz){
    g_clouds.clear();
    float base=80.0f;
    for(int i=0;i<16;i++){
        float ang=i*(6.2832f/16.f);
        float r=60.f+hash(float(i)*1.7f,0.f)*120.f;
        float bx=px+cosf(ang)*r, bz=pz+sinf(ang)*r;
        float sz=30.f+hash(float(i)*3.1f,1.f)*40.f;
        float sz2=sz*(0.4f+hash(float(i)*2.3f,2.f)*0.3f);
        float al=0.55f+hash(float(i)*0.9f,3.f)*0.35f;
        g_clouds.push_back({bx,base,bz,sz,sz2,al});
    }
}

// ════════════════════════════════════════════════════════════════
//  Engine state
// ════════════════════════════════════════════════════════════════
static GLuint g_worldProg=0;
static GLuint g_vaoTorso,g_vaoHead,g_vaoUpLimb,g_vaoLowLimb,g_vaoFoot;
static GLuint g_vaoSword,g_vaoShield,g_vaoTree,g_vaoRock;

// Player
static float g_px=0,g_py=0,g_pz=0;
static float g_facing=0,g_walkT=0;
static float g_jumpVY=0,g_jumpY=0;
static float g_slashT=0,g_bashT=0;
static bool  g_block=false;

// Camera
static float g_camYaw=0.7f,g_camPitch=0.42f,g_camZoom=14.f;
static M4    g_proj;
static float g_aspect=1.f;

// Time of day: 0=midnight,0.25=dawn,0.5=noon,0.75=dusk,1=midnight
static float g_dayFrac=0.45f;
static const float DAY_SPEED=0.00005f;

// ════════════════════════════════════════════════════════════════
//  Sun / ambient computation from day fraction
// ════════════════════════════════════════════════════════════════
static void getSunMoon(float df,
    V3& sunDir, V3& sunCol,
    V3& moonDir,
    V3& ambSky, V3& ambGnd,
    V3& fogCol,
    float& fogNear, float& fogFar)
{
    float angle=df*6.2832f-1.5708f;
    sunDir=v3norm({cosf(angle)*0.95f, sinf(angle), cosf(angle)*0.30f});
    moonDir=v3norm({-sunDir.x,-sunDir.y,-sunDir.z});

    float sunUp=clamp01(sunDir.y);
    sunCol={lerp(0.98f,1.00f,sunUp),
            lerp(0.60f,0.96f,sunUp),
            lerp(0.30f,0.88f,sunUp)};

    float night=clamp01(1.f-sunUp*3.f);
    float day=1.f-night;
    ambSky={lerp(0.05f,0.40f,day), lerp(0.05f,0.50f,day), lerp(0.12f,0.68f,day)};
    ambGnd={lerp(0.02f,0.12f,day), lerp(0.02f,0.11f,day), lerp(0.02f,0.08f,day)};

    float dusk=std::max(0.f,1.f-fabsf(df-0.25f)*8.f)+
               std::max(0.f,1.f-fabsf(df-0.75f)*8.f);
    dusk=clamp01(dusk);
    fogCol={lerp(lerp(0.47f,0.80f,dusk),0.03f,night),
            lerp(lerp(0.62f,0.50f,dusk),0.03f,night),
            lerp(lerp(0.88f,0.30f,dusk),0.08f,night)};
    fogNear=g_camZoom*2.8f;
    fogFar =g_camZoom*8.0f+40.f;
}

// ════════════════════════════════════════════════════════════════
//  Draw helpers
// ════════════════════════════════════════════════════════════════
static GLint uMdl,uMVP;

static void drawVAO(GLuint vao,int n,const M4& model,const M4& vp){
    M4 mvp=m4mul(vp,model);
    glUniformMatrix4fv(uMVP, 1,GL_FALSE,mvp.m);
    glUniformMatrix4fv(uMdl, 1,GL_FALSE,model.m);
    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES,0,n);
}

// ════════════════════════════════════════════════════════════════
//  Character
// ════════════════════════════════════════════════════════════════
static void drawCharacter(const M4& base,const M4& vp){
    // Torso
    drawVAO(g_vaoTorso, N_TORSO, base, vp);
    // Head
    drawVAO(g_vaoHead,  N_HEAD,  m4mul(base,m4T(0,.92f,0)), vp);

    // ── Right arm (sword) ──────────────────────────────────────
    // swRot: negative = arm swings forward (attack), positive = arm back (idle swing)
    float swRot=(g_slashT>0)?-2.4f*sinf(g_slashT*3.14159f):-sinf(g_walkT)*.46f;
    M4 mRA=m4mul(m4mul(base,m4T(.41f,.54f,0)),m4RX(swRot));
    drawVAO(g_vaoUpLimb,  N_UP_LIMB,  mRA, vp);
    M4 mRF=m4mul(mRA,m4T(0,-.44f,0));
    drawVAO(g_vaoLowLimb, N_LOW_LIMB, mRF, vp);
    M4 mRH=m4mul(mRF,m4T(0,-.41f,0));
    drawVAO(g_vaoFoot,    N_FOOT,     mRH, vp);

    // FIX: sword — pommel in palm, blade extends upward (+Y in GL space).
    // The arm chain already carries swRot so the slash arc is correct.
    // Small forward (Z) offset clears the wrist geometry.
    M4 mSwPos = m4mul(mRH, m4T(0.0f, 0.04f, 0.06f));
    drawVAO(g_vaoSword, N_SWORD, mSwPos, vp);

    // ── Left arm (shield) ──────────────────────────────────────
    float shRot=g_block?-1.52f:(g_bashT>0?-1.78f: sinf(g_walkT)*.46f);
    M4 mLA=m4mul(m4mul(base,m4T(-.41f,.54f,0)),m4RX(shRot));
    drawVAO(g_vaoUpLimb,  N_UP_LIMB,  mLA, vp);
    M4 mLF=m4mul(mLA,m4T(0,-.44f,0));
    drawVAO(g_vaoLowLimb, N_LOW_LIMB, mLF, vp);

    // FIX: shield — face points forward (-Z world), long axis vertical (+Y).
    // No extra rotation needed; mesh authored correctly in shield.py.
    // Forward Z offset pushes the shield face in front of the forearm.
    M4 mSh = m4mul(mLF, m4T(0.0f, -0.18f, 0.16f));
    drawVAO(g_vaoShield, N_SHIELD, mSh, vp);

    // ── Legs with knee bend ────────────────────────────────────
    float lg=sinf(g_walkT)*.68f;
    // Right leg
    M4 mRL=m4mul(m4mul(base,m4T(.20f,-.09f,0)),m4RX(-lg));
    drawVAO(g_vaoUpLimb,  N_UP_LIMB,  mRL, vp);
    M4 mRS=m4mul(m4mul(mRL,m4T(0,-.44f,0)),m4RX(std::max(0.f,-lg)*.60f));
    drawVAO(g_vaoLowLimb, N_LOW_LIMB, mRS, vp);
    drawVAO(g_vaoFoot,    N_FOOT,     m4mul(mRS,m4T(0,-.42f,0)), vp);
    // Left leg
    M4 mLL=m4mul(m4mul(base,m4T(-.20f,-.09f,0)),m4RX(lg));
    drawVAO(g_vaoUpLimb,  N_UP_LIMB,  mLL, vp);
    M4 mLS=m4mul(m4mul(mLL,m4T(0,-.44f,0)),m4RX(std::max(0.f,lg)*.60f));
    drawVAO(g_vaoLowLimb, N_LOW_LIMB, mLS, vp);
    drawVAO(g_vaoFoot,    N_FOOT,     m4mul(mLS,m4T(0,-.42f,0)), vp);
}

// ════════════════════════════════════════════════════════════════
//  JNI
// ════════════════════════════════════════════════════════════════
extern "C" {

JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onCreated(JNIEnv*,jobject){
    g_worldProg = linkProg(WORLD_VS, WORLD_FS);
    g_terrProg  = linkProg(TERR_VS,  WORLD_FS);
    g_skyProg   = linkProg(SKY_VS,   SKY_FS);
    g_cloudProg = linkProg(CLOUD_VS, CLOUD_FS);

    g_vaoTorso   = makeVAO6(M_TORSO,   N_TORSO);
    g_vaoHead    = makeVAO6(M_HEAD,    N_HEAD);
    g_vaoUpLimb  = makeVAO6(M_UP_LIMB, N_UP_LIMB);
    g_vaoLowLimb = makeVAO6(M_LOW_LIMB,N_LOW_LIMB);
    g_vaoFoot    = makeVAO6(M_FOOT,    N_FOOT);
    g_vaoSword   = makeVAO6(M_SWORD,   N_SWORD);
    g_vaoShield  = makeVAO6(M_SHIELD,  N_SHIELD);
    g_vaoTree    = makeVAO6(M_TREE,    N_TREE);
    g_vaoRock    = makeVAO6(M_ROCK,    N_ROCK);

    buildSkyDome();

    glGenVertexArrays(1,&g_cloudVAO);
    GLuint cvbo; glGenBuffers(1,&cvbo);
    glBindVertexArray(g_cloudVAO);
    glBindBuffer(GL_ARRAY_BUFFER,cvbo);
    glBufferData(GL_ARRAY_BUFFER,sizeof(CLOUD_UV),CLOUD_UV,GL_STATIC_DRAW);
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,8,(void*)0); glEnableVertexAttribArray(0);
    glBindVertexArray(0);

    glEnable(GL_DEPTH_TEST); glDepthFunc(GL_LEQUAL);
    glEnable(GL_CULL_FACE);  glCullFace(GL_BACK);
    glEnable(GL_BLEND);      glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);

    streamChunks(0,0);
    seedClouds(0,0);
    LOGI("Engine v3.1 initialised.");
}

JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onChanged(JNIEnv*,jobject,jint w,jint h){
    glViewport(0,0,w,h);
    g_aspect=(h>0)?(float)w/h:1.f;
    g_proj=m4persp(1.047f,g_aspect,0.1f,600.f);
    LOGI("Surface %dx%d",w,h);
}

JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onDraw(
    JNIEnv*,jobject,
    jfloat ix,jfloat iy,jfloat yaw,jfloat pitch,jfloat zoom)
{
    g_camYaw=yaw; g_camPitch=pitch; g_camZoom=zoom;

    // ── Time of day ──────────────────────────────────────────
    g_dayFrac+=DAY_SPEED;
    if(g_dayFrac>=1.f) g_dayFrac-=1.f;

    V3 sunDir,sunCol,moonDir,ambSky,ambGnd,fogCol;
    float fogNear,fogFar;
    getSunMoon(g_dayFrac,sunDir,sunCol,moonDir,ambSky,ambGnd,fogCol,fogNear,fogFar);

    glClearColor(fogCol.x,fogCol.y,fogCol.z,1.f);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);

    // ── Player movement ──────────────────────────────────────
    bool moving=fabsf(ix)>0.02f||fabsf(iy)>0.02f;
    if(moving){
        float sy=sinf(yaw),cy=cosf(yaw);
        float dx=ix*cy-(-iy)*sy, dz=ix*sy+(-iy)*cy;
        g_px+=dx*0.12f; g_pz-=dz*0.12f;
        g_facing=atan2f(-dx,dz);
        g_walkT+=0.18f;
    }
    g_jumpY+=g_jumpVY; g_jumpVY-=0.022f;
    float gh=terrH(g_px,g_pz);
    if(g_jumpY<gh){g_jumpY=gh;g_jumpVY=0.f;}
    g_py=g_jumpY;

    if(g_slashT>0)g_slashT-=0.055f;
    if(g_bashT >0)g_bashT -=0.085f;

    // ── Stream terrain ───────────────────────────────────────
    streamChunks(g_px,g_pz);

    g_cloudOffX+=0.008f;
    if(g_clouds.empty()) seedClouds(g_px,g_pz);

    // ── Camera ───────────────────────────────────────────────
    float safeZ=std::max(5.f,zoom);
    float eyeX=g_px-sinf(yaw)*cosf(pitch)*safeZ;
    float eyeZ=g_pz-cosf(yaw)*cosf(pitch)*safeZ;
    float eyeY=g_py+sinf(pitch)*safeZ+1.5f;
    float eyeGH=terrH(eyeX,eyeZ)+0.5f;
    if(eyeY<eyeGH) eyeY=eyeGH;
    V3 eye={eyeX,eyeY,eyeZ};
    V3 target={g_px,g_py+1.2f,g_pz};
    M4 view=m4look(eye,target,{0,1,0});
    M4 vp=m4mul(g_proj,view);

    V3 camRight={view.m[0],view.m[4],view.m[8]};
    V3 camUp   ={view.m[1],view.m[5],view.m[9]};

    // ── 1. SKY (depth write off) ──────────────────────────────
    glDepthMask(GL_FALSE);
    glDisable(GL_CULL_FACE);
    glUseProgram(g_skyProg);
    M4 skyView=view;
    skyView.m[12]=0;skyView.m[13]=0;skyView.m[14]=0;
    M4 skyVP=m4mul(g_proj,skyView);
    glUniformMatrix4fv(glGetUniformLocation(g_skyProg,"uVP"),1,GL_FALSE,skyVP.m);
    glUniform3f(glGetUniformLocation(g_skyProg,"uSunDir"), sunDir.x,sunDir.y,sunDir.z);
    glUniform3f(glGetUniformLocation(g_skyProg,"uMoonDir"),moonDir.x,moonDir.y,moonDir.z);
    glUniform1f(glGetUniformLocation(g_skyProg,"uDayFrac"),g_dayFrac);
    // FIX: pass fogCol so sky horizon matches terrain fog exactly
    glUniform3f(glGetUniformLocation(g_skyProg,"uFogColor"),fogCol.x,fogCol.y,fogCol.z);
    glBindVertexArray(g_skyVAO);
    glDrawElements(GL_TRIANGLES,g_skyIdxCount,GL_UNSIGNED_INT,nullptr);
    glDepthMask(GL_TRUE);
    glEnable(GL_CULL_FACE);

    // ── 2. TERRAIN ────────────────────────────────────────────
    glUseProgram(g_terrProg);
    GLint tMVP=glGetUniformLocation(g_terrProg,"uMVP");
    GLint tMdl=glGetUniformLocation(g_terrProg,"uModel");
    glUniform3f(glGetUniformLocation(g_terrProg,"uSunDir"),    sunDir.x,sunDir.y,sunDir.z);
    glUniform3f(glGetUniformLocation(g_terrProg,"uSunColor"),  sunCol.x,sunCol.y,sunCol.z);
    glUniform3f(glGetUniformLocation(g_terrProg,"uAmbientSky"),ambSky.x,ambSky.y,ambSky.z);
    glUniform3f(glGetUniformLocation(g_terrProg,"uAmbientGnd"),ambGnd.x,ambGnd.y,ambGnd.z);
    glUniform3f(glGetUniformLocation(g_terrProg,"uCamPos"),    eye.x,eye.y,eye.z);
    glUniform1f(glGetUniformLocation(g_terrProg,"uFogNear"),   fogNear);
    glUniform1f(glGetUniformLocation(g_terrProg,"uFogFar"),    fogFar);
    glUniform3f(glGetUniformLocation(g_terrProg,"uFogColor"),  fogCol.x,fogCol.y,fogCol.z);
    M4 identity=m4id();
    glUniformMatrix4fv(tMdl,1,GL_FALSE,identity.m);
    for(auto& ch:g_chunks){
        M4 mvp=m4mul(g_proj,m4mul(view,identity));
        glUniformMatrix4fv(tMVP,1,GL_FALSE,mvp.m);
        glBindVertexArray(ch.vao);
        glDrawElements(GL_TRIANGLES,ch.idxCount,GL_UNSIGNED_INT,nullptr);
    }

    // ── 3. WORLD OBJECTS ─────────────────────────────────────
    glUseProgram(g_worldProg);
    uMVP=glGetUniformLocation(g_worldProg,"uMVP");
    uMdl=glGetUniformLocation(g_worldProg,"uModel");
    glUniform3f(glGetUniformLocation(g_worldProg,"uSunDir"),    sunDir.x,sunDir.y,sunDir.z);
    glUniform3f(glGetUniformLocation(g_worldProg,"uSunColor"),  sunCol.x,sunCol.y,sunCol.z);
    glUniform3f(glGetUniformLocation(g_worldProg,"uAmbientSky"),ambSky.x,ambSky.y,ambSky.z);
    glUniform3f(glGetUniformLocation(g_worldProg,"uAmbientGnd"),ambGnd.x,ambGnd.y,ambGnd.z);
    glUniform3f(glGetUniformLocation(g_worldProg,"uCamPos"),    eye.x,eye.y,eye.z);
    glUniform1f(glGetUniformLocation(g_worldProg,"uFogNear"),   fogNear);
    glUniform1f(glGetUniformLocation(g_worldProg,"uFogFar"),    fogFar);
    glUniform3f(glGetUniformLocation(g_worldProg,"uFogColor"),  fogCol.x,fogCol.y,fogCol.z);

    // Trees — on terrain surface, hash-filtered
    int pcx=(int)floorf(g_px/8.f), pcz=(int)floorf(g_pz/8.f);
    for(int dz=-7;dz<=7;dz++) for(int dx=-7;dx<=7;dx++){
        float tx=(pcx+dx)*8.f, tz=(pcz+dz)*8.f;
        float h1=hash(tx*.031f,tz*.047f);
        if(h1<0.52f) continue;
        float ty=terrH(tx,tz);
        if(ty>7.5f) continue;
        V3 tn=terrNormal(tx,tz);
        if(tn.y<0.72f) continue;
        float rot=hash(tx*.13f,tz*.19f)*6.2832f;
        float scl=0.85f+hash(tx*.07f,tz*.11f)*0.35f;
        M4 tm=m4mul(m4mul(m4T(tx,ty,tz),m4RY(rot)),m4S(scl,scl,scl));
        drawVAO(g_vaoTree,N_TREE,tm,vp);
    }

    // Rocks
    for(int dz=-5;dz<=5;dz++) for(int dx=-5;dx<=5;dx++){
        float rx=(pcx+dx)*5.f+2.5f, rz=(pcz+dz)*5.f+2.5f;
        float hr=hash(rx*.053f+9.f,rz*.067f);
        if(hr<0.75f) continue;
        float ry=terrH(rx,rz);
        M4 rm=m4mul(m4T(rx,ry,rz),m4RY(hr*6.2832f));
        drawVAO(g_vaoRock,N_ROCK,rm,vp);
    }

    // ── 4. CHARACTER ─────────────────────────────────────────
    bool move=fabsf(ix)>0.02f||fabsf(iy)>0.02f;
    float bobY=move?sinf(g_walkT*2.f)*0.025f:0.f;
    float groundOffset=g_py-terrH(g_px,g_pz);
    M4 charBase=m4mul(m4T(g_px,g_py+0.98f+bobY,g_pz),m4RY(g_facing));
    drawCharacter(charBase,vp);

    // ── 5. CLOUDS (alpha-blended last) ───────────────────────
    glDepthMask(GL_FALSE);
    glDisable(GL_CULL_FACE);
    glUseProgram(g_cloudProg);
    GLint ucPos=glGetUniformLocation(g_cloudProg,"uCloudPos");
    GLint ucSz =glGetUniformLocation(g_cloudProg,"uSize");
    GLint ucVP =glGetUniformLocation(g_cloudProg,"uVP");
    GLint ucCR =glGetUniformLocation(g_cloudProg,"uCamRight");
    GLint ucCU =glGetUniformLocation(g_cloudProg,"uCamUp");
    GLint ucAl =glGetUniformLocation(g_cloudProg,"uAlpha");
    glUniformMatrix4fv(ucVP,1,GL_FALSE,vp.m);
    glUniform3f(ucCR,camRight.x,camRight.y,camRight.z);
    glUniform3f(ucCU,camUp.x,camUp.y,camUp.z);
    glBindVertexArray(g_cloudVAO);
    for(auto& cl:g_clouds){
        float cx=cl.wx+g_cloudOffX;
        glUniform3f(ucPos,cx,cl.wy,cl.wz);
        glUniform2f(ucSz,cl.sizeX,cl.sizeY);
        glUniform1f(ucAl,cl.alpha);
        glDrawArrays(GL_TRIANGLES,0,6);
    }
    glDepthMask(GL_TRUE);
    glEnable(GL_CULL_FACE);
}

JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*,jobject,jint id){
    switch(id){
        case 1: g_slashT=1.f; break;
        case 2: g_block=true; break;
        case 3: g_block=false; break;
        case 4: if(g_jumpY<=terrH(g_px,g_pz)+0.08f) g_jumpVY=0.40f; break;
        case 6: g_bashT=1.f; g_block=false; break;
    }
}

JNIEXPORT jfloat JNICALL
Java_com_game_procedural_MainActivity_getCameraYaw(JNIEnv*,jobject){
    return g_camYaw;
}

} // extern "C"
CPPEOF

echo "[generate_engine.sh] native-lib.cpp written."
