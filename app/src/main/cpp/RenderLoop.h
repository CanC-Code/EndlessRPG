#pragma once
#include <thread>
#include <atomic>
#include "EGLCore.h"
#include "Renderer.h"

class RenderLoop {
public:
    RenderLoop(EGLCore* egl, GrassRenderer* renderer);
    ~RenderLoop();

    void start();
    void stop();

private:
    void run();

    EGLCore* eglCore;
    GrassRenderer* grassRenderer;
    std::thread loopThread;
    std::atomic<bool> running;
};
