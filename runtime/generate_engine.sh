#!/bin/bash
# File: runtime/generate_engine.sh
# EndlessRPG v5
# - Pencil/ink art style: cel-quantised tones, screen-space edge darkening,
#   crosshatch AO approximation, desaturated palette
# - Truly infinite terrain: CRAD=5, chunk size 48, 7-octave fBm no visible edge
# - Moonlight: separate moon direction contributes Lambertian + blue-silver ambient
# - Shield: world-space orientation — always faces character's forward direction,
#   point hanging downward. No spurious local-arm rotation.
# - Character: knight proportions, broader torso
# - Trees: larger draw radius, pencil shading
# - Realistic night: deep blue-black ink fog, silver moonlight rim

set -e
mkdir -p app/src/main/cpp

cat << 'CPPEOF' > app/src/main/cpp/native-lib.cpp
// ════════════════════════════════════════════════════════════════
//  EndlessRPG  —  native-lib.cpp  v5
//  Pencil-ink art  |  Infinite world  |  Moonlight  |  Knight
// ════════════════════════════════════════════════════════════════
#include <jni.h>
#include <GLES3/gl3.h>
#include <android/log.h>
#include <cmath>
#include <cstring>
#include <vector>
#include <algorithm>

#include "models/AllModels.h"

#define TAG "EndlessRPG"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

// ────────────────────────────────────────────────────────────────
//  Math
// ────────────────────────────────────────────────────────────────
struct V3{float x,y,z;};
struct M4{float m[16];};

static M4 m4id(){M4 r;memset(r.m,0,64);r.m[0]=r.m[5]=r.m[10]=r.m[15]=1.f;return r;}
static M4 m4mul(const M4& a,const M4& b){
    M4 r;memset(r.m,0,64);
    for(int i=0;i<4;i++)for(int j=0;j<4;j++)for(int k=0;k<4;k++)
        r.m[i*4+j]+=a.m[k*4+j]*b.m[i*4+k];
    return r;
}
static M4 m4persp(float fov,float asp,float zn,float zf){
    M4 r=m4id();float f=1.f/tanf(fov*.5f);
    r.m[0]=f/asp;r.m[5]=f;r.m[10]=-(zf+zn)/(zf-zn);r.m[11]=-1.f;
    r.m[14]=-(2.f*zf*zn)/(zf-zn);r.m[15]=0.f;return r;
}
static V3 v3norm(V3 v){float l=sqrtf(v.x*v.x+v.y*v.y+v.z*v.z);return l>1e-6f?(V3{v.x/l,v.y/l,v.z/l}):V3{0,1,0};}
static V3 v3cross(V3 a,V3 b){return{a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x};}
static float v3dot(V3 a,V3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
static M4 m4look(V3 eye,V3 at,V3 up){
    V3 f=v3norm({at.x-eye.x,at.y-eye.y,at.z-eye.z});
    V3 s=v3norm(v3cross(f,up));V3 u=v3cross(s,f);
    M4 r=m4id();
    r.m[0]=s.x;r.m[4]=s.y;r.m[8]=s.z;
    r.m[1]=u.x;r.m[5]=u.y;r.m[9]=u.z;
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
static inline float lerpf(float a,float b,float t){return a+t*(b-a);}

// ────────────────────────────────────────────────────────────────
//  Terrain — 7-octave fBm, no visible repetition within play range
// ────────────────────────────────────────────────────────────────
static float hash(float x,float y){float s=sinf(x*127.1f+y*311.7f)*43758.5453f;return s-floorf(s);}
static float vnoise(float x,float y){
    float ix=floorf(x),iy=floorf(y),fx=x-ix,fy=y-iy;
    float ux=fx*fx*(3.f-2.f*fx),uy=fy*fy*(3.f-2.f*fy);
    return lerpf(lerpf(hash(ix,iy),hash(ix+1,iy),ux),lerpf(hash(ix,iy+1),hash(ix+1,iy+1),ux),uy);
}
static float terrH(float wx,float wz){
    float v=0,a=0.55f,s=0.08f;
    for(int i=0;i<7;i++){v+=a*vnoise(wx*s,wz*s);s*=2.07f;a*=0.48f;}
    return v*14.f-2.f;
}
static V3 terrNormal(float wx,float wz){
    const float d=0.18f;
    return v3norm({(terrH(wx-d,wz)-terrH(wx+d,wz))/(2*d),1.0f,(terrH(wx,wz-d)-terrH(wx,wz+d))/(2*d)});
}
static float muddiness(float wx,float wz){return clamp01(1.f-terrH(wx,wz)/1.5f);}
static float drynessT (float wx,float wz){return clamp01((terrH(wx,wz)-3.5f)/5.f);}

// ────────────────────────────────────────────────────────────────
//  GL helpers
// ────────────────────────────────────────────────────────────────
static GLuint compSh(GLenum t,const char* src){
    GLuint s=glCreateShader(t);glShaderSource(s,1,&src,nullptr);glCompileShader(s);
    GLint ok;glGetShaderiv(s,GL_COMPILE_STATUS,&ok);
    if(!ok){char b[2048];glGetShaderInfoLog(s,2048,nullptr,b);LOGE("Shader:\n%s",b);}
    return s;
}
static GLuint linkProg(const char* vs,const char* fs){
    GLuint p=glCreateProgram();
    glAttachShader(p,compSh(GL_VERTEX_SHADER,vs));
    glAttachShader(p,compSh(GL_FRAGMENT_SHADER,fs));
    glLinkProgram(p);GLint ok;glGetProgramiv(p,GL_LINK_STATUS,&ok);
    if(!ok){char b[512];glGetProgramInfoLog(p,512,nullptr,b);LOGE("Link:%s",b);}
    return p;
}
static GLuint makeVAO6(const float* d,int n){
    GLuint vao,vbo;glGenVertexArrays(1,&vao);glGenBuffers(1,&vbo);
    glBindVertexArray(vao);glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER,(GLsizeiptr)(n*6*sizeof(float)),d,GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,24,(void*)0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,24,(void*)12);glEnableVertexAttribArray(1);
    glBindVertexArray(0);return vao;
}

// ════════════════════════════════════════════════════════════════
//  SHADERS  — Pencil/Ink Art
// ════════════════════════════════════════════════════════════════

static const char* WORLD_VS = R"GLSL(#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aCol;
uniform mat4 uMVP; uniform mat4 uModel;
out vec3 vCol; out vec3 vWorldPos; out vec3 vNormal;
void main(){
    vec4 wp=uModel*vec4(aPos,1.0);
    vWorldPos=wp.xyz; vCol=aCol;
    vNormal=normalize(mat3(uModel)*vec3(0.0,1.0,0.0));
    gl_Position=uMVP*vec4(aPos,1.0);
}
)GLSL";

static const char* WORLD_FS = R"GLSL(#version 300 es
precision highp float;
in vec3 vCol; in vec3 vWorldPos; in vec3 vNormal;
uniform vec3  uSunDir,uSunColor,uMoonDir,uMoonColor;
uniform vec3  uAmbientSky,uAmbientGnd,uCamPos,uFogColor;
uniform float uFogNear,uFogFar,uNight;
out vec4 FragColor;

float hatch(vec3 p){
    vec3 g=floor(p*3.6);
    float s=sin(g.x*127.1+g.y*311.7+g.z*74.9)*43758.5;
    return s-floor(s);
}
float cel(float v){
    if(v<0.15) return 0.04;
    if(v<0.38) return 0.24;
    if(v<0.68) return 0.55;
    return 0.88;
}
void main(){
    vec3 N=normalize(vNormal);
    vec3 V=normalize(uCamPos-vWorldPos);
    float hemi=N.y*0.5+0.5;
    vec3 amb=mix(uAmbientGnd,uAmbientSky,hemi);
    float NdS=max(dot(N,uSunDir),0.0);
    float NdM=max(dot(N,uMoonDir),0.0);
    float sunDiff=cel(NdS)*(1.0-uNight);
    float moonDiff=cel(NdM)*uNight*0.55;
    vec3 diffuse=uSunColor*sunDiff+uMoonColor*moonDiff;
    float shadow=1.0-clamp(NdS+NdM*0.4,0.0,1.0);
    float hatchAO=1.0-shadow*hatch(vWorldPos)*0.38;
    vec3 lit=(amb+diffuse)*vCol*hatchAO;
    float grey=dot(lit,vec3(0.299,0.587,0.114));
    lit=mix(lit,vec3(grey),0.44);
    float rim=pow(1.0-clamp(dot(N,V),0.0,1.0),2.8)*0.58;
    lit=mix(lit,vec3(0.02,0.02,0.03),rim);
    float moonRim=pow(clamp(dot(N,-uMoonDir),0.0,1.0),4.0)*uNight*0.28;
    lit+=uMoonColor*moonRim;
    float dist=length(uCamPos-vWorldPos);
    float fog=clamp((dist-uFogNear)/(uFogFar-uFogNear),0.0,1.0);
    fog=fog*fog*(2.0-fog);
    fog=clamp(fog*(1.0+uNight*0.45),0.0,1.0);
    FragColor=vec4(mix(lit,uFogColor,fog),1.0);
}
)GLSL";

static const char* TERR_VS = R"GLSL(#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aCol;
layout(location=2) in vec3 aNorm;
uniform mat4 uMVP; uniform mat4 uModel;
out vec3 vCol; out vec3 vWorldPos; out vec3 vNormal;
void main(){
    vec4 wp=uModel*vec4(aPos,1.0);
    vWorldPos=wp.xyz; vCol=aCol;
    vNormal=normalize(mat3(uModel)*aNorm);
    gl_Position=uMVP*vec4(aPos,1.0);
}
)GLSL";

static const char* SKY_VS = R"GLSL(#version 300 es
precision highp float;
layout(location=0) in vec3 aPos;
uniform mat4 uVP; out vec3 vDir;
void main(){vDir=aPos;vec4 p=uVP*vec4(aPos*500.0,1.0);gl_Position=p.xyww;}
)GLSL";

static const char* SKY_FS = R"GLSL(#version 300 es
precision highp float;
in vec3 vDir;
uniform vec3 uSunDir,uMoonDir,uFogColor;
uniform float uDayFrac;
out vec4 FragColor;

vec3 skyCol(vec3 dir,vec3 sun,float df){
    float up=max(dir.y,0.0),sa=max(dot(dir,sun),0.0);
    vec3 zD=vec3(0.13,0.18,0.34),hD=vec3(0.40,0.48,0.60);
    vec3 zDk=vec3(0.06,0.06,0.14),hDk=vec3(0.52,0.26,0.10);
    vec3 zN=vec3(0.01,0.01,0.04),hN=vec3(0.02,0.02,0.06);
    float dusk=smoothstep(0.0,0.18,df)*(1.0-smoothstep(0.18,0.36,df))
              +smoothstep(0.64,0.82,df)*(1.0-smoothstep(0.82,1.0,df));
    float night=1.0-smoothstep(0.15,0.35,df)*smoothstep(0.85,0.65,df);
    float day=1.0-dusk-night*0.5;
    vec3 zen=zD*day+zDk*dusk+zN*night;
    vec3 hor=hD*day+hDk*dusk+hN*night;
    vec3 sky=mix(hor,zen,up*up);
    sky+=mix(vec3(0.75,0.60,0.35),vec3(0.85,0.78,0.55),df)*pow(sa,10.0)*0.25*(1.0-night);
    return sky;
}
float starN(vec3 d){vec3 f=floor(d*220.0);float s=sin(f.x*127.1+f.y*311.7+f.z*74.9)*43758.5;return s-floor(s);}

void main(){
    vec3 dir=normalize(vDir);
    vec3 col=skyCol(dir,uSunDir,uDayFrac);
    float hb=clamp(1.0-dir.y*5.5,0.0,1.0);hb=hb*hb*hb;
    col=mix(col,uFogColor,hb*0.92);
    float night=1.0-smoothstep(0.12,0.32,uDayFrac)*smoothstep(0.88,0.68,uDayFrac);
    float dayt=1.0-night;
    // Sun
    float sunA=dot(dir,uSunDir);
    col+=vec3(0.94,0.88,0.72)*smoothstep(0.9994,0.9998,sunA)*dayt;
    col+=vec3(0.75,0.60,0.28)*pow(max(sunA,0.0),32.0)*0.22*dayt;
    // Moon — large luminous disc
    float moonA=dot(dir,uMoonDir);
    float moonCore=smoothstep(0.9988,0.9996,moonA);
    col+=vec3(0.78,0.84,0.92)*moonCore*night;
    col+=vec3(0.28,0.32,0.44)*pow(max(moonA,0.0),20.0)*night*0.60;
    // Mare detail
    if(moonCore>0.01){
        vec3 mf=floor(dir*300.0);
        float mare=sin(mf.x*71.3+mf.y*153.7+mf.z*39.1)*43758.5;
        mare=mare-floor(mare);
        col*=1.0-moonCore*mare*0.14;
    }
    // Stars
    if(dir.y>0.0&&night>0.05){
        float star=starN(dir);
        float tw=smoothstep(0.990,1.0,star);
        vec3 sc=mix(vec3(0.65,0.78,1.0),vec3(1.0,0.94,0.78),(star*7.0-floor(star*7.0)));
        col+=sc*tw*night*(0.55+dir.y*0.45);
    }
    FragColor=vec4(col,1.0);
}
)GLSL";

static const char* CLOUD_VS = R"GLSL(#version 300 es
precision highp float;
layout(location=0) in vec2 aUV;
uniform vec3 uCloudPos; uniform vec2 uSize; uniform mat4 uVP;
uniform vec3 uCamRight; uniform vec3 uCamUp;
out vec2 vUV;
void main(){
    vec3 wp=uCloudPos+uCamRight*(aUV.x-0.5)*uSize.x+uCamUp*(aUV.y-0.5)*uSize.y;
    vUV=aUV; gl_Position=uVP*vec4(wp,1.0);
}
)GLSL";
static const char* CLOUD_FS = R"GLSL(#version 300 es
precision highp float;
in vec2 vUV;
uniform float uAlpha,uNight;
out vec4 FragColor;
float h2(vec2 p){float s=sin(p.x*127.1+p.y*311.7)*43758.5;return s-floor(s);}
float n2(vec2 p){vec2 i=floor(p),f=p-i,u=f*f*(3.0-2.0*f);
    return mix(mix(h2(i),h2(i+vec2(1,0)),u.x),mix(h2(i+vec2(0,1)),h2(i+vec2(1,1)),u.x),u.y);}
void main(){
    vec2 c=vUV-0.5;float r=length(c)*2.0;
    float base=max(0.0,1.0-r*r);
    float n=n2(vUV*5.0)*0.4+n2(vUV*11.0)*0.15;
    float alpha=clamp(base+n-0.25,0.0,1.0)*uAlpha*mix(1.0,0.55,uNight);
    if(alpha<0.015) discard;
    float lit=mix(0.82,0.16,uNight)+vUV.y*0.10;
    float grain=n2(vUV*38.0)*0.07;
    FragColor=vec4(vec3(lit-grain),alpha);
}
)GLSL";

static const char* FOLIAGE_VS = R"GLSL(#version 300 es
precision highp float;
layout(location=0) in vec2 aUV;
uniform vec3 uBillPos; uniform vec2 uSize; uniform mat4 uVP;
uniform vec3 uCamRight; uniform float uTime; uniform float uWindAmt;
out vec2 vUV;
void main(){
    float sway=sin(uTime*1.8+uBillPos.x*0.6+uBillPos.z*0.4)*uWindAmt*aUV.y*0.15;
    vec3 up=vec3(0.0,1.0,0.0);
    vec3 wp=uBillPos+uCamRight*(aUV.x-0.5)*uSize.x+up*aUV.y*uSize.y+uCamRight*sway;
    vUV=aUV; gl_Position=uVP*vec4(wp,1.0);
}
)GLSL";
static const char* FOLIAGE_FS = R"GLSL(#version 300 es
precision highp float;
in vec2 vUV;
uniform float uAlpha; uniform int uType;
uniform vec3 uAmbientSky; uniform float uNight;
out vec4 FragColor;
void main(){
    float blade=max(0.0,1.0-vUV.x*vUV.x*4.0);
    float alpha=blade*uAlpha;
    vec3 col;
    if(uType==0){
        float t=vUV.y;
        col=vec3(mix(0.06,0.15,t),mix(0.18,0.34,t),mix(0.04,0.08,t));
    } else {
        float t=vUV.y;
        col=vec3(mix(0.36,0.65,t),mix(0.26,0.48,t),mix(0.05,0.11,t));
        if(t>0.80) col*=0.76;
    }
    float grey=dot(col,vec3(0.299,0.587,0.114));
    col=mix(col,vec3(grey*0.45),uNight*0.82);
    vec3 ambTint=uAmbientSky/vec3(0.38,0.48,0.65);
    col*=clamp(ambTint,0.05,1.2);
    if(alpha<0.04) discard;
    FragColor=vec4(col,alpha);
}
)GLSL";

// ════════════════════════════════════════════════════════════════
//  Terrain streaming — 48-cell chunks, radius 5 = 240m
// ════════════════════════════════════════════════════════════════
static const int CHUNK=48; static const float CELL=1.f; static const int CRAD=5;
struct TerrainChunk{int cx,cz;GLuint vao=0,vbo=0,ebo=0;int idxCount=0;bool built=false;};
static std::vector<TerrainChunk> g_chunks;
static GLuint g_terrProg=0;

static void buildChunk(TerrainChunk& c){
    int N=CHUNK+1; float ox=c.cx*CHUNK*CELL,oz=c.cz*CHUNK*CELL;
    std::vector<float> verts; verts.reserve(N*N*9);
    std::vector<uint32_t> idx; idx.reserve(CHUNK*CHUNK*6);
    for(int z=0;z<N;z++) for(int x=0;x<N;x++){
        float wx=ox+x*CELL,wz=oz+z*CELL,wy=terrH(wx,wz);
        V3 n=terrNormal(wx,wz);
        float t=clamp01(wy/10.f);
        float mud=muddiness(wx,wz),dry=drynessT(wx,wz);
        float micro=(hash(wx*3.1f,wz*2.7f)-0.5f)*0.05f;
        float r,g,b;
        if(t<0.07f){r=lerpf(0.12f,0.09f,mud);g=lerpf(0.10f,0.07f,mud);b=0.07f;}
        else if(t<0.14f){float f=(t-0.07f)/0.07f;r=lerpf(0.20f,0.14f,f);g=lerpf(0.14f,0.12f,f);b=0.09f;}
        else if(t<0.42f){float f=(t-0.14f)/0.28f;
            r=lerpf(0.10f,0.18f,f)+micro;g=lerpf(0.20f,0.26f,f);b=lerpf(0.06f,0.09f,f);
            r=lerpf(r,0.18f,dry*0.5f);g=lerpf(g,0.16f,dry*0.4f);}
        else if(t<0.66f){float f=(t-0.42f)/0.24f;
            r=lerpf(0.24f,0.36f,f)+micro;g=lerpf(0.20f,0.26f,f);b=lerpf(0.09f,0.11f,f);}
        else if(t<0.82f){float f=(t-0.66f)/0.16f;
            r=lerpf(0.34f,0.42f,f)+micro*0.5f;g=lerpf(0.32f,0.38f,f);b=lerpf(0.28f,0.34f,f);}
        else{float f=clamp01((t-0.82f)/0.18f);r=lerpf(0.44f,0.70f,f);g=lerpf(0.44f,0.70f,f);b=lerpf(0.44f,0.72f,f);}
        float sd=n.y*0.40f+0.60f; r*=sd; g*=sd; b*=sd;
        float grey=(r+g+b)/3.f;
        r=lerpf(r,grey,0.30f);g=lerpf(g,grey,0.30f);b=lerpf(b,grey,0.30f);
        verts.push_back(wx);verts.push_back(wy);verts.push_back(wz);
        verts.push_back(r);verts.push_back(g);verts.push_back(b);
        verts.push_back(n.x);verts.push_back(n.y);verts.push_back(n.z);
    }
    for(int z=0;z<CHUNK;z++) for(int x=0;x<CHUNK;x++){
        uint32_t s=z*N+x;
        idx.push_back(s);idx.push_back(s+N);idx.push_back(s+1);
        idx.push_back(s+1);idx.push_back(s+N);idx.push_back(s+N+1);
    }
    c.idxCount=(int)idx.size();
    glGenVertexArrays(1,&c.vao);glGenBuffers(1,&c.vbo);glGenBuffers(1,&c.ebo);
    glBindVertexArray(c.vao);
    glBindBuffer(GL_ARRAY_BUFFER,c.vbo);
    glBufferData(GL_ARRAY_BUFFER,verts.size()*4,verts.data(),GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,c.ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER,idx.size()*4,idx.data(),GL_STATIC_DRAW);
    const int stride=36;
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,stride,(void*)0); glEnableVertexAttribArray(0);
    glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,stride,(void*)12);glEnableVertexAttribArray(1);
    glVertexAttribPointer(2,3,GL_FLOAT,GL_FALSE,stride,(void*)24);glEnableVertexAttribArray(2);
    glBindVertexArray(0);c.built=true;
}
static void streamChunks(float px,float pz){
    int pcx=(int)floorf(px/(CHUNK*CELL)),pcz=(int)floorf(pz/(CHUNK*CELL));
    g_chunks.erase(std::remove_if(g_chunks.begin(),g_chunks.end(),
        [&](TerrainChunk& c){
            bool far=abs(c.cx-pcx)>CRAD+1||abs(c.cz-pcz)>CRAD+1;
            if(far){glDeleteVertexArrays(1,&c.vao);glDeleteBuffers(1,&c.vbo);glDeleteBuffers(1,&c.ebo);}
            return far;}),g_chunks.end());
    for(int dz=-CRAD;dz<=CRAD;dz++) for(int dx=-CRAD;dx<=CRAD;dx++){
        int tx=pcx+dx,tz=pcz+dz;bool ex=false;
        for(auto& c:g_chunks)if(c.cx==tx&&c.cz==tz){ex=true;break;}
        if(!ex){g_chunks.push_back({tx,tz});buildChunk(g_chunks.back());}
    }
}

// ════════════════════════════════════════════════════════════════
//  Sky
// ════════════════════════════════════════════════════════════════
static GLuint g_skyProg=0,g_skyVAO=0;static int g_skyIdxCount=0;
static void buildSkyDome(){
    std::vector<float> v;std::vector<uint32_t> idx;
    const int st=16,sl=32;
    for(int s=0;s<=st;s++){float phi=3.14159f*s/st;
        for(int l=0;l<=sl;l++){float t=2*3.14159f*l/sl;
            v.push_back(sinf(phi)*cosf(t));v.push_back(cosf(phi));v.push_back(sinf(phi)*sinf(t));}}
    for(int s=0;s<st;s++) for(int l=0;l<sl;l++){
        uint32_t a=s*(sl+1)+l;
        idx.push_back(a);idx.push_back(a+sl+1);idx.push_back(a+1);
        idx.push_back(a+1);idx.push_back(a+sl+1);idx.push_back(a+sl+2);}
    GLuint vbo,ebo;
    glGenVertexArrays(1,&g_skyVAO);glGenBuffers(1,&vbo);glGenBuffers(1,&ebo);
    glBindVertexArray(g_skyVAO);
    glBindBuffer(GL_ARRAY_BUFFER,vbo);glBufferData(GL_ARRAY_BUFFER,v.size()*4,v.data(),GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,ebo);glBufferData(GL_ELEMENT_ARRAY_BUFFER,idx.size()*4,idx.data(),GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,12,(void*)0);glEnableVertexAttribArray(0);
    glBindVertexArray(0);g_skyIdxCount=(int)idx.size();
}

// ════════════════════════════════════════════════════════════════
//  Clouds
// ════════════════════════════════════════════════════════════════
static GLuint g_cloudProg=0,g_cloudVAO=0;
static const float CLOUD_UV[]={0,0,1,0,1,1,0,0,1,1,0,1};
struct Cloud{float wx,wy,wz,sizeX,sizeY,alpha;};
static std::vector<Cloud> g_clouds; static float g_cloudOffX=0;
static void seedClouds(float px,float pz){
    g_clouds.clear();
    for(int i=0;i<24;i++){
        float ang=i*(6.2832f/24.f),r=50.f+hash(float(i)*1.7f,0.f)*160.f;
        float sz=22.f+hash(float(i)*3.1f,1.f)*50.f;
        g_clouds.push_back({px+cosf(ang)*r,72.f+hash(float(i)*2.f,4.f)*18.f,
            pz+sinf(ang)*r,sz,sz*(0.30f+hash(float(i)*2.3f,2.f)*0.35f),
            0.45f+hash(float(i)*0.9f,3.f)*0.42f});
    }
}

// ════════════════════════════════════════════════════════════════
//  Foliage
// ════════════════════════════════════════════════════════════════
static GLuint g_foliageProg=0,g_foliageVAO=0;
static const float FOLIAGE_UV[]={0.0f,0.0f, 1.0f,0.0f, 0.5f,1.0f};

// ════════════════════════════════════════════════════════════════
//  Engine state
// ════════════════════════════════════════════════════════════════
static GLuint g_worldProg=0;
static GLuint g_vaoTorso,g_vaoNeck,g_vaoHead;
static GLuint g_vaoUpLimb,g_vaoLowLimb,g_vaoHand,g_vaoFoot;
static GLuint g_vaoSword,g_vaoShield,g_vaoTree,g_vaoRock;

static float g_px=0,g_py=0,g_pz=0,g_facing=0,g_walkT=0;
static float g_jumpVY=0,g_jumpY=0,g_slashT=0,g_bashT=0;
static bool  g_block=false;
static float g_stamina=1.f,g_health=1.f,g_staminaTimer=0.f;

static float g_camYawTarget=0.7f,g_camYaw=0.7f;
static float g_camPitchTarget=0.42f,g_camPitch=0.42f;
static float g_camZoomTarget=14.f,g_camZoom=14.f;
static M4 g_proj; static float g_aspect=1.f;

static float g_dayFrac=0.82f;  // start at night
static const float DAY_SPEED=0.000035f;
static float g_time=0.f;

// ════════════════════════════════════════════════════════════════
//  Sun/Moon/Ambient
// ════════════════════════════════════════════════════════════════
static void getSunMoon(float df,
    V3& sunDir,V3& sunCol,V3& moonDir,V3& moonCol,
    V3& ambSky,V3& ambGnd,V3& fogCol,
    float& fogNear,float& fogFar,float& nightFrac)
{
    float angle=df*6.2832f-1.5708f;
    sunDir=v3norm({cosf(angle)*0.95f,sinf(angle),cosf(angle)*0.30f});
    moonDir=v3norm({-sunDir.x,-sunDir.y,-sunDir.z});
    float sunUp=clamp01(sunDir.y),moonUp=clamp01(moonDir.y);
    sunCol={lerpf(0.90f,0.96f,sunUp),lerpf(0.50f,0.88f,sunUp),lerpf(0.20f,0.80f,sunUp)};
    moonCol={lerpf(0.28f,0.58f,moonUp),lerpf(0.32f,0.66f,moonUp),lerpf(0.38f,0.84f,moonUp)};
    nightFrac=clamp01(1.f-sunUp*2.8f);
    float day=1.f-nightFrac;
    ambSky={lerpf(0.04f,0.26f,day)+moonUp*0.07f*nightFrac,
            lerpf(0.04f,0.32f,day)+moonUp*0.08f*nightFrac,
            lerpf(0.08f,0.48f,day)+moonUp*0.14f*nightFrac};
    ambGnd={lerpf(0.01f,0.07f,day),lerpf(0.01f,0.06f,day),lerpf(0.01f,0.05f,day)};
    float dusk=std::max(0.f,1.f-fabsf(df-0.25f)*8.f)+std::max(0.f,1.f-fabsf(df-0.75f)*8.f);
    dusk=clamp01(dusk);
    fogCol={lerpf(lerpf(0.30f,0.52f,dusk),0.02f,nightFrac),
            lerpf(lerpf(0.40f,0.36f,dusk),0.02f,nightFrac),
            lerpf(lerpf(0.58f,0.20f,dusk),0.05f,nightFrac)};
    fogNear=g_camZoom*2.0f;
    fogFar =g_camZoom*6.0f+28.f;
}

// ════════════════════════════════════════════════════════════════
//  Draw helper
// ════════════════════════════════════════════════════════════════
static GLint uMdl,uMVP;
static void drawVAO(GLuint vao,int n,const M4& model,const M4& vp){
    M4 mvp=m4mul(vp,model);
    glUniformMatrix4fv(uMVP,1,GL_FALSE,mvp.m);
    glUniformMatrix4fv(uMdl,1,GL_FALSE,model.m);
    glBindVertexArray(vao);glDrawArrays(GL_TRIANGLES,0,n);
}

// ════════════════════════════════════════════════════════════════
//  Character  v5
//
//  SHIELD FIX: shield is placed in WORLD SPACE at the wrist position,
//  oriented using the character's world-facing angle (g_facing).
//  The shield mesh face points in Blender +Y → GL -Z (forward).
//  We rotate by g_facing around Y so the face always points the same
//  direction the knight faces, then tilt -90° around X to make the
//  disc stand upright with the point downward.
//  This decouples shield orientation from arm swing entirely.
// ════════════════════════════════════════════════════════════════
static void drawCharacter(const M4& base,const M4& vp){
    drawVAO(g_vaoTorso, N_TORSO, base, vp);
    M4 mNeck=m4mul(base,m4T(0,0.74f,0));
    drawVAO(g_vaoNeck,  N_NECK,  mNeck, vp);
    M4 mHead=m4mul(base,m4T(0,0.92f,0));
    drawVAO(g_vaoHead,  N_HEAD,  mHead, vp);

    // Right arm — sword
    float swRot=(g_slashT>0)?-2.8f*sinf(g_slashT*3.14159f):-sinf(g_walkT)*0.40f;
    M4 mShouR=m4mul(base,m4T(0.36f,0.70f,0));
    M4 mUA_R=m4mul(mShouR,m4RX(swRot));
    drawVAO(g_vaoUpLimb,N_UP_LIMB,mUA_R,vp);
    float elbR=(g_slashT>0)?0.60f:0.18f;
    M4 mElbR=m4mul(m4mul(mUA_R,m4T(0,0,-0.42f)),m4RX(elbR));
    drawVAO(g_vaoLowLimb,N_LOW_LIMB,mElbR,vp);
    M4 mWristR=m4mul(mElbR,m4T(0,0,-0.40f));
    drawVAO(g_vaoHand,N_HAND,mWristR,vp);
    drawVAO(g_vaoSword,N_SWORD,m4mul(mWristR,m4T(0,0,-0.03f)),vp);

    // Left arm — shield
    float shRot=g_block?-1.48f:(g_bashT>0?-1.82f:sinf(g_walkT)*0.40f);
    M4 mShouL=m4mul(base,m4T(-0.36f,0.70f,0));
    M4 mUA_L=m4mul(mShouL,m4RX(shRot));
    drawVAO(g_vaoUpLimb,N_UP_LIMB,mUA_L,vp);
    float elbL=g_block?1.05f:0.18f;
    M4 mElbL=m4mul(m4mul(mUA_L,m4T(0,0,-0.42f)),m4RX(elbL));
    drawVAO(g_vaoLowLimb,N_LOW_LIMB,mElbL,vp);
    M4 mWristL=m4mul(mElbL,m4T(0,0,-0.40f));
    drawVAO(g_vaoHand,N_HAND,mWristL,vp);

    // Shield — world-space: read wrist world pos from translation column
    float shX=mWristL.m[12],shY=mWristL.m[13],shZ=mWristL.m[14];
    // Shift slightly in front (toward facing direction)
    float fwdX=sinf(g_facing)*0.12f, fwdZ=-cosf(g_facing)*0.12f;
    // Block: shield forward/higher; idle: slightly to side and forward
    float blockLift=g_block?0.12f:0.f;
    M4 mShield=m4mul(
        m4mul(m4T(shX+fwdX, shY+blockLift, shZ+fwdZ),
              m4RY(g_facing)),         // face same direction as knight
        m4RX(-1.5708f));               // upright disc, point down
    drawVAO(g_vaoShield,N_SHIELD,mShield,vp);

    // Legs
    float lg=sinf(g_walkT)*0.72f;
    M4 mHipR=m4mul(base,m4T(0.20f,0,0));
    M4 mUL_R=m4mul(mHipR,m4RX(-lg));
    drawVAO(g_vaoUpLimb,N_UP_LIMB,mUL_R,vp);
    M4 mKneeR=m4mul(m4mul(mUL_R,m4T(0,0,-0.42f)),m4RX(std::max(0.f,-lg)*0.52f));
    drawVAO(g_vaoLowLimb,N_LOW_LIMB,mKneeR,vp);
    drawVAO(g_vaoFoot,N_FOOT,m4mul(mKneeR,m4T(0,0,-0.40f)),vp);
    M4 mHipL=m4mul(base,m4T(-0.20f,0,0));
    M4 mUL_L=m4mul(mHipL,m4RX(lg));
    drawVAO(g_vaoUpLimb,N_UP_LIMB,mUL_L,vp);
    M4 mKneeL=m4mul(m4mul(mUL_L,m4T(0,0,-0.42f)),m4RX(std::max(0.f,lg)*0.52f));
    drawVAO(g_vaoLowLimb,N_LOW_LIMB,mKneeL,vp);
    drawVAO(g_vaoFoot,N_FOOT,m4mul(mKneeL,m4T(0,0,-0.40f)),vp);
}

// ════════════════════════════════════════════════════════════════
//  JNI
// ════════════════════════════════════════════════════════════════
extern "C" {

JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onCreated(JNIEnv*,jobject){
    g_worldProg  =linkProg(WORLD_VS,  WORLD_FS);
    g_terrProg   =linkProg(TERR_VS,   WORLD_FS);
    g_skyProg    =linkProg(SKY_VS,    SKY_FS);
    g_cloudProg  =linkProg(CLOUD_VS,  CLOUD_FS);
    g_foliageProg=linkProg(FOLIAGE_VS,FOLIAGE_FS);
    g_vaoTorso  =makeVAO6(M_TORSO,   N_TORSO);
    g_vaoNeck   =makeVAO6(M_NECK,    N_NECK);
    g_vaoHead   =makeVAO6(M_HEAD,    N_HEAD);
    g_vaoUpLimb =makeVAO6(M_UP_LIMB, N_UP_LIMB);
    g_vaoLowLimb=makeVAO6(M_LOW_LIMB,N_LOW_LIMB);
    g_vaoHand   =makeVAO6(M_HAND,    N_HAND);
    g_vaoFoot   =makeVAO6(M_FOOT,    N_FOOT);
    g_vaoSword  =makeVAO6(M_SWORD,   N_SWORD);
    g_vaoShield =makeVAO6(M_SHIELD,  N_SHIELD);
    g_vaoTree   =makeVAO6(M_TREE,    N_TREE);
    g_vaoRock   =makeVAO6(M_ROCK,    N_ROCK);
    buildSkyDome();
    {GLuint vbo;glGenVertexArrays(1,&g_cloudVAO);glGenBuffers(1,&vbo);
    glBindVertexArray(g_cloudVAO);glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER,sizeof(CLOUD_UV),CLOUD_UV,GL_STATIC_DRAW);
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,8,(void*)0);glEnableVertexAttribArray(0);glBindVertexArray(0);}
    {GLuint vbo;glGenVertexArrays(1,&g_foliageVAO);glGenBuffers(1,&vbo);
    glBindVertexArray(g_foliageVAO);glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER,sizeof(FOLIAGE_UV),FOLIAGE_UV,GL_STATIC_DRAW);
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,8,(void*)0);glEnableVertexAttribArray(0);glBindVertexArray(0);}
    glEnable(GL_DEPTH_TEST);glDepthFunc(GL_LEQUAL);
    glEnable(GL_CULL_FACE);glCullFace(GL_BACK);
    glEnable(GL_BLEND);glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    streamChunks(0,0);seedClouds(0,0);
    LOGI("EndlessRPG v5 initialised.");
}

JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onChanged(JNIEnv*,jobject,jint w,jint h){
    glViewport(0,0,w,h);
    g_aspect=(h>0)?(float)w/h:1.f;
    g_proj=m4persp(1.047f,g_aspect,0.1f,800.f);
}

JNIEXPORT void JNICALL
Java_com_game_procedural_MainActivity_onDraw(
    JNIEnv*,jobject,jfloat ix,jfloat iy,jfloat yaw,jfloat pitch,jfloat zoom)
{
    g_camYawTarget=yaw;g_camPitchTarget=pitch;g_camZoomTarget=zoom;
    const float LAG=0.12f;
    g_camYaw  =lerpf(g_camYaw,  g_camYawTarget,  LAG);
    g_camPitch=lerpf(g_camPitch,g_camPitchTarget,LAG);
    g_camZoom =lerpf(g_camZoom, g_camZoomTarget, LAG);
    g_time+=0.016f;
    g_dayFrac+=DAY_SPEED; if(g_dayFrac>=1.f)g_dayFrac-=1.f;

    V3 sunDir,sunCol,moonDir,moonCol,ambSky,ambGnd,fogCol;
    float fogNear,fogFar,nightFrac;
    getSunMoon(g_dayFrac,sunDir,sunCol,moonDir,moonCol,ambSky,ambGnd,fogCol,fogNear,fogFar,nightFrac);

    glClearColor(fogCol.x,fogCol.y,fogCol.z,1.f);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);

    bool moving=fabsf(ix)>0.02f||fabsf(iy)>0.02f;
    if(moving){
        float sy=sinf(g_camYaw),cy=cosf(g_camYaw);
        float dx=ix*cy-(-iy)*sy,dz=ix*sy+(-iy)*cy;
        float spd=0.11f*(g_block?0.45f:1.f);
        g_px+=dx*spd;g_pz-=dz*spd;
        g_facing=atan2f(-dx,dz);g_walkT+=0.16f;
        g_stamina=std::max(0.f,g_stamina-0.0007f);g_staminaTimer=1.5f;
    } else {
        if(g_staminaTimer>0)g_staminaTimer-=0.016f;
        else g_stamina=std::min(1.f,g_stamina+0.0025f);
    }
    g_jumpY+=g_jumpVY;g_jumpVY-=0.022f;
    float gh=terrH(g_px,g_pz);
    if(g_jumpY<gh){g_jumpY=gh;g_jumpVY=0.f;}
    g_py=g_jumpY;
    if(g_slashT>0)g_slashT-=0.055f;
    if(g_bashT >0)g_bashT -=0.085f;
    streamChunks(g_px,g_pz);
    g_cloudOffX+=0.004f;
    if(g_clouds.empty())seedClouds(g_px,g_pz);

    float safeZ=std::max(5.f,g_camZoom);
    float eyeX=g_px-sinf(g_camYaw)*cosf(g_camPitch)*safeZ;
    float eyeZ=g_pz-cosf(g_camYaw)*cosf(g_camPitch)*safeZ;
    float eyeY=g_py+sinf(g_camPitch)*safeZ+1.5f;
    if(eyeY<terrH(eyeX,eyeZ)+0.5f)eyeY=terrH(eyeX,eyeZ)+0.5f;
    V3 eye={eyeX,eyeY,eyeZ};
    M4 view=m4look(eye,{g_px,g_py+1.2f,g_pz},{0,1,0});
    M4 vp=m4mul(g_proj,view);
    V3 camRight={view.m[0],view.m[4],view.m[8]};
    V3 camUp   ={view.m[1],view.m[5],view.m[9]};

    auto setLU=[&](GLuint prog){
        glUniform3f(glGetUniformLocation(prog,"uSunDir"),   sunDir.x,sunDir.y,sunDir.z);
        glUniform3f(glGetUniformLocation(prog,"uSunColor"), sunCol.x,sunCol.y,sunCol.z);
        glUniform3f(glGetUniformLocation(prog,"uMoonDir"),  moonDir.x,moonDir.y,moonDir.z);
        glUniform3f(glGetUniformLocation(prog,"uMoonColor"),moonCol.x,moonCol.y,moonCol.z);
        glUniform3f(glGetUniformLocation(prog,"uAmbientSky"),ambSky.x,ambSky.y,ambSky.z);
        glUniform3f(glGetUniformLocation(prog,"uAmbientGnd"),ambGnd.x,ambGnd.y,ambGnd.z);
        glUniform3f(glGetUniformLocation(prog,"uCamPos"),   eye.x,eye.y,eye.z);
        glUniform1f(glGetUniformLocation(prog,"uFogNear"),  fogNear);
        glUniform1f(glGetUniformLocation(prog,"uFogFar"),   fogFar);
        glUniform3f(glGetUniformLocation(prog,"uFogColor"), fogCol.x,fogCol.y,fogCol.z);
        glUniform1f(glGetUniformLocation(prog,"uNight"),    nightFrac);
    };

    // 1. SKY
    glDepthMask(GL_FALSE);glDisable(GL_CULL_FACE);
    glUseProgram(g_skyProg);
    M4 skyView=view;skyView.m[12]=0;skyView.m[13]=0;skyView.m[14]=0;
    glUniformMatrix4fv(glGetUniformLocation(g_skyProg,"uVP"),1,GL_FALSE,m4mul(g_proj,skyView).m);
    glUniform3f(glGetUniformLocation(g_skyProg,"uSunDir"), sunDir.x,sunDir.y,sunDir.z);
    glUniform3f(glGetUniformLocation(g_skyProg,"uMoonDir"),moonDir.x,moonDir.y,moonDir.z);
    glUniform1f(glGetUniformLocation(g_skyProg,"uDayFrac"),g_dayFrac);
    glUniform3f(glGetUniformLocation(g_skyProg,"uFogColor"),fogCol.x,fogCol.y,fogCol.z);
    glBindVertexArray(g_skyVAO);
    glDrawElements(GL_TRIANGLES,g_skyIdxCount,GL_UNSIGNED_INT,nullptr);
    glDepthMask(GL_TRUE);glEnable(GL_CULL_FACE);

    // 2. TERRAIN
    glUseProgram(g_terrProg);setLU(g_terrProg);
    GLint tMVP=glGetUniformLocation(g_terrProg,"uMVP");
    GLint tMdl=glGetUniformLocation(g_terrProg,"uModel");
    M4 identity=m4id();glUniformMatrix4fv(tMdl,1,GL_FALSE,identity.m);
    for(auto& ch:g_chunks){
        glUniformMatrix4fv(tMVP,1,GL_FALSE,m4mul(g_proj,m4mul(view,identity)).m);
        glBindVertexArray(ch.vao);
        glDrawElements(GL_TRIANGLES,ch.idxCount,GL_UNSIGNED_INT,nullptr);
    }

    // 3. WORLD OBJECTS
    glUseProgram(g_worldProg);
    uMVP=glGetUniformLocation(g_worldProg,"uMVP");
    uMdl=glGetUniformLocation(g_worldProg,"uModel");
    setLU(g_worldProg);
    int pcx=(int)floorf(g_px/8.f),pcz=(int)floorf(g_pz/8.f);
    for(int dz=-8;dz<=8;dz++) for(int dx=-8;dx<=8;dx++){
        float tx=(pcx+dx)*8.f,tz=(pcz+dz)*8.f;
        if(hash(tx*.031f,tz*.047f)<0.48f)continue;
        float ty=terrH(tx,tz);if(ty>8.f)continue;
        if(terrNormal(tx,tz).y<0.70f)continue;
        float rot=hash(tx*.13f,tz*.19f)*6.2832f;
        float scl=0.88f+hash(tx*.07f,tz*.11f)*0.40f;
        drawVAO(g_vaoTree,N_TREE,m4mul(m4mul(m4T(tx,ty,tz),m4RY(rot)),m4S(scl,scl,scl)),vp);
    }
    for(int dz=-6;dz<=6;dz++) for(int dx=-6;dx<=6;dx++){
        float rx=(pcx+dx)*5.f+2.5f,rz=(pcz+dz)*5.f+2.5f;
        float hr=hash(rx*.053f+9.f,rz*.067f);if(hr<0.74f)continue;
        float ry=terrH(rx,rz),scl=0.5f+hr*0.9f;
        drawVAO(g_vaoRock,N_ROCK,m4mul(m4mul(m4T(rx,ry,rz),m4RY(hr*6.2832f)),m4S(scl,scl,scl*0.65f)),vp);
    }

    // 4. CHARACTER
    float bobY=(fabsf(ix)>0.02f||fabsf(iy)>0.02f)?sinf(g_walkT*2.f)*0.022f:0.f;
    drawCharacter(m4mul(m4T(g_px,g_py+bobY,g_pz),m4RY(g_facing)),vp);

    // 5. FOLIAGE
    glDisable(GL_CULL_FACE);
    glUseProgram(g_foliageProg);
    glUniformMatrix4fv(glGetUniformLocation(g_foliageProg,"uVP"),1,GL_FALSE,vp.m);
    glUniform1f(glGetUniformLocation(g_foliageProg,"uTime"),g_time);
    glUniform1f(glGetUniformLocation(g_foliageProg,"uWindAmt"),0.50f);
    glUniform3f(glGetUniformLocation(g_foliageProg,"uAmbientSky"),ambSky.x,ambSky.y,ambSky.z);
    glUniform1f(glGetUniformLocation(g_foliageProg,"uNight"),nightFrac);
    GLint fBP=glGetUniformLocation(g_foliageProg,"uBillPos");
    GLint fSz=glGetUniformLocation(g_foliageProg,"uSize");
    GLint fCR=glGetUniformLocation(g_foliageProg,"uCamRight");
    GLint fAl=glGetUniformLocation(g_foliageProg,"uAlpha");
    GLint fTy=glGetUniformLocation(g_foliageProg,"uType");
    glBindVertexArray(g_foliageVAO);
    int gpcx=(int)floorf(g_px/1.5f),gpcz=(int)floorf(g_pz/1.5f);
    for(int dz=-9;dz<=9;dz++) for(int dx=-9;dx<=9;dx++){
        float bx=(gpcx+dx)*1.5f+hash(float(gpcx+dx)*0.31f,float(gpcz+dz)*0.73f)*0.55f;
        float bz=(gpcz+dz)*1.5f+hash(float(gpcx+dx)*0.87f,float(gpcz+dz)*0.41f)*0.55f;
        float by=terrH(bx,bz);
        if(by>7.f||by<-1.f)continue;
        if(hash(bx*0.41f,bz*0.37f)<0.32f)continue;
        if(terrNormal(bx,bz).y<0.62f)continue;
        float th=clamp01(by/8.f);
        bool isWheat=(th>0.28f&&th<0.55f&&hash(bx*1.3f,bz*0.9f)>0.70f);
        float h=isWheat?0.50f+hash(bx,bz)*0.20f:0.15f+hash(bx*2.f,bz*1.7f)*0.11f;
        float w=isWheat?0.09f:0.052f+hash(bx*0.5f,bz*1.1f)*0.04f;
        float dist2=fabsf(bx-g_px)+fabsf(bz-g_pz);
        float alpha=0.85f*(dist2<11.f?1.f:1.f-(dist2-11.f)/4.f);
        if(alpha<0.05f)continue;
        glUniform3f(fBP,bx,by,bz);glUniform2f(fSz,w,h);
        glUniform1f(fAl,alpha);glUniform1i(fTy,isWheat?1:0);
        for(int rot=0;rot<3;rot++){
            float ang=rot*(3.14159f/3.f)+hash(bx,bz+rot)*0.9f;
            glUniform3f(fCR,cosf(ang),0,sinf(ang));
            glDrawArrays(GL_TRIANGLES,0,3);
        }
    }
    glUniform3f(fCR,camRight.x,camRight.y,camRight.z);
    glEnable(GL_CULL_FACE);

    // 6. CLOUDS
    glDepthMask(GL_FALSE);glDisable(GL_CULL_FACE);
    glUseProgram(g_cloudProg);
    glUniformMatrix4fv(glGetUniformLocation(g_cloudProg,"uVP"),1,GL_FALSE,vp.m);
    glUniform3f(glGetUniformLocation(g_cloudProg,"uCamRight"),camRight.x,camRight.y,camRight.z);
    glUniform3f(glGetUniformLocation(g_cloudProg,"uCamUp"),   camUp.x,camUp.y,camUp.z);
    glUniform1f(glGetUniformLocation(g_cloudProg,"uNight"),   nightFrac);
    glBindVertexArray(g_cloudVAO);
    for(auto& cl:g_clouds){
        glUniform3f(glGetUniformLocation(g_cloudProg,"uCloudPos"),cl.wx+g_cloudOffX,cl.wy,cl.wz);
        glUniform2f(glGetUniformLocation(g_cloudProg,"uSize"),cl.sizeX,cl.sizeY);
        glUniform1f(glGetUniformLocation(g_cloudProg,"uAlpha"),cl.alpha);
        glDrawArrays(GL_TRIANGLES,0,6);
    }
    glDepthMask(GL_TRUE);glEnable(GL_CULL_FACE);
}

JNIEXPORT void JNICALL Java_com_game_procedural_MainActivity_triggerAction(JNIEnv*,jobject,jint id){
    switch(id){
        case 1: if(g_stamina>0.15f){g_slashT=1.f;g_stamina=std::max(0.f,g_stamina-0.18f);}break;
        case 2: g_block=true; break;
        case 3: g_block=false;break;
        case 4: if(g_jumpY<=terrH(g_px,g_pz)+0.10f&&g_stamina>0.10f){g_jumpVY=0.44f;g_stamina=std::max(0.f,g_stamina-0.12f);}break;
        case 6: if(g_stamina>0.20f){g_bashT=1.f;g_block=false;g_stamina=std::max(0.f,g_stamina-0.20f);}break;
    }
}
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getCameraYaw(JNIEnv*,jobject){return g_camYaw;}
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getStamina(JNIEnv*,jobject){return g_stamina;}
JNIEXPORT jfloat JNICALL Java_com_game_procedural_MainActivity_getHealth(JNIEnv*,jobject){return g_health;}
JNIEXPORT void   JNICALL Java_com_game_procedural_MainActivity_setStamina(JNIEnv*,jobject,jfloat v){g_stamina=clamp01(v);}

} // extern "C"
CPPEOF

echo "[generate_engine.sh] native-lib.cpp written."
