#include "World.h"
#include "SimpleJSON.h"
#include <android/log.h>
#include <cmath>

#define LOG_TAG "World"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static std::string read_asset(AAssetManager* am, const std::string& path) {
    AAsset* a = AAssetManager_open(am, path.c_str(), AASSET_MODE_BUFFER);
    if (!a) return "";
    off_t n = AAsset_getLength(a);
    std::string s(n, '\0');
    AAsset_read(a, &s[0], n);
    AAsset_close(a);
    return s;
}

static float terrain_h(float x, float z) {
    return 2.5f * sinf(x * 0.2f) * cosf(z * 0.2f);
}

void World::load(AAssetManager* am) {
    AAssetDir* dir = AAssetManager_openDir(am, "entities");
    if (!dir) {
        LOGE("entities dir not found");
        return;
    }
    const char* name;
    int loaded = 0;
    while ((name = AAssetDir_getNextFileName(dir)) != nullptr) {
        std::string fn = name;
        if (fn.size() < 5 || fn.substr(fn.size() - 5) != ".json") continue;

        std::string text = read_asset(am, "entities/" + fn);
        if (text.empty()) continue;

        auto v = json::parse(text);
        if (!v) {
            LOGE("parse fail %s: %s", fn.c_str(), json::error().c_str());
            continue;
        }

        EntityType t;
        t.id      = v->getString("id");
        t.display = v->getString("display", t.id);
        t.mesh    = v->getString("mesh", "box");
        t.solid   = v->getBool("solid", true);
        t.interact = v->getString("interact", "none");
        t.loot    = v->getString("loot", "");

        if (auto sz = v->get("size"); sz && sz->isArray() && sz->arrayVal.size() >= 3) {
            t.sx = sz->arrayVal[0]->asFloat();
            t.sy = sz->arrayVal[1]->asFloat();
            t.sz = sz->arrayVal[2]->asFloat();
        }
        if (auto col = v->get("color"); col && col->isArray() && col->arrayVal.size() >= 3) {
            t.r = col->arrayVal[0]->asFloat();
            t.g = col->arrayVal[1]->asFloat();
            t.b = col->arrayVal[2]->asFloat();
        }

        if (!t.id.empty()) {
            registry_[t.id] = t;
            ++loaded;
        }
    }
    AAssetDir_close(dir);
    LOGE("World: loaded %d entity types", loaded);
}

static void spawn_at(World* w, const std::string& id,
                     const std::map<std::string, EntityType>& reg,
                     std::vector<EntityInstance>& out,
                     float x, float z) {
    auto it = reg.find(id);
    if (it == reg.end()) return;
    EntityInstance e;
    e.type = &it->second;
    e.x = x;
    e.z = z;
    e.y = terrain_h(x, z) + e.type->sy * 0.5f;
    e.yaw = 0;
    out.push_back(e);
}

void World::spawn_test_set() {
    // Place a few of each type near origin so we can see them.
    for (int i = 0; i < 3; ++i) {
        spawn_at(this, "chest_wooden", registry_, instances_,
                 (float)(i * 6 - 6), -8.0f);
    }
    for (int i = 0; i < 8; ++i) {
        spawn_at(this, "herb_common", registry_, instances_,
                 (float)((i * 37 % 40) - 20), (float)((i * 53 % 40) - 20));
    }
    for (int i = 0; i < 6; ++i) {
        spawn_at(this, "rock_mineral", registry_, instances_,
                 (float)((i * 41 % 50) - 25), (float)((i * 29 % 50) - 25));
    }
    // grow the instances_ vector — spawn_at takes it by reference, need to patch
}

void World::draw(std::vector<BladeVertex>& out) {
    // Each box: 12 triangles, 36 verts. Reuse BladeVertex format.
    for (const auto& inst : instances_) {
        if (!inst.type) continue;
        float hx = inst.type->sx * 0.5f;
        float hy = inst.type->sy * 0.5f;
        float hz = inst.type->sz * 0.5f;
        float x0 = inst.x - hx, x1 = inst.x + hx;
        float y0 = inst.y - hy, y1 = inst.y + hy;
        float z0 = inst.z - hz, z1 = inst.z + hz;
        uint8_t cr = (uint8_t)(inst.type->r * 255.0f);
        uint8_t cg = (uint8_t)(inst.type->g * 255.0f);
        uint8_t cb = (uint8_t)(inst.type->b * 255.0f);

        auto push = [&](float x, float y, float z) {
            out.push_back({ x, y, z, 0.5f, 1.0f, cr, cg, cb, 255 });
        };
        // 6 faces, 2 tris each, CCW
        // -Z
        push(x0,y0,z0); push(x1,y0,z0); push(x1,y1,z0);
        push(x0,y0,z0); push(x1,y1,z0); push(x0,y1,z0);
        // +Z
        push(x0,y0,z1); push(x0,y1,z1); push(x1,y1,z1);
        push(x0,y0,z1); push(x1,y1,z1); push(x1,y0,z1);
        // -X
        push(x0,y0,z0); push(x0,y1,z0); push(x0,y1,z1);
        push(x0,y0,z0); push(x0,y1,z1); push(x0,y0,z1);
        // +X
        push(x1,y0,z0); push(x1,y0,z1); push(x1,y1,z1);
        push(x1,y0,z0); push(x1,y1,z1); push(x1,y1,z0);
        // -Y
        push(x0,y0,z0); push(x0,y0,z1); push(x1,y0,z1);
        push(x0,y0,z0); push(x1,y0,z1); push(x1,y0,z0);
        // +Y
        push(x0,y1,z0); push(x1,y1,z0); push(x1,y1,z1);
        push(x0,y1,z0); push(x1,y1,z1); push(x0,y1,z1);
    }
}
