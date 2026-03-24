#include <jni.h>
#include <android/native_window_jni.h>
#include <android/asset_manager_jni.h> 
#include "EGLCore.h"
#include "Renderer.h"
#include "RenderLoop.h"
#include "AssetManager.h"

// Global engine components
EGLCore* eglCore = nullptr;
GrassRenderer* renderer = nullptr;
RenderLoop* renderLoop = nullptr;

extern "C" JNIEXPORT void JNICALL
Java_com_example_game_MainActivity_initAssetManager(JNIEnv* env, jobject thiz, jobject assetManager) {
    // Convert the Java jobject to a native AAssetManager* for the C++ side
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
    // Window resizing is handled automatically by the RenderLoop
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_releaseNativeSurface(JNIEnv* env, jobject thiz) {
    if (renderLoop) renderLoop->setWindow(nullptr);
}

// --- UPDATED INPUT BRIDGE ---
// This function now accepts the view mode and zoom level
extern "C" JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_updateInput(JNIEnv* env, jobject thiz, 
                                                jfloat moveX, jfloat moveY, 
                                                jfloat lookDX, jfloat lookDY, 
                                                jboolean isThirdPerson, 
                                                jfloat zoom) {
    if (renderer) {
        // Pass the new camera states into the renderer's update logic
        renderer->updateInput(moveX, moveY, lookDX, lookDY, (bool)isThirdPerson, zoom);
    }
}
