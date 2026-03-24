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

#define LOG_TAG "EndlessRPG"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// ---------------------------------------------------------------------------
// Minimal job system — kept for future use.
// ---------------------------------------------------------------------------
class JobSystem {
    std::vector<std::thread> workers;
    std::queue<std::function<void()>> tasks;
    std::mutex queue_mutex;
    std::condition_variable condition;
    bool stop = false;
public:
    explicit JobSystem(size_t threads) {
        for (size_t i = 0; i < threads; ++i) {
            workers.emplace_back([this] {
                while (true) {
                    std::function<void()> task;
                    {
                        std::unique_lock<std::mutex> lk(queue_mutex);
                        condition.wait(lk, [this] { return stop || !tasks.empty(); });
                        if (stop && tasks.empty()) return;
                        task = std::move(tasks.front());
                        tasks.pop();
                    }
                    task();
                }
            });
        }
    }
    template<class F> void enqueue(F&& f) {
        { std::unique_lock<std::mutex> lk(queue_mutex); tasks.emplace(std::forward<F>(f)); }
        condition.notify_one();
    }
    ~JobSystem() {
        { std::unique_lock<std::mutex> lk(queue_mutex); stop = true; }
        condition.notify_all();
        for (auto& w : workers) w.join();
    }
};

// ---------------------------------------------------------------------------
// Global engine state
// ---------------------------------------------------------------------------
static JobSystem*    engineThreadPool = nullptr;
static EGLCore*      graphicsBridge   = nullptr;
static GrassRenderer* renderer        = nullptr;
static RenderLoop*   mainLoop         = nullptr;
static ANativeWindow* nativeWindow    = nullptr;

extern "C" {

// Called from MainActivity.onCreate — stores the Java AssetManager pointer.
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initAssetManager(JNIEnv* env, jobject /*thiz*/, jobject am) {
    NativeAssetManager::init(AAssetManager_fromJava(env, am));
    LOGI("AssetManager initialised.");
}

// Called from MainActivity.onCreate — creates the job pool.
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initEngine(JNIEnv* /*env*/, jobject /*thiz*/) {
    unsigned int cores = std::thread::hardware_concurrency();
    engineThreadPool = new JobSystem(cores > 0 ? cores : 4);
    LOGI("Engine initialised with %u worker threads.", cores > 0 ? cores : 4u);
}

// Called from GameSurfaceView.surfaceCreated — sets up EGL + renderer + render loop.
// FIX: After start(), call setWindow() so the render thread's condvar wakes up.
JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_setNativeSurface(JNIEnv* env, jobject /*thiz*/, jobject surface) {
    // Obtain the ANativeWindow from the Java Surface object.
    nativeWindow = ANativeWindow_fromSurface(env, surface);
    if (!nativeWindow) {
        LOGE("ANativeWindow_fromSurface returned null — cannot render.");
        return;
    }

    // Create EGL context on the render thread later (via RenderLoop::run).
    // We pass the window to RenderLoop; it will call eglCore->init() inside its thread.
    graphicsBridge = new EGLCore();
    renderer       = new GrassRenderer();
    mainLoop       = new RenderLoop(graphicsBridge, renderer);

    // Start the render thread first, then hand it the window.
    // Without setWindow() the thread would block on condvar forever → black screen.
    mainLoop->start();
    mainLoop->setWindow(nativeWindow);   // <── THE CRITICAL FIX
    LOGI("Render loop started, window handed off.");
}

// Called from GameSurfaceView.surfaceDestroyed.
JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_releaseNativeSurface(JNIEnv* /*env*/, jobject /*thiz*/) {
    if (mainLoop)       { mainLoop->stop();        delete mainLoop;       mainLoop       = nullptr; }
    if (renderer)       {                           delete renderer;       renderer       = nullptr; }
    if (graphicsBridge) { graphicsBridge->release(); delete graphicsBridge; graphicsBridge = nullptr; }
    if (nativeWindow)   { ANativeWindow_release(nativeWindow); nativeWindow = nullptr; }
    LOGI("Native surface released.");
}

// Called from MainActivity.onDestroy.
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_shutdownEngine(JNIEnv* /*env*/, jobject /*thiz*/) {
    if (engineThreadPool) { delete engineThreadPool; engineThreadPool = nullptr; }
    LOGI("Engine shutdown complete.");
}

} // extern "C"
