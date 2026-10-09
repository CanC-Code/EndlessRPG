#include "BladeMeshBuilder.h"
#include <cmath>

static float terrain_height(float x, float z) {
    return 2.5f * sinf(x * 0.2f) * cosf(z * 0.2f);
}

static const int SEGMENTS = 5;   // 5 quads = 10 tris per blade

static int emit_blade(const Blade& b, float tileOriginX, float tileOriginZ,
                      float tileSize, float windTime,
                      BladeVertex* outVerts, int* vi)
{
    const float T = tileSize;
    float wx = tileOriginX + (b.localX / 255.0f) * T;
    float wz = tileOriginZ + (b.localZ / 255.0f) * T;
    float gy = terrain_height(wx, wz) + 0.005f;   // tiny lift, avoid z-fight

    float h = b.currentHeight;
    if (h < 0.005f) return 0;

    // ---------- per-blade wind ----------------------------------------
    float ph = (b.seed / 255.0f) * 6.2831853f;
    float baseSway = sinf(windTime * 0.7f) * 0.15f;
    float turb = sinf(windTime * 2.3f + ph) * 0.35f
               + sinf(windTime * 3.7f + ph * 2.1f) * 0.20f;
    float windAmp = (baseSway + turb) * h * h;
    float lean = ((b.seed & 0x0F) - 7.5f) * 0.02f;

    // ---------- color palette -----------------------------------------
    float hueShift = ((b.seed & 0x1F) - 16) * 0.006f;
    float dry = ((b.seed >> 5) & 0x07) * 0.03f;

    // ---------- precompute ring geometry ------------------------------
    const int RINGS = SEGMENTS + 1;
    float ringCx[RINGS], ringY[RINGS], ringHalfW[RINGS];
    uint8_t ringR[RINGS], ringG[RINGS], ringB[RINGS];

    for (int seg = 0; seg < RINGS; ++seg) {
        float t = (float)seg / (float)SEGMENTS;

        float taper = 1.0f - 0.85f * powf(t, 1.7f);
        ringHalfW[seg] = fmaxf(b.width * 0.5f * taper, 0.0006f);

        float bend = (b.bend + lean) * t * t + windAmp * t * t;
        ringCx[seg] = wx + bend;
        ringY[seg]  = gy + h * t;

        float r, g, bl;
        if (t < 0.25f) {
            // sheath: brown-green at base
            float u = t / 0.25f;
            r  = 0.14f + 0.08f * u;
            g  = 0.19f + 0.13f * u;
            bl = 0.07f + 0.04f * u;
        } else {
            // blade: dark green at base of leaf, yellow-green at tip
            float u = (t - 0.25f) / 0.75f;
            r  = 0.22f + 0.36f * u + dry + hueShift * 0.5f;
            g  = 0.42f + 0.30f * u + dry;
            bl = 0.15f + 0.15f * u + hueShift;
        }
        ringR[seg] = (uint8_t)(fminf(fmaxf(r,  0.0f), 1.0f) * 255.0f);
        ringG[seg] = (uint8_t)(fminf(fmaxf(g,  0.0f), 1.0f) * 255.0f);
        ringB[seg] = (uint8_t)(fminf(fmaxf(bl, 0.0f), 1.0f) * 255.0f);
    }

    // ---------- emit triangles between consecutive rings --------------
    int vi_start = *vi;
    for (int seg = 0; seg < SEGMENTS; ++seg) {
        float y0  = ringY[seg],     y1  = ringY[seg+1];
        float cx0 = ringCx[seg],    cx1 = ringCx[seg+1];
        float hw0 = ringHalfW[seg], hw1 = ringHalfW[seg+1];
        uint8_t r0 = ringR[seg], g0 = ringG[seg], b0 = ringB[seg];
        uint8_t r1 = ringR[seg+1], g1 = ringG[seg+1], b1 = ringB[seg+1];
        float t0 = (float)seg / (float)SEGMENTS;
        float t1 = (float)(seg+1) / (float)SEGMENTS;

        // Triangle 1: bottom-left, bottom-right, top-right
        outVerts[*vi] = { cx0-hw0, y0, wz, 0.0f, t0, r0, g0, b0, 255 }; (*vi)++;
        outVerts[*vi] = { cx0+hw0, y0, wz, 1.0f, t0, r0, g0, b0, 255 }; (*vi)++;
        outVerts[*vi] = { cx1+hw1, y1, wz, 1.0f, t1, r1, g1, b1, 255 }; (*vi)++;
        // Triangle 2: bottom-left, top-right, top-left
        outVerts[*vi] = { cx0-hw0, y0, wz, 0.0f, t0, r0, g0, b0, 255 }; (*vi)++;
        outVerts[*vi] = { cx1+hw1, y1, wz, 1.0f, t1, r1, g1, b1, 255 }; (*vi)++;
        outVerts[*vi] = { cx1-hw1, y1, wz, 0.0f, t1, r1, g1, b1, 255 }; (*vi)++;
    }
    return (*vi) - vi_start;
}

int build_frame_grass(const std::vector<GrassTile>& tiles,
                      const CameraView& cam,
                      float windTime,
                      BladeVertex* outVerts,
                      int maxVerts) {
    int vi = 0;
    const float R2 = 900.0f;   // 30 m cull radius squared
    const float T  = 4.0f;     // must match GrassSim tileSize

    for (const auto& tile : tiles) {
        float tcx = tile.worldX + T * 0.5f;
        float tcz = tile.worldZ + T * 0.5f;
        float dx = tcx - cam.x, dz = tcz - cam.z;
        if (dx*dx + dz*dz > R2) continue;

        for (const auto& b : tile.blades) {
            // 30 verts per blade (5 segments × 6 verts per quad)
            if (vi + 30 > maxVerts) return vi / 3;
            emit_blade(b, tile.worldX, tile.worldZ, T, windTime, outVerts, &vi);
        }
    }
    return vi / 3;
}
