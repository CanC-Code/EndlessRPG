#pragma once
#include <EGL/egl.h>
#include <EGL/eglext.h> // Required for OpenGL ES 3.x extensions
#include <android/native_window.h>

// Guard for EGL 1.4 environments that don't define the ES3 bit
#ifndef EGL_OPENGL_ES3_BIT_KHR
#define EGL_OPENGL_ES3_BIT_KHR 0x0040
#endif

class EGLCore {
public:
    EGLCore();
    ~EGLCore();

    bool init(ANativeWindow* window);
    void swapBuffers();
    void release();

private:
    EGLDisplay display;
    EGLConfig  config;
    EGLSurface surface;
    EGLContext context;
};
