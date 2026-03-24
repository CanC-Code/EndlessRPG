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

// Internal Engine headers
#include "AssetManager.h"
#include "EGLCore.h"

#define LOG_TAG "DungeonMasterEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// --- Job System (Thread Pool) ---
/** * Manages physical CPU resources to execute computational processes.
 * Packs 30+ logic tasks into a queue that physical cores pull from,
 * preventing UI lag by never over-subscribing the hardware.
 */
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
                    task(); // Execute procedural/computational logic
                }
            });
        }
    }

    template<class F>
    void enqueue(F&& f) {
        {
            std::unique_lock<std::mutex> lock(queue_mutex);
            tasks.emplace(std::forward<F>(f));
        }
        condition.notify_one();
    }

    ~JobSystem() {
        {
            std::unique_lock<std::mutex> lock(queue_mutex);
            stop = true;
        }
        condition.notify_all();
        for(std::thread &worker: workers) {
            worker.join();
        }
    }
};

// --- Global Engine State ---
JobSystem* engineThreadPool = nullptr;
EGLCore* graphicsBridge = nullptr;
ANativeWindow* nativeWindow = nullptr;

// --- JNI Bridge Functions ---
extern "C" {

/**
 * 1. ASSET INITIALIZATION
 * Connects the Android APK asset folder to C++.
 */
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initAssetManager(JNIEnv* env, jobject /* this */, jobject javaAssetManager) {
    AAssetManager* nativeManager = AAssetManager_fromJava(env, javaAssetManager);
    if (nativeManager == nullptr) {
        LOGE("Failed to extract AAssetManager.");
        return;
    }
    NativeAssetManager::init(nativeManager);
    LOGI("Native Asset Manager linked successfully.");
}

/**
 * 2. ENGINE LOGIC INITIALIZATION
 * Boots the Job System and dispatches the 30 computational processes.
 */
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initEngine(JNIEnv* env, jobject /* this */) {
    unsigned int cores = std::thread::hardware_concurrency();
    if (cores == 0) cores = 4;
    
    LOGI("Booting Engine on %u cores.", cores);
    engineThreadPool = new JobSystem(cores);

    // Dispatch the 30 computational processes immediately
    for (int i = 0; i < 30; ++i) {
        engineThreadPool->enqueue([i] {
            // Logic for grass growth, wind vectors, and world generation
            LOGI("JobSystem: Processing logic task %d on background thread.", i);
        });
    }
}

/**
 * 3. GRAPHICS SURFACE INITIALIZATION
 * Connects the GameSurfaceView to the GPU.
 */
JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_setNativeSurface(JNIEnv* env, jobject /* this */, jobject surface) {
    // Acquire the native window handle from the Android Surface
    nativeWindow = ANativeWindow_fromSurface(env, surface);
    
    graphicsBridge = new EGLCore();
    if (graphicsBridge->init(nativeWindow)) {
        LOGI("EGL Graphics Bridge initialized. GPU is ready for procedural rendering.");
        
        // At this point, you would typically start the Render Loop thread.
    } else {
        LOGE("EGL initialization failed.");
    }
}

/**
 * 4. SURFACE CLEANUP
 * Detaches the GPU context when the surface is destroyed.
 */
JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_releaseNativeSurface(JNIEnv* env, jobject /* this */) {
    if (graphicsBridge) {
        graphicsBridge->release();
        delete graphicsBridge;
        graphicsBridge = nullptr;
    }
    if (nativeWindow) {
        ANativeWindow_release(nativeWindow);
        nativeWindow = nullptr;
    }
    LOGI("Native Surface released and EGL cleaned up.");
}

/**
 * 5. ENGINE SHUTDOWN
 * Final cleanup of the Job System and associated memory.
 */
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_shutdownEngine(JNIEnv* env, jobject /* this */) {
    if (engineThreadPool) {
        delete engineThreadPool;
        engineThreadPool = nullptr;
    }
    LOGI("DungeonMaster Engine shut down gracefully.");
}

} // extern "C"
