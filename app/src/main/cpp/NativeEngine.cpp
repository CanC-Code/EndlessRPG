#include <jni.h>
#include <android/native_window_jni.h>
#include <android/native_window.h>
#include <android/asset_manager_jni.h>
#include <android/log.h>
#include <thread>
#include <atomic>
#include <chrono>

#include "Renderer.h"
#include "EGLCore.h"

#define LOG_TAG "NativeEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

static GrassRenderer* gRenderer = nullptr;
static EGLCore* gEGLCore = nullptr;
static ANativeWindow* gWindow = nullptr;
static AAssetManager* gAssetManager = nullptr; // <--- ADDED: Global pointer storage

static std::thread gRenderThread;
static std::atomic<bool> gIsRendering{false};

void startRenderLoop() {
    if (!gEGLCore || !gWindow) return;
    
    gEGLCore->init(gWindow);
    LOGI("EGL context created and surface bound.");

    auto lastTime = std::chrono::high_resolution_clock::now();
    float totalTime = 0.0f;
    
    while (gIsRendering) {
        auto currentTime = std::chrono::high_resolution_clock::now();
        float dt = std::chrono::duration<float>(currentTime - lastTime).count();
        lastTime = currentTime;
        totalTime += dt;
        
        int w = gEGLCore->getWidth();
        int h = gEGLCore->getHeight();
        
        if (gRenderer && w > 0 && h > 0) {
            // Updated to pass the AssetManager so the renderer can read files
            gRenderer->updateAndRender(totalTime, dt, w, h, gAssetManager); 
            gEGLCore->swapBuffers();
        } else {
            std::this_thread::sleep_for(std::chrono::milliseconds(16));
        }
    }
    
    gEGLCore->release();
}

extern "C" {

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initEngine(JNIEnv* env, jobject thiz) {
    if (!gRenderer) gRenderer = new GrassRenderer();
    if (!gEGLCore) gEGLCore = new EGLCore();
}

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_updateInput(JNIEnv* env, jobject thiz, 
    jfloat mx, jfloat my, jfloat lx, jfloat ly, jboolean tp, jfloat zoom) {
    if (gRenderer) gRenderer->updateInput(mx, my, lx, ly, (bool)tp, zoom);
}

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_shutdownEngine(JNIEnv* env, jobject thiz) {
    gIsRendering = false;
    if (gRenderThread.joinable()) gRenderThread.join();
    if (gEGLCore) { delete gEGLCore; gEGLCore = nullptr; }
    if (gRenderer) { delete gRenderer; gRenderer = nullptr; }
}

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initAssetManager(JNIEnv* env, jobject thiz, jobject assetManager) {
    // CRITICAL FIX: Storing the pointer so the C++ side can actually use it
    gAssetManager = AAssetManager_fromJava(env, assetManager);
    LOGI("Asset Manager Initialized and stored.");
}

JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_surfaceCreated(JNIEnv* env, jobject thiz, jobject surface) {
    if (gWindow) ANativeWindow_release(gWindow);
    gWindow = ANativeWindow_fromSurface(env, surface);
    gIsRendering = true;
    gRenderThread = std::thread(startRenderLoop);
}

JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_surfaceChanged(JNIEnv* env, jobject thiz, jint width, jint height) {}

JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_releaseNativeSurface(JNIEnv* env, jobject thiz) {
    gIsRendering = false;
    if (gRenderThread.joinable()) gRenderThread.join();
    if (gWindow) { ANativeWindow_release(gWindow); gWindow = nullptr; }
}

}
