#include "EGLCore.h"
#include <android/log.h>

#define LOG_TAG "EGLCore"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)

EGLCore::EGLCore()
    : display(EGL_NO_DISPLAY), surface(EGL_NO_SURFACE), context(EGL_NO_CONTEXT) {}

EGLCore::~EGLCore() {
    release();
}

bool EGLCore::init(ANativeWindow* window) {
    // Guard: if already initialised with a live context, do nothing.
    if (display != EGL_NO_DISPLAY && context != EGL_NO_CONTEXT && surface != EGL_NO_SURFACE) {
        return true;
    }

    display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (display == EGL_NO_DISPLAY) { LOGE("eglGetDisplay failed"); return false; }

    if (!eglInitialize(display, nullptr, nullptr)) {
        LOGE("eglInitialize failed: 0x%x", eglGetError());
        return false;
    }

    // Require OpenGL ES 3.1 — needed for compute shaders and vertex-stage SSBOs.
    const EGLint attribs[] = {
        EGL_SURFACE_TYPE,     EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE,  EGL_OPENGL_ES3_BIT_KHR,
        EGL_RED_SIZE,   8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE,  8,
        EGL_ALPHA_SIZE, 0,
        EGL_DEPTH_SIZE, 16,
        EGL_NONE
    };

    EGLint numConfigs = 0;
    if (!eglChooseConfig(display, attribs, &config, 1, &numConfigs) || numConfigs == 0) {
        LOGE("eglChooseConfig failed: 0x%x", eglGetError());
        return false;
    }

    // Request ES 3.1 explicitly via major/minor version attributes.
    const EGLint contextAttribs[] = {
        EGL_CONTEXT_MAJOR_VERSION, 3,
        EGL_CONTEXT_MINOR_VERSION, 1,
        EGL_NONE
    };

    context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttribs);
    if (context == EGL_NO_CONTEXT) {
        LOGE("eglCreateContext (ES 3.1) failed: 0x%x — trying ES 3.0 fallback", eglGetError());
        const EGLint fallback[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
        context = eglCreateContext(display, config, EGL_NO_CONTEXT, fallback);
        if (context == EGL_NO_CONTEXT) {
            LOGE("eglCreateContext (ES 3.0 fallback) also failed: 0x%x", eglGetError());
            return false;
        }
    }

    surface = eglCreateWindowSurface(display, config, window, nullptr);
    if (surface == EGL_NO_SURFACE) {
        LOGE("eglCreateWindowSurface failed: 0x%x", eglGetError());
        return false;
    }

    if (!eglMakeCurrent(display, surface, surface, context)) {
        LOGE("eglMakeCurrent failed: 0x%x", eglGetError());
        return false;
    }

    LOGI("EGL initialised successfully. Surface %dx%d", getWidth(), getHeight());
    return true;
}

void EGLCore::swapBuffers() {
    if (display != EGL_NO_DISPLAY && surface != EGL_NO_SURFACE) {
        eglSwapBuffers(display, surface);
    }
}

int EGLCore::getWidth() {
    EGLint w = 0;
    if (display != EGL_NO_DISPLAY && surface != EGL_NO_SURFACE)
        eglQuerySurface(display, surface, EGL_WIDTH, &w);
    return w;
}

int EGLCore::getHeight() {
    EGLint h = 0;
    if (display != EGL_NO_DISPLAY && surface != EGL_NO_SURFACE)
        eglQuerySurface(display, surface, EGL_HEIGHT, &h);
    return h;
}

void EGLCore::release() {
    if (display != EGL_NO_DISPLAY) {
        eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (context != EGL_NO_CONTEXT) { eglDestroyContext(display, context); context = EGL_NO_CONTEXT; }
        if (surface != EGL_NO_SURFACE) { eglDestroySurface(display, surface); surface = EGL_NO_SURFACE; }
        eglTerminate(display);
        display = EGL_NO_DISPLAY;
    }
}
