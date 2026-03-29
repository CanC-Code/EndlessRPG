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

static std::thread gRenderThread;
static std::atomic<bool> gIsRendering{false};

// The Unified Native Render Thread
void startRenderLoop() {
    if (!gEGLCore || !gWindow) return;
    
    // Bind the Android Surface to the OpenGL Context
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
        
        // Ensure surface is valid before executing shader dispatches
        if (gRenderer && w > 0 && h > 0) {
            gRenderer->updateAndRender(totalTime, dt, w, h);
            gEGLCore->swapBuffers();
        } else {
            // Sleep briefly if waiting on surface layout to save battery
            std::this_thread::sleep_for(std::chrono::milliseconds(16));
        }
    }
    
    gEGLCore->release();
    LOGI("EGL context released.");
}

extern "C" {

// ---- MAIN ACTIVITY CALLBACKS ----

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initEngine(JNIEnv* env, jobject thiz) {
    if (!gRenderer) gRenderer = new GrassRenderer();
    if (!gEGLCore) gEGLCore = new EGLCore();
    LOGI("Engine Initialized");
}

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_updateInput(JNIEnv* env, jobject thiz, 
    jfloat mx, jfloat my, jfloat lx, jfloat ly, jboolean tp, jfloat zoom) {
    if (gRenderer) {
        gRenderer->updateInput(mx, my, lx, ly, (bool)tp, zoom);
    }
}

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_shutdownEngine(JNIEnv* env, jobject thiz) {
    // Safely stop the render thread before deleting pointers
    gIsRendering = false;
    if (gRenderThread.joinable()) {
        gRenderThread.join();
    }
    
    if (gEGLCore) {
        delete gEGLCore;
        gEGLCore = nullptr;
    }
    
    if (gRenderer) {
        delete gRenderer;
        gRenderer = nullptr;
    }
    LOGI("Engine Shutdown");
}

JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initAssetManager(JNIEnv* env, jobject thiz, jobject assetManager) {
    AAssetManager* am = AAssetManager_fromJava(env, assetManager);
}

// ---- GAME SURFACE VIEW CALLBACKS (The missing links that caused the crash!) ----

JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_surfaceCreated(JNIEnv* env, jobject thiz, jobject surface) {
    if (gWindow) {
        ANativeWindow_release(gWindow);
    }
    
    // Convert the Kotlin 'android.view.Surface' into a C++ ANativeWindow
    gWindow = ANativeWindow_fromSurface(env, surface);
    
    // Start the render thread now that we have a canvas!
    gIsRendering = true;
    gRenderThread = std::thread(startRenderLoop);
    LOGI("Surface Created & Render Thread Started");
}

JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_surfaceChanged(JNIEnv* env, jobject thiz, jint width, jint height) {
    LOGI("Surface dimensions changed to %d x %d", width, height);
}

JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_releaseNativeSurface(JNIEnv* env, jobject thiz) {
    gIsRendering = false;
    if (gRenderThread.joinable()) {
        gRenderThread.join();
    }
    if (gWindow) {
        ANativeWindow_release(gWindow);
        gWindow = nullptr;
    }
    LOGI("Surface Destroyed & Render Thread Stopped");
}

} // extern "C"
