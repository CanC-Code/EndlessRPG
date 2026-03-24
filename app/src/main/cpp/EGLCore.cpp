#include "EGLCore.h"

EGLCore::EGLCore() : display(EGL_NO_DISPLAY), surface(EGL_NO_SURFACE), context(EGL_NO_CONTEXT) {}

// Added missing destructor
EGLCore::~EGLCore() {
    release();
}

bool EGLCore::init(ANativeWindow* window) {
    display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    eglInitialize(display, nullptr, nullptr);

    const EGLint attribs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_BLUE_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_RED_SIZE, 8,
        EGL_DEPTH_SIZE, 16, // Depth buffer for accurate 3D sorting
        EGL_NONE
    };

    EGLConfig config;
    EGLint numConfigs;
    eglChooseConfig(display, attribs, &config, 1, &numConfigs);

    const EGLint contextAttribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_NONE
    };

    context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttribs);
    surface = eglCreateWindowSurface(display, config, window, nullptr);

    eglMakeCurrent(display, surface, surface, context);
    return true;
}

void EGLCore::swapBuffers() {
    if (display != EGL_NO_DISPLAY && surface != EGL_NO_SURFACE) {
        eglSwapBuffers(display, surface);
    }
}

// Added missing getWidth method
int EGLCore::getWidth() {
    EGLint width = 0;
    if (display != EGL_NO_DISPLAY && surface != EGL_NO_SURFACE) {
        eglQuerySurface(display, surface, EGL_WIDTH, &width);
    }
    return width;
}

// Added missing getHeight method
int EGLCore::getHeight() {
    EGLint height = 0;
    if (display != EGL_NO_DISPLAY && surface != EGL_NO_SURFACE) {
        eglQuerySurface(display, surface, EGL_HEIGHT, &height);
    }
    return height;
}

void EGLCore::release() {
    if (display != EGL_NO_DISPLAY) {
        eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (context != EGL_NO_CONTEXT) eglDestroyContext(display, context);
        if (surface != EGL_NO_SURFACE) eglDestroySurface(display, surface);
        eglTerminate(display);
    }
    display = EGL_NO_DISPLAY;
    surface = EGL_NO_SURFACE;
    context = EGL_NO_CONTEXT;
}
