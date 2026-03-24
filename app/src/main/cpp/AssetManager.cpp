#include "AssetManager.h"
#include <android/log.h>

#define LOG_TAG "AssetManager"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Initialize the static member
AAssetManager* NativeAssetManager::assetManager = nullptr;

void NativeAssetManager::init(AAssetManager* manager) {
    assetManager = manager;
}

std::string NativeAssetManager::loadShaderText(const char* filename) {
    if (!assetManager) {
        LOGE("CRITICAL: AssetManager not initialized before use!");
        return "";
    }

    // AASSET_MODE_BUFFER reads the file into memory efficiently
    AAsset* asset = AAssetManager_open(assetManager, filename, AASSET_MODE_BUFFER);
    if (!asset) {
        LOGE("Failed to locate or open asset: %s", filename);
        return "";
    }

    // Get the file size to allocate the exact amount of memory needed
    off_t length = AAsset_getLength(asset);
    
    // Create a string of the correct size pre-filled with null terminators
    std::string content(length, '\0');
    
    // Read the raw bytes directly into the C++ string's memory buffer
    AAsset_read(asset, &content[0], length);
    
    // Always close the asset to prevent memory leaks
    AAsset_close(asset);

    return content;
}
