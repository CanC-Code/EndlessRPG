#pragma once
#include "EGLCore.h"
#include "Renderer.h"
#include <atomic>
#include <thread>
#include <mutex>
#include <condition_variable>

class RenderLoop {
public:
    RenderLoop(EGLCore* egl, GrassRenderer* renderer);
    ~RenderLoop();

    void start();
    void stop();
    void setWindow(ANativeWindow* window);

private:
    void run();

    EGLCore* eglCore;
    GrassRenderer* grassRenderer;
    
    std::thread renderThread;
    std::atomic<bool> isRunning;
    std::mutex loopMutex;
    std::condition_variable condVar;
    ANativeWindow* activeWindow;
};
