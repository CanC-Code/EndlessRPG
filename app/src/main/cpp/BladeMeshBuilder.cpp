#include "BladeMeshBuilder.h"
#include <cmath>

// Matches the terrain vertex shader so blades sit on the surface.
static float terrain_height(float x, float z) {
    return 2.5f * sinf(x * 0.2f) * cosf(z * 0.2f);
}

// 5 segments -> 6 rings -> 12 verts -> 10 tris per blade.
static const int SEGMENTS = 5;

// Emit one blade into outVerts starting at index *vi.
// Returns number of vertices written.
static int emit_blade(const Blade& b, float tileOriginX, float tileOriginZ,
                      float tileSize, float windTime,
                      BladeVertex* outVerts, int* vi)
{
    const float T = tileSize;
    float wx = tileOriginX + (b.localX / 255.0f) * T;
    float wz = tileOriginZ + (b.localZ / 255.0f) * T;
    float gy = terrain_height(wx, wz);

    float h = b.currentHeight;
    if (h < 0.01f) return 0;

    // ---------- per-blade variation ----------------------------------
    // Each blade gets a slightly different hue. Grass is never uniform.
    // base: darker, cooler green
    // tip:  warmer, yellower green
    uint8_t s = b.seed;
    float hueShift = ((s & 0x1F) - 16) * 0.006f;   // ±0.10 tint
    float dry      = ((s >> 5) & 0x07) * 0.03f;    // some blades drier

    // base color (dark green, slightly blue), tip color (yellow-green)
    float br = 0.10f + 0.05f * ((s >> 0) & 0x03);  // 0.10 .. 0.25
    float bg = 0.28f + 0.06f * ((s >> 2) & 0x03);  // 0.28 .. 0.46
    float bb = 0.08f + 0.03f * ((s >> 4) & 0x03);  // 0.08 .. 0.17
    float tr = 0.42f + 0.10f * ((s >> 1) & 0x03) + dry;  // 0.42 .. 0.70
    float tg = 0.62f + 0.10f * ((s >> 3) & 0x03) + dry;  // 0.62 .. 0.90
    float tb = 0.18f + 0.06f * ((s >> 5) & 0x03);        // 0.18 .. 0.36
    br += hueShift * 0.5f; bg -= hueShift; bb += hueShift;

    // ---------- wind -------------------------------------------------
    // Base sway: low frequency, all blades in the area move together.
    // Turbulence: high frequency, per-blade phase — this is what makes
    // grass look alive rather than a rigid grid.
    float ph = (s / 255.0f) * 6.2831853f;
    float baseSway = sinf(windTime * 0.7f) * 0.15f;
    float turb = sinf(windTime * 2.3f + ph) * 0.35f
               + sinf(windTime * 3.7f + ph * 2.1f) * 0.20f;
    // wind strength scales with blade height — tall blades wave more
    float windAmp = (baseSway + turb) * h * h;

    // static lean from seed: some blades lean left, some right
    float lean = ((s & 0x0F) - 7.5f) * 0.02f;      // ±0.15 m at tip

    // ---------- generate rings --------------------------------------
    // A "ring" is the pair of verts at one height level along the blade.
    // Ring 0 is at ground level, ring SEGMENTS at the tip.
    int vi_start = *vi;

    for (int seg = 0; seg <= SEGMENTS; ++seg) {
        float t = (float)seg / (float)SEGMENTS;   // 0..1
        float y = gy + h * t;

        // Taper: blade narrows toward tip. The (1 - 0.85*t^1.7) curve
        // keeps the blade wide at the base and pinches it fast near top —
        // that's what real grass looks like.
        float taper = 1.0f - 0.85f * powf(t, 1.7f);
        float halfW = b.width * 0.5f * taper;
        if (halfW < 0.0006f) halfW = 0.0006f;   // never truly zero

        // Bend: quadratic along the blade so the tip moves 4x the middle
        // and the base stays anchored in the ground.
        float bend = (b.bend + lean) * t * t + windAmp * t * t;

        float cx = wx + bend;   // blade center X at this height
        float cz = wz;          // no bend in Z for now

        // Color for this ring — linear interp base -> tip
        float r = br + (tr - br) * t;
        float g = bg + (tg - bg) * t;
        float bb2 = bb + (tb - bb) * t;
        uint8_t cr = (uint8_t)(r * 255.0f);
        uint8_t cg = (uint8_t)(g * 255.0f);
        uint8_t cb = (uint8_t)(bb2 * 255.0f);

        // Two verts, offset along X by halfW (blade faces +Z / -Z)
        outVerts[*vi] = { cx - halfW, y, cz, 0.0f, t, cr, cg, cb, 255 };
        (*vi)++;
        outVerts[*vi] = { cx + halfW, y, cz, 1.0f, t, cr, cg, cb, 255 };
        (*vi)++;
    }

    return (*vi) - vi_start;
}

int build_frame_grass(const std::vector<GrassTile>& tiles,
                      const CameraView& cam,
                      float windTime,
                      BladeVertex* outVerts,
                      int maxVerts) {
    int vi = 0;
    const float R2 = 900.0f;   // cull radius^2 (30m)
    const float T = 4.0f;      // must match GrassSim tileSize

    for (const auto& tile : tiles) {
        // cull whole tile by distance from camera
        float tileCenterX = tile.worldX + T * 0.5f;
        float tileCenterZ = tile.worldZ + T * 0.5f;
        float dx = tileCenterX - cam.x;
        float dz = tileCenterZ - cam.z;
        if (dx * dx + dz * dz > R2) continue;

        for (const auto& b : tile.blades) {
            // 12 verts per blade; check we have room
            if (vi + 2 * (SEGMENTS + 1) > maxVerts) {
                return vi / 3;
            }
            emit_blade(b, tile.worldX, tile.worldZ, T, windTime,
                       outVerts, &vi);
        }
    }
    return vi / 3;
}
