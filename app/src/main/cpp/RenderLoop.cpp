#include "RenderLoop.h"
#include <android/log.h>
#include <chrono>

#define LOG_TAG "RenderLoop"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

RenderLoop::RenderLoop(EGLCore* egl, GrassRenderer* renderer)
    : eglCore(egl), grassRenderer(renderer), isRunning(false), activeWindow(nullptr) {}

RenderLoop::~RenderLoop() { stop(); }

void RenderLoop::start() {
    isRunning    = true;
    renderThread = std::thread(&RenderLoop::run, this);
}

void RenderLoop::stop() {
    isRunning = false;
    condVar.notify_all();
    if (renderThread.joinable()) renderThread.join();
}

// Called from the main thread after start() to hand the window to the render thread.
void RenderLoop::setWindow(ANativeWindow* window) {
    {
        std::lock_guard<std::mutex> lock(loopMutex);
        activeWindow = window;
    }
    condVar.notify_all();
}

void RenderLoop::run() {
    // -----------------------------------------------------------------------
    // Phase 1 — wait for a valid ANativeWindow.
    // -----------------------------------------------------------------------
    {
        std::unique_lock<std::mutex> lock(loopMutex);
        condVar.wait(lock, [this] { return activeWindow != nullptr || !isRunning; });
    }

    if (!isRunning) return;

    ANativeWindow* window = activeWindow; // captured once; window won't change

    // -----------------------------------------------------------------------
    // Phase 2 — initialise EGL on THIS thread (required by the OpenGL spec).
    // eglCore->init() is called exactly once here, not every frame.
    // -----------------------------------------------------------------------
    if (!eglCore->init(window)) {
        LOGE("EGL init failed — render loop aborting.");
        return;
    }

    // -----------------------------------------------------------------------
    // Phase 3 — init the renderer (needs an active GL context, hence on this thread).
    // -----------------------------------------------------------------------
    grassRenderer->init();

    // -----------------------------------------------------------------------
    // Phase 4 — main render loop.
    // -----------------------------------------------------------------------
    auto startTime = std::chrono::high_resolution_clock::now();
    auto lastFrame = startTime;

    while (isRunning) {
        auto now = std::chrono::high_resolution_clock::now();
        float time = std::chrono::duration<float>(now - startTime).count();
        float dt   = std::chrono::duration<float>(now - lastFrame).count();
        lastFrame  = now;

        int w = eglCore->getWidth();
        int h = eglCore->getHeight();
        if (w <= 0) w = 1920;
        if (h <= 0) h = 1080;

        grassRenderer->updateAndRender(time, dt, w, h);
        eglCore->swapBuffers();
    }

    LOGI("Render thread exiting cleanly.");
}
