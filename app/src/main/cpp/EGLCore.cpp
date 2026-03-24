#include "EGLCore.h"
#include <android/log.h>

#define LOG_TAG "EGLCore"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

EGLCore::EGLCore() : display(EGL_NO_DISPLAY), surface(EGL_NO_SURFACE), context(EGL_NO_CONTEXT) {}

EGLCore::~EGLCore() {
    release();
}

bool EGLCore::init(ANativeWindow* window) {
    display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (display == EGL_NO_DISPLAY) {
        LOGE("Unable to get EGL display");
        return false;
    }

    if (!eglInitialize(display, nullptr, nullptr)) {
        LOGE("eglInitialize failed");
        return false;
    }

    // Use the bit we defined/included in the header
    const EGLint configAttribs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT_KHR,
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_BLUE_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        // Alpha size 8 is often required for photographic transparency/blending
        EGL_RED_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24,
        EGL_NONE
    };

    EGLint numConfigs;
    if (!eglChooseConfig(display, configAttribs, &config, 1, &numConfigs) || numConfigs == 0) {
        LOGE("eglChooseConfig failed or returned no configs");
        return false;
    }

    surface = eglCreateWindowSurface(display, config, window, nullptr);
    if (surface == EGL_NO_SURFACE) {
        LOGE("eglCreateWindowSurface failed");
        return false;
    }

    // Explicitly request GLES 3.1 for Compute Shader support
    const EGLint contextAttribs[] = { 
        EGL_CONTEXT_CLIENT_VERSION, 3, 
        EGL_NONE 
    };
    
    context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttribs);
    if (context == EGL_NO_CONTEXT) {
        LOGE("eglCreateContext failed");
        return false;
    }

    if (!eglMakeCurrent(display, surface, surface, context)) {
        LOGE("eglMakeCurrent failed");
        return false;
    }

    return true;
}

void EGLCore::swapBuffers() {
    if (display != EGL_NO_DISPLAY && surface != EGL_NO_SURFACE) {
        eglSwapBuffers(display, surface);
    }
}

void EGLCore::release() {
    if (display != EGL_NO_DISPLAY) {
        eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (context != EGL_NO_CONTEXT) eglDestroyContext(display, context);
        if (surface != EGL_NO_SURFACE) eglDestroySurface(display, surface);
        eglTerminate(display);
    }
    display = EGL_NO_DISPLAY;
    context = EGL_NO_CONTEXT;
    surface = EGL_NO_SURFACE;
}
