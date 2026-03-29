#include <jni.h>
#include <android/asset_manager_jni.h>
#include "Renderer.h"
#include <android/log.h>

#define LOG_TAG "NativeEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

// Global pointer to your renderer instance
static GrassRenderer* gRenderer = nullptr;

extern "C" {

// Maps to: MainActivity.initEngine()
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initEngine(JNIEnv* env, jobject thiz) {
    if (gRenderer == nullptr) {
        gRenderer = new GrassRenderer();
        // IMPORTANT: Ensure GrassRenderer::init() does NOT call OpenGL functions yet.
        gRenderer->init(); 
        LOGI("Engine Initialized");
    }
}

// Maps to: MainActivity.updateInput(...)
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_updateInput(JNIEnv* env, jobject thiz, 
    jfloat mx, jfloat my, jfloat lx, jfloat ly, jboolean tp, jfloat zoom) {
    if (gRenderer != nullptr) {
        gRenderer->updateInput(mx, my, lx, ly, (bool)tp, zoom);
    }
}

// Maps to: MainActivity.shutdownEngine()
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_shutdownEngine(JNIEnv* env, jobject thiz) {
    if (gRenderer != nullptr) {
        delete gRenderer;
        gRenderer = nullptr;
        LOGI("Engine Shutdown");
    }
}

// Maps to: MainActivity.initAssetManager(assets)
JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initAssetManager(JNIEnv* env, jobject thiz, jobject assetManager) {
    AAssetManager* am = AAssetManager_fromJava(env, assetManager);
    if (am == nullptr) {
        LOGI("Failed to load AssetManager");
        return;
    }
    // If you have a global AssetManager wrapper in C++, initialize it here:
    // AssetManager::init(am); 
}

} // extern "C"
