#include <jni.h>
#include <android/native_window_jni.h>
#include <android/asset_manager_jni.h> // REQUIRED for AAssetManager_fromJava
#include "EGLCore.h"
#include "Renderer.h"
#include "RenderLoop.h"
#include "AssetManager.h"

EGLCore* eglCore = nullptr;
GrassRenderer* renderer = nullptr;
RenderLoop* renderLoop = nullptr;

extern "C" JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initAssetManager(JNIEnv* env, jobject thiz, jobject assetManager) {
    // FIXED: Convert the Java jobject to a native AAssetManager* first
    AAssetManager* nativeManager = AAssetManager_fromJava(env, assetManager);
    NativeAssetManager::init(nativeManager); 
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initEngine(JNIEnv* env, jobject thiz) {
    eglCore = new EGLCore();
    renderer = new GrassRenderer();
    renderer->init();
    renderLoop = new RenderLoop(eglCore, renderer);
    renderLoop->start();
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_shutdownEngine(JNIEnv* env, jobject thiz) {
    if (renderLoop) { renderLoop->stop(); delete renderLoop; renderLoop = nullptr; }
    if (renderer) { delete renderer; renderer = nullptr; }
    if (eglCore) { delete eglCore; eglCore = nullptr; }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_onSurfaceCreated(JNIEnv* env, jobject thiz, jobject surface) {
    ANativeWindow* window = ANativeWindow_fromSurface(env, surface);
    if (renderLoop) renderLoop->setWindow(window);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_onSurfaceChanged(JNIEnv* env, jobject thiz, jint width, jint height) {
    // Handled by RenderLoop querying EGL dimensions
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_releaseNativeSurface(JNIEnv* env, jobject thiz) {
    if (renderLoop) renderLoop->setWindow(nullptr);
}

// --- NEW INPUT BRIDGE ---
extern "C" JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_updateInput(JNIEnv* env, jobject thiz, jfloat moveX, jfloat moveY, jfloat lookDX, jfloat lookDY) {
    if (renderer) {
        renderer->updateInput(moveX, moveY, lookDX, lookDY);
    }
}
