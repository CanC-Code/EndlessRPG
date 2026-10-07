#pragma once
#include <cstdint>
#include <vector>

struct Blade {
    uint8_t localX, localZ;   // position within owning tile, 0..255
    uint8_t seed;             // per-blade RNG for wind phase + color
    float   age;              // seconds since sprout
    float   growthTime;       // seconds from sprout to max height
    float   maxHeight;        // metres
    float   currentHeight;    // derived each tick
    float   width;            // base width in metres
    float   bend;             // static curvature bias, metres at tip
    float   health;           // 0..1, caps final height
};

struct GrassTile {
    int   tileX, tileZ;
    float worldX, worldZ;
    std::vector<Blade> blades;
};

class GrassSim {
public:
    GrassSim(uint64_t worldSeed, int tilesX, int tilesZ, float tileSize);

    void tick(float dt, float camX, float camZ, float activeRadius);

    const std::vector<GrassTile>& tiles() const { return tiles_; }
    int   tileCountX() const { return tilesX_; }
    int   tileCountZ() const { return tilesZ_; }
    float tileSize()  const { return tileSize_; }

private:
    void populate_tile(GrassTile& t);
    void tick_blade(Blade& b, float dt);

    uint64_t seed_;
    int      tilesX_, tilesZ_;
    float    tileSize_;
    std::vector<GrassTile> tiles_;
};

uint64_t hash64(uint64_t seed, int x, int z);
