#include <jni.h>
#include <android/log.h>
#include <android/asset_manager_jni.h>
#include <vector>
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <functional>

// Internal headers
#include "AssetManager.h"

#define LOG_TAG "GameEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// --- Job System (Thread Pool) ---
/** * Manages a pool of worker threads. Packaged tasks (Jobs) are fed into the queue 
 * and executed by the next available physical CPU core.
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
                    task(); // Execute procedural generation logic
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

// --- JNI Bridge Functions ---

extern "C" {

/**
 * Connects the Android OS Asset Manager to the Native C++ layer.
 * This must be called before loading any shaders or textures.
 */
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initAssetManager(JNIEnv* env, jobject /* this */, jobject javaAssetManager) {
    AAssetManager* nativeManager = AAssetManager_fromJava(env, javaAssetManager);
    if (nativeManager == nullptr) {
        LOGE("Failed to extract AAssetManager from Java object.");
        return;
    }
    
    NativeAssetManager::init(nativeManager);
    LOGI("Native Asset Manager linked and initialized.");
}

/**
 * Initializes the multithreaded job system based on device hardware.
 */
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initEngine(JNIEnv* env, jobject /* this */) {
    // Check hardware to prevent thread thrashing
    unsigned int cores = std::thread::hardware_concurrency();
    if (cores == 0) cores = 4; // Sensible default for mobile
    
    LOGI("Booting DungeonMaster Engine with JobSystem on %u cores.", cores);
    engineThreadPool = new JobSystem(cores);

    // Initial load: Queue the 30 logical processes for world generation
    for (int i = 0; i < 30; ++i) {
        engineThreadPool->enqueue([i] {
            // Placeholder for real logic: terrain heightmap generation, 
            // vegetation distribution patterns, or water flow logic.
            LOGI("JobSystem: Processing procedural logic chunk %d...", i);
        });
    }
}

/**
 * Cleanly shuts down the engine and releases memory.
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
