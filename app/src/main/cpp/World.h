#pragma once
#include <string>
#include <vector>
#include <map>
#include <android/asset_manager.h>
#include "BladeMeshBuilder.h"

struct EntityType {
    std::string id;
    std::string display;
    std::string mesh;       // "box" for now
    float sx = 1.0f, sy = 1.0f, sz = 1.0f;
    float r = 1.0f, g = 1.0f, b = 1.0f;
    bool solid = true;
    std::string interact;   // "none" | "open_container" | "gather" | "mine"
    std::string loot;       // loot table id
};

struct EntityInstance {
    const EntityType* type = nullptr;
    float x = 0, y = 0, z = 0, yaw = 0;
};

class World {
public:
    void load(AAssetManager* am);
    void spawn_test_set();
    void draw(std::vector<BladeVertex>& out);

    size_t typeCount() const { return registry_.size(); }
    size_t instanceCount() const { return instances_.size(); }

    const std::map<std::string, EntityType>& registry() const { return registry_; }
    const std::vector<EntityInstance>& instances() const { return instances_; }

private:
    std::map<std::string, EntityType> registry_;
    std::vector<EntityInstance> instances_;
};
