#include "RenderLoop.h"
#include <chrono>

RenderLoop::RenderLoop(EGLCore* egl, GrassRenderer* renderer) 
    : eglCore(egl), grassRenderer(renderer), running(false) {}

RenderLoop::~RenderLoop() {
    stop();
}

void RenderLoop::start() {
    if (running) return;
    running = true;
    loopThread = std::thread(&RenderLoop::run, this);
}

void RenderLoop::stop() {
    running = false;
    if (loopThread.joinable()) {
        loopThread.join();
    }
}

void RenderLoop::run() {
    auto lastTime = std::chrono::high_resolution_clock::now();
    float totalTime = 0.0f;

    while (running) {
        auto currentTime = std::chrono::high_resolution_clock::now();
        float deltaTime = std::chrono::duration<float>(currentTime - lastTime).count();
        lastTime = currentTime;
        totalTime += deltaTime;

        if (grassRenderer && eglCore) {
            // Fetch dynamic screen size to handle rotation/scaling
            int width = eglCore->getWidth();
            int height = eglCore->getHeight();
            
            // Execute the compute logic and rendering
            grassRenderer->updateAndRender(totalTime, deltaTime, width, height);
            
            // Push the drawn frame to the physical display
            eglCore->swapBuffers();
        }
    }
}
