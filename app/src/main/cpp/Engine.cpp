#include <android/native_window_jni.h> // For ANativeWindow_fromSurface
#include "EGLCore.h"

// Global Graphics State
EGLCore* graphicsBridge = nullptr;
ANativeWindow* nativeWindow = nullptr;

extern "C" {

JNIEXPORT void JNICALL
Java_com_example_game_GameSurfaceView_setNativeSurface(JNIEnv* env, jobject /* this */, jobject surface) {
    // Convert Java Surface to C++ ANativeWindow
    nativeWindow = ANativeWindow_fromSurface(env, surface);
    
    graphicsBridge = new EGLCore();
    if (graphicsBridge->init(nativeWindow)) {
        LOGI("EGL Graphics Bridge initialized on Surface.");
        // Here you would trigger the start of your rendering loop
    }
}

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
}

} // extern "C"
