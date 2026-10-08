#include "BladeMeshBuilder.h"
#include <cmath>

static float terrain_height(float x, float z) {
    return 2.5f * sinf(x * 0.2f) * cosf(z * 0.2f);
}

int build_frame_grass(const std::vector<GrassTile>& tiles,
                      const CameraView& cam,
                      float windTime,
                      BladeVertex* outVerts,
                      int maxVerts) {
    int verts = 0;
    const float R2 = 900.0f, T = 4.0f;
    for (const auto& tile : tiles) {
        float cx = tile.worldX + T*0.5f, cz = tile.worldZ + T*0.5f;
        float dx = cx - cam.x, dz = cz - cam.z;
        if (dx*dx + dz*dz > R2) continue;
        for (const auto& b : tile.blades) {
            if (verts + 3 > maxVerts) return verts / 3;
            float h = b.currentHeight;
            if (h < 0.01f) continue;
            float wx = tile.worldX + (b.localX / 255.0f) * T;
            float wz = tile.worldZ + (b.localZ / 255.0f) * T;
            float gy = terrain_height(wx, wz);
            float ph = (b.seed / 255.0f) * 6.2831853f;
            float sw = (sinf(windTime*1.7f + ph)*0.35f
                      + sinf(windTime*0.9f + ph*1.7f)*0.20f) * h * h;
            float w  = b.width;
            float tx = wx + b.bend * h + sw;
            float ty = gy + h;
            uint8_t r  = 40  + (b.seed & 0x1F);
            uint8_t g  = 140 + (b.seed & 0x3F);
            uint8_t bl = 40  + (b.seed & 0x1F);
            outVerts[verts++] = { wx-w, gy, wz, 0.0f, 0.0f, r, g, bl, 255 };
            outVerts[verts++] = { wx+w, gy, wz, 1.0f, 0.0f, r, g, bl, 255 };
            outVerts[verts++] = { tx,   ty, wz, 0.5f, 1.0f, r, g, bl, 255 };
        }
    }
    return verts / 3;
}
