#include "BladeMeshBuilder.h"
#include <cmath>

static float terrain_height(float x, float z) {
    return 2.5f * sinf(x * 0.2f) * cosf(z * 0.2f);
}

// segments by distance from camera (metres)
static int lod_segments(float dist2) {
    if (dist2 < 100.0f)  return 5;   // <10m
    if (dist2 < 400.0f)  return 2;   // <20m
    return 1;                         // 20-30m
}

// emit one blade with variable segment count.
// returns verts written (always 6*segments).
static int emit_blade_seg(const Blade& b, float tileOriginX, float tileOriginZ,
                          float tileSize, float windTime, int SEGMENTS,
                          BladeVertex* outVerts, int* vi)
{
    const float T = tileSize;
    float wx = tileOriginX + (b.localX / 255.0f) * T;
    float wz = tileOriginZ + (b.localZ / 255.0f) * T;
    float gy = terrain_height(wx, wz) + 0.005f;

    float h = b.currentHeight;
    if (h < 0.005f) return 0;

    // wind
    float ph = (b.seed / 255.0f) * 6.2831853f;
    float baseSway = sinf(windTime * 0.7f) * 0.15f;
    float turb = sinf(windTime * 2.3f + ph) * 0.35f
               + sinf(windTime * 3.7f + ph * 2.1f) * 0.20f;
    float windAmp = (baseSway + turb) * h * h;
    float lean = ((b.seed & 0x0F) - 7.5f) * 0.02f;

    // color
    float hueShift = ((b.seed & 0x1F) - 16) * 0.006f;
    float dry = ((b.seed >> 5) & 0x07) * 0.03f;

    const int RINGS = SEGMENTS + 1;
    float ringCx[16], ringY[16], ringHalfW[16];
    uint8_t ringR[16], ringG[16], ringB[16];

    for (int seg = 0; seg < RINGS; ++seg) {
        float t = (float)seg / (float)SEGMENTS;
        float taper = 1.0f - 0.85f * powf(t, 1.7f);
        ringHalfW[seg] = fmaxf(b.width * 0.5f * taper, 0.0006f);
        float bend = (b.bend + lean) * t * t + windAmp * t * t;
        ringCx[seg] = wx + bend;
        ringY[seg]  = gy + h * t;

        float r, g, bl;
        if (t < 0.25f) {
            float u = t / 0.25f;
            r  = 0.14f + 0.08f * u;
            g  = 0.19f + 0.13f * u;
            bl = 0.07f + 0.04f * u;
        } else {
            float u = (t - 0.25f) / 0.75f;
            r  = 0.22f + 0.36f * u + dry + hueShift * 0.5f;
            g  = 0.42f + 0.30f * u + dry;
            bl = 0.15f + 0.15f * u + hueShift;
        }
        ringR[seg] = (uint8_t)(fminf(fmaxf(r,  0.0f), 1.0f) * 255.0f);
        ringG[seg] = (uint8_t)(fminf(fmaxf(g,  0.0f), 1.0f) * 255.0f);
        ringB[seg] = (uint8_t)(fminf(fmaxf(bl, 0.0f), 1.0f) * 255.0f);
    }

    int vi_start = *vi;
    for (int seg = 0; seg < SEGMENTS; ++seg) {
        float y0  = ringY[seg],     y1  = ringY[seg+1];
        float cx0 = ringCx[seg],    cx1 = ringCx[seg+1];
        float hw0 = ringHalfW[seg], hw1 = ringHalfW[seg+1];
        uint8_t r0 = ringR[seg], g0 = ringG[seg], b0 = ringB[seg];
        uint8_t r1 = ringR[seg+1], g1 = ringG[seg+1], b1 = ringB[seg+1];
        float t0 = (float)seg / (float)SEGMENTS;
        float t1 = (float)(seg+1) / (float)SEGMENTS;

        outVerts[*vi] = { cx0-hw0, y0, wz, 0.0f, t0, r0, g0, b0, 255 }; (*vi)++;
        outVerts[*vi] = { cx0+hw0, y0, wz, 1.0f, t0, r0, g0, b0, 255 }; (*vi)++;
        outVerts[*vi] = { cx1+hw1, y1, wz, 1.0f, t1, r1, g1, b1, 255 }; (*vi)++;
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
    const float T = 4.0f;

    for (const auto& tile : tiles) {
        // tile center for coarse cull
        float tcx = tile.worldX + T * 0.5f;
        float tcz = tile.worldZ + T * 0.5f;
        float tdx = tcx - cam.x, tdz = tcz - cam.z;
        if (tdx*tdx + tdz*tdz > 900.0f) continue;   // 30m cull

        for (const auto& b : tile.blades) {
            float wx = tile.worldX + (b.localX / 255.0f) * T;
            float wz = tile.worldZ + (b.localZ / 255.0f) * T;
            float dx = wx - cam.x, dz = wz - cam.z;
            float d2 = dx*dx + dz*dz;
            int segs = lod_segments(d2);
            int need = segs * 6;
            if (vi + need > maxVerts) return vi / 3;
            emit_blade_seg(b, tile.worldX, tile.worldZ, T, windTime,
                           segs, outVerts, &vi);
        }
    }
    return vi / 3;
}
