#pragma once
#include <android/asset_manager.h>
#include <string>
#include <vector>

class NativeAssetManager {
public:
    // Stores the pointer from the Android OS
    static void init(AAssetManager* manager);
    
    // Reads a text file (like our .comp, .vert, .frag shaders) into a C++ string
    static std::string loadShaderText(const char* filename);

private:
    static AAssetManager* assetManager;
};
