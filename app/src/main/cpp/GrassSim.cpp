#include "GrassSim.h"

// splitmix64-style mixing — deterministic across compilers/platforms
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
            t.worldX = tx * tileSize_;
            t.worldZ = tz * tileSize_;
            populate_tile(t);
        }
    }
}

void GrassSim::populate_tile(GrassTile& t) {
    // Skeleton — population logic lands in commit 3.
    t.blades.clear();
}

void GrassSim::tick(float dt, float camX, float camZ, float activeRadius) {
    // Skeleton — simulation lands in commit 5.
    (void)dt; (void)camX; (void)camZ; (void)activeRadius;
}

void GrassSim::tick_blade(Blade& b, float dt) {
    (void)b; (void)dt;
}
