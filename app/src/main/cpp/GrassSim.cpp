#include "GrassSim.h"
#include <cmath>

uint64_t hash64(uint64_t seed, int x, int z) {
    uint64_t h = seed;
    h ^= (uint64_t)(uint32_t)x * 0x9E3779B97F4A7C15ULL;
    h ^= (uint64_t)(uint32_t)z * 0xC2B2AE3D27D4EB4FULL;
    h ^= h >> 30; h *= 0xBF58476D1CE4E5B9ULL;
    h ^= h >> 27; h *= 0x94D049BB133111EBULL;
    h ^= h >> 31;
    return h;
}

GrassSim::GrassSim(uint64_t worldSeed, int tilesX, int tilesZ, float tileSize)
    : seed_(worldSeed), tilesX_(tilesX), tilesZ_(tilesZ), originX_(0), originZ_(0), tileSize_(tileSize)
{
    tiles_.resize((size_t)tilesX_ * tilesZ_);
    for (int tz = 0; tz < tilesZ_; ++tz) {
        for (int tx = 0; tx < tilesX_; ++tx) {
            GrassTile& t = tiles_[(size_t)tz * tilesX_ + tx];
            t.tileX  = tx - tilesX_ / 2;
            t.tileZ  = tz - tilesZ_ / 2;
            t.worldX = t.tileX * tileSize_;
            t.worldZ = t.tileZ * tileSize_;
            populate_tile(t);
        }
    }
    originX_ = -tilesX_ / 2;
    originZ_ = -tilesZ_ / 2;
}

void GrassSim::populate_tile(GrassTile& t) {
    uint64_t h = hash64(seed_, t.tileX, t.tileZ);  // tileX/Z are absolute world tile coords
    auto next_u32 = [&h]() -> uint32_t {
        h ^= h << 13; h ^= h >> 7; h ^= h << 17;
        return (uint32_t)(h >> 32);
    };
    auto next_float = [&next_u32]() -> float {
        return (next_u32() & 0xFFFFFF) / (float)0x1000000;
    };

    // 40 clumps per 4x4m tile = 2.5 clumps/m^2. Each clump 6-12 blades.
    const int NUM_CLUMPS = 40;
    t.blades.reserve(NUM_CLUMPS * 12);

    for (int c = 0; c < NUM_CLUMPS; ++c) {
        uint8_t cx = (uint8_t)(next_u32() & 0xFF);
        uint8_t cz = (uint8_t)(next_u32() & 0xFF);
        int bladeCount = 6 + (int)(next_u32() % 7);  // 6..12

        for (int i = 0; i < bladeCount; ++i) {
            Blade b;
            // tighter scatter: +/-5 in 0..255 coords = +/-8cm
            int dx = (int)(next_u32() % 11) - 5;
            int dz = (int)(next_u32() % 11) - 5;
            b.localX = (uint8_t)(((int)cx + dx) & 0xFF);
            b.localZ = (uint8_t)(((int)cz + dz) & 0xFF);
            b.seed = (uint8_t)(next_u32() & 0xFF);

            // height tiers: mostly short, some tall. Clump has mixed heights.
            int tier = (int)(next_u32() % 10);
            if (tier < 5) {
                b.maxHeight = 0.06f + next_float() * 0.07f;   // 6..13 cm
            } else if (tier < 9) {
                b.maxHeight = 0.13f + next_float() * 0.13f;   // 13..26 cm
            } else {
                b.maxHeight = 0.26f + next_float() * 0.22f;   // 26..48 cm
            }
            b.width = 0.007f + next_float() * 0.007f;
            b.bend = (next_float() - 0.5f) * 0.30f;
            b.growthTime = 3.0f + next_float() * 4.0f;
            b.age = next_float() * 15.0f;
            b.currentHeight = b.maxHeight;
            b.health = 1.0f;
            t.blades.push_back(b);
        }
    }
}

void GrassSim::tick(float dt, float camX, float camZ, float activeRadius) {
    (void)dt; (void)activeRadius;
    int px = (int)std::floor(camX / tileSize_);
    int pz = (int)std::floor(camZ / tileSize_);
    int wantX = px - tilesX_ / 2;
    int wantZ = pz - tilesZ_ / 2;
    if (wantX != originX_ || wantZ != originZ_) {
        set_origin(wantX, wantZ);
    }
}

void GrassSim::set_origin(int newX, int newZ) {
    originX_ = newX;
    originZ_ = newZ;
    for (int tz = 0; tz < tilesZ_; ++tz) {
        for (int tx = 0; tx < tilesX_; ++tx) {
            GrassTile& t = tiles_[(size_t)tz * tilesX_ + tx];
            int absX = originX_ + tx;
            int absZ = originZ_ + tz;
            if (t.tileX == absX && t.tileZ == absZ && !t.blades.empty()) continue;
            t.tileX  = absX;
            t.tileZ  = absZ;
            t.worldX = absX * tileSize_;
            t.worldZ = absZ * tileSize_;
            t.blades.clear();
            populate_tile(t);
        }
    }
}

void GrassSim::tick_blade(Blade& b, float dt) {
    (void)b; (void)dt;
}
