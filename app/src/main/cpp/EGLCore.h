#pragma once
#include <EGL/egl.h>
#include <android/native_window.h>

class EGLCore {
public:
    EGLCore();
    ~EGLCore();

    // Initializes EGL for a given native window (Surface)
    bool init(ANativeWindow* window);
    
    // Swaps the front and back buffers to display the rendered frame
    void swapBuffers();
    
    // Cleans up EGL resources
    void release();

private:
    EGLDisplay display;
    EGLConfig  config;
    EGLSurface surface;
    EGLContext context;
};
