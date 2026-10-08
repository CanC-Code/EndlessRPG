#pragma once
#include <GLES3/gl31.h>
#include <android/asset_manager.h>
#include <vector>
#include "GrassSim.h"
#include "BladeMeshBuilder.h"
void setupBladePipeline(GLuint* p, GLuint* v, GLuint* b, AAssetManager* am);
void drawBlades(GLuint p, GLuint v, GLuint b, const float* mvp,
                const std::vector<GrassTile>& tiles,
                float cx, float cy, float cz, float tm,
                std::vector<BladeVertex>& sc);

