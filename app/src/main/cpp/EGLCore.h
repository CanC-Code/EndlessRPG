#pragma once
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <android/native_window.h>

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

    // New additions to fetch the screen dimensions
    int getWidth();
    int getHeight();

private:
    EGLDisplay display;
    EGLConfig  config;
    EGLSurface surface;
    EGLContext context;
};
