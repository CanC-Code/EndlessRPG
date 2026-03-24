#include "EGLCore.h"
#include <android/log.h>

#define LOG_TAG "EGLCore"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/**
 * Constructor: Initializes EGL handles to null/none states.
 */
EGLCore::EGLCore() : display(EGL_NO_DISPLAY), surface(EGL_NO_SURFACE), context(EGL_NO_CONTEXT) {}

/**
 * Destructor: Ensures GPU resources are detached and freed if the object is destroyed.
 */
EGLCore::~EGLCore() {
    release();
}

/**
 * Initializes the EGL display, selects a hardware configuration, 
 * creates the rendering surface, and binds the OpenGL ES 3.1 context.
 */
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

    // Configuration attributes for the GPU. 
    // We request 8-bit color channels and a 24-bit depth buffer for realism.
    const EGLint configAttribs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT_KHR,
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_BLUE_SIZE, 8,
        EGL_GREEN_SIZE, 8,
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

    // Create the surface from the Android Native Window
    surface = eglCreateWindowSurface(display, config, window, nullptr);
    if (surface == EGL_NO_SURFACE) {
        LOGE("eglCreateWindowSurface failed");
        return false;
    }

    // Explicitly request GLES 3.1 to ensure Compute Shader compatibility
    const EGLint contextAttribs[] = { 
        EGL_CONTEXT_CLIENT_VERSION, 3, 
        EGL_NONE 
    };

    context = eglCreateContext(display, config, EGL_NO_CONTEXT, contextAttribs);
    if (context == EGL_NO_CONTEXT) {
        LOGE("eglCreateContext failed");
        return false;
    }

    // Bind the context to the current thread and surface
    if (!eglMakeCurrent(display, surface, surface, context)) {
        LOGE("eglMakeCurrent failed");
        return false;
    }

    return true;
}

/**
 * Swaps the back buffer to the front, displaying the rendered frame to the user.
 */
void EGLCore::swapBuffers() {
    if (display != EGL_NO_DISPLAY && surface != EGL_NO_SURFACE) {
        eglSwapBuffers(display, surface);
    }
}

/**
 * Detaches the context and destroys all EGL handles.
 */
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

/**
 * Queries the physical width of the active rendering surface.
 * Used by the Renderer to set the viewport and projection aspect ratio.
 */
int EGLCore::getWidth() {
    if (display == EGL_NO_DISPLAY || surface == EGL_NO_SURFACE) return 0;
    EGLint width;
    eglQuerySurface(display, surface, EGL_WIDTH, &width);
    return width;
}

/**
 * Queries the physical height of the active rendering surface.
 */
int EGLCore::getHeight() {
    if (display == EGL_NO_DISPLAY || surface == EGL_NO_SURFACE) return 0;
    EGLint height;
    eglQuerySurface(display, surface, EGL_HEIGHT, &height);
    return height;
}
