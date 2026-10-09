#include "GrassSim.h"

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
    : seed_(worldSeed), tilesX_(tilesX), tilesZ_(tilesZ), tileSize_(tileSize)
{
    tiles_.resize((size_t)tilesX_ * tilesZ_);
    for (int tz = 0; tz < tilesZ_; ++tz) {
        for (int tx = 0; tx < tilesX_; ++tx) {
            GrassTile& t = tiles_[(size_t)tz * tilesX_ + tx];
            t.tileX  = tx;
            t.tileZ  = tz;
            t.worldX = (tx - tilesX_ * 0.5f) * tileSize_;
            t.worldZ = (tz - tilesZ_ * 0.5f) * tileSize_;
            populate_tile(t);
        }
    }
}

void GrassSim::populate_tile(GrassTile& t) {
    uint64_t h = hash64(seed_, t.tileX, t.tileZ);
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
    (void)dt; (void)camX; (void)camZ; (void)activeRadius;
}

void GrassSim::tick_blade(Blade& b, float dt) {
    (void)b; (void)dt;
}
