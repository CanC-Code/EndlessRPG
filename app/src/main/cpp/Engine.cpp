#include <jni.h>
#include <android/log.h>
#include <android/asset_manager_jni.h>
#include <android/native_window_jni.h>
#include <vector>
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <functional>

#include "AssetManager.h"
#include "EGLCore.h"
#include "Renderer.h"
#include "RenderLoop.h"

#define LOG_TAG "DungeonMaster"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

class JobSystem {
private:
    std::vector<std::thread> workers;
    std::queue<std::function<void()>> tasks;
    std::mutex queue_mutex;
    std::condition_variable condition;
    bool stop = false;
public:
    JobSystem(size_t threads) {
        for(size_t i = 0; i < threads; ++i) {
            workers.emplace_back([this] {
                while(true) {
                    std::function<void()> task;
                    {
                        std::unique_lock<std::mutex> lock(this->queue_mutex);
                        this->condition.wait(lock, [this]{ return this->stop || !this->tasks.empty(); });
                        if(this->stop && this->tasks.empty()) return;
                        task = std::move(this->tasks.front());
                        this->tasks.pop();
                    }
                    task();
                }
            });
        }
    }
    template<class F> void enqueue(F&& f) {
        { std::unique_lock<std::mutex> lock(queue_mutex); tasks.emplace(std::forward<F>(f)); }
        condition.notify_one();
    }
    ~JobSystem() {
        { std::unique_lock<std::mutex> lock(queue_mutex); stop = true; }
        condition.notify_all();
        for(std::thread &worker: workers) worker.join();
    }
};

JobSystem* engineThreadPool = nullptr;
EGLCore* graphicsBridge = nullptr;
GrassRenderer* renderer = nullptr;
RenderLoop* mainLoop = nullptr;
ANativeWindow* nativeWindow = nullptr;

extern "C" {
JNIEXPORT void JNICALL Java_com_example_game_MainActivity_initAssetManager(JNIEnv* env, jobject thiz, jobject am) {
    NativeAssetManager::init(AAssetManager_fromJava(env, am));
}
JNIEXPORT void JNICALL Java_com_example_game_MainActivity_initEngine(JNIEnv* env, jobject thiz) {
    engineThreadPool = new JobSystem(std::thread::hardware_concurrency());
    for (int i = 0; i < 30; ++i) engineThreadPool->enqueue([i] { LOGI("Task %d running", i); });
}
JNIEXPORT void JNICALL Java_com_example_game_GameSurfaceView_setNativeSurface(JNIEnv* env, jobject thiz, jobject surface) {
    nativeWindow = ANativeWindow_fromSurface(env, surface);
    graphicsBridge = new EGLCore();
    if (graphicsBridge->init(nativeWindow)) {
        renderer = new GrassRenderer();
        renderer->init();
        mainLoop = new RenderLoop(graphicsBridge, renderer);
        mainLoop->start();
    }
}
JNIEXPORT void JNICALL Java_com_example_game_MainActivity_shutdownEngine(JNIEnv* env, jobject thiz) {
    delete engineThreadPool;
}
}
