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

// --- Global Engine State ---
JobSystem* engineThreadPool = nullptr;
EGLCore* graphicsBridge = nullptr;
GrassRenderer* renderer = nullptr;
RenderLoop* mainLoop = nullptr;
ANativeWindow* nativeWindow = nullptr;

extern "C" {

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initAssetManager(JNIEnv* env, jobject /* this */, jobject javaAssetManager) {
    NativeAssetManager::init(AAssetManager_fromJava(env, javaAssetManager));
}

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initEngine(JNIEnv* env, jobject /* this */) {
    unsigned int cores = std::thread::hardware_concurrency();
    engineThreadPool = new JobSystem(cores > 0 ? cores : 4);

    // Launch the 30 specific computational processes
    for (int i = 0; i < 30; ++i) {
        engineThreadPool->enqueue([i] {
            // Logic: Biological growth rules, soil simulation, wind mapping
        });
    }
}

JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_setNativeSurface(JNIEnv* env, jobject /* this */, jobject surface) {
    nativeWindow = ANativeWindow_fromSurface(env, surface);
    
    graphicsBridge = new EGLCore();
    if (graphicsBridge->init(nativeWindow)) {
        renderer = new GrassRenderer();
        renderer->init(); // Compiles shaders via AssetManager
        
        mainLoop = new RenderLoop(graphicsBridge, renderer);
        mainLoop->start(); // Starts the visual cycle thread
        LOGI("Engine Visuals Active.");
    }
}

JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_releaseNativeSurface(JNIEnv* env, jobject /* this */) {
    if (mainLoop) {
        mainLoop->stop();
        delete mainLoop;
        mainLoop = nullptr;
    }
    if (renderer) {
        delete renderer;
        renderer = nullptr;
    }
    if (graphicsBridge) {
        graphicsBridge->release();
        delete graphicsBridge;
        graphicsBridge = nullptr;
    }
    if (nativeWindow) {
        ANativeWindow_release(nativeWindow);
        nativeWindow = nullptr;
    }
}

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_shutdownEngine(JNIEnv* env, jobject /* this */) {
    delete engineThreadPool;
    engineThreadPool = nullptr;
}

}
