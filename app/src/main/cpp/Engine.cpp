#include <jni.h>
#include <android/log.h>
#include <vector>
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <functional>

#define LOG_TAG "GameEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

// --- Job System (Thread Pool) ---
// This prevents lag by limiting concurrent threads to the actual physical cores.
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
                    task(); // Execute the procedural logic
                }
            });
        }
    }

    // Add one of your 30 computational processes here
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

// Global Engine State
JobSystem* engineThreadPool = nullptr;

extern "C" JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initEngine(JNIEnv* env, jobject /* this */) {
    // Determine the number of hardware cores to prevent lag/thrashing
    unsigned int cores = std::thread::hardware_concurrency();
    if (cores == 0) cores = 4; // Fallback
    
    LOGI("Initializing Engine Thread Pool with %u cores", cores);
    engineThreadPool = new JobSystem(cores);

    // Example: Queuing up 30 procedural generation tasks safely
    for (int i = 0; i < 30; ++i) {
        engineThreadPool->enqueue([i] {
            // This is where grass growth logic, wind physics, or terrain chunk generation happens
            LOGI("Executing background process %d on worker thread", i);
        });
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_shutdownEngine(JNIEnv* env, jobject /* this */) {
    delete engineThreadPool;
    engineThreadPool = nullptr;
    LOGI("Engine shut down safely.");
}
