#include "BladePipeline.h"
#include <cstdlib>
static GLuint mk(GLenum t, const char* s){GLuint h=glCreateShader(t);glShaderSource(h,1,&s,nullptr);glCompileShader(h);return h;}
static char* lf(AAssetManager* a, const char* p){AAsset* A=AAssetManager_open(a,p,AASSET_MODE_BUFFER);if(!A)return nullptr;off_t n=AAsset_getLength(A);char* b=(char*)malloc(n+1);AAsset_read(A,b,n);b[n]=0;AAsset_close(A);return b;}
void setupBladePipeline(GLuint* p, GLuint* v, GLuint* b, AAssetManager* am){
char* vs=lf(am,"shaders/blade.vert");char* fs=lf(am,"shaders/blade.frag");
if(!vs||!fs)return;
*p=glCreateProgram();glAttachShader(*p,mk(GL_VERTEX_SHADER,vs));glAttachShader(*p,mk(GL_FRAGMENT_SHADER,fs));glLinkProgram(*p);
glGenVertexArrays(1,v);glGenBuffers(1,b);glBindVertexArray(*v);glBindBuffer(GL_ARRAY_BUFFER,*b);
glBufferData(GL_ARRAY_BUFFER,200000*24,nullptr,GL_DYNAMIC_DRAW);
glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,24,0);glEnableVertexAttribArray(0);
glVertexAttribPointer(1,2,GL_FLOAT,GL_FALSE,24,(void*)12);glEnableVertexAttribArray(1);
glVertexAttribPointer(2,4,GL_UNSIGNED_BYTE,GL_TRUE,24,(void*)20);glEnableVertexAttribArray(2);
}
void drawBlades(GLuint p, GLuint v, GLuint b, const float* mvp, const std::vector<GrassTile>& tiles, float cx, float cy, float cz, float tm, std::vector<BladeVertex>& sc){
sc.resize(30000);
CameraView cv{cx,cy,cz};
int tc=build_frame_grass(tiles,cv,tm,sc.data(),(int)sc.size());
static int dbg=0; if((dbg++%60)==0) LOGE("drawBlades tc=%d",tc);
if(tc<=0)return;
int nv=tc*3;
glBindBuffer(GL_ARRAY_BUFFER,b);
glBufferSubData(GL_ARRAY_BUFFER,0,nv*24,sc.data());
glUseProgram(p);
glUniformMatrix4fv(glGetUniformLocation(p,"uMVP"),1,GL_FALSE,mvp);
glBindVertexArray(v);
glDrawArrays(GL_TRIANGLES,0,nv);
}

