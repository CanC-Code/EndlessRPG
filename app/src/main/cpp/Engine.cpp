#include "Engine.h"
#include <android/log.h>

#define LOG_TAG "ProceduralEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

// If you have an Engine class implementation here, KEEP IT. 
// For example:
// Engine::Engine() { ... }
// void Engine::start() { ... }

// REMOVE the entire extern "C" { ... } block from this file!
// It should NO LONGER contain:
// JNIEXPORT void JNICALL Java_com_example_game_MainActivity_initEngine(...)
// JNIEXPORT void JNICALL Java_com_example_game_MainActivity_initAssetManager(...)
// JNIEXPORT void JNICALL Java_com_example_game_MainActivity_shutdownEngine(...)
