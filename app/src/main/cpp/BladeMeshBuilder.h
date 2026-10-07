#pragma once
#include "GrassSim.h"

struct BladeVertex {
    float   x, y, z;
    float   u, v;
    uint8_t r, g, b, a;
};

struct CameraView {
    float x, y, z;
};

// Writes up to maxVerts vertices into outVerts.
// Returns number of triangles written (0 = nothing to draw).
int build_frame_grass(const std::vector<GrassTile>& tiles,
                      const CameraView& cam,
                      float windTime,
                      BladeVertex* outVerts,
                      int maxVerts);
