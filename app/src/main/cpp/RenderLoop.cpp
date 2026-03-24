#include "RenderLoop.h"
#include <chrono>

RenderLoop::RenderLoop(EGLCore* egl, GrassRenderer* renderer) 
    : eglCore(egl), grassRenderer(renderer), isRunning(false), activeWindow(nullptr) {}

RenderLoop::~RenderLoop() { stop(); }

void RenderLoop::start() {
    isRunning = true;
    renderThread = std::thread(&RenderLoop::run, this);
}

void RenderLoop::stop() {
    isRunning = false;
    condVar.notify_all();
    if (renderThread.joinable()) renderThread.join();
}

void RenderLoop::setWindow(ANativeWindow* window) {
    std::lock_guard<std::mutex> lock(loopMutex);
    activeWindow = window;
    condVar.notify_all();
}

void RenderLoop::run() {
    auto startTime = std::chrono::high_resolution_clock::now();
    auto lastFrame = startTime;

    while (isRunning) {
        ANativeWindow* currentWindow = nullptr;
        {
            std::unique_lock<std::mutex> lock(loopMutex);
            if (!activeWindow) {
                // If there's no window, safely wait instead of failing or turning black
                condVar.wait(lock, [this] { return activeWindow != nullptr || !isRunning; });
            }
            currentWindow = activeWindow;
        }

        if (!isRunning) break;

        // Initialize EGL Surface if we have a window but no context
        if (currentWindow && !eglCore->init(currentWindow)) {
            continue; // Retry next cycle
        }

        // Calculate Time and DeltaTime
        auto now = std::chrono::high_resolution_clock::now();
        float time = std::chrono::duration<float>(now - startTime).count();
        float dt = std::chrono::duration<float>(now - lastFrame).count();
        lastFrame = now;

        // Force minimum safe screen dimensions
        int w = eglCore->getWidth();
        int h = eglCore->getHeight();
        if (w <= 0) w = 1920; 
        if (h <= 0) h = 1080;

        // Draw and Swap
        grassRenderer->updateAndRender(time, dt, w, h);
        eglCore->swapBuffers();
    }
}
