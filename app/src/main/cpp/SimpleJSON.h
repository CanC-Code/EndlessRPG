#pragma once
#include <string>
#include <vector>
#include <map>
#include <memory>

namespace json {

class Value;
using ValuePtr = std::shared_ptr<Value>;

class Value {
public:
    enum class Type { Null, Bool, Number, String, Array, Object };

    Type type = Type::Null;
    bool boolVal = false;
    double numberVal = 0;
    std::string stringVal;
    std::vector<ValuePtr> arrayVal;
    std::map<std::string, ValuePtr> objectVal;

    bool isNull()   const { return type == Type::Null; }
    bool isBool()   const { return type == Type::Bool; }
    bool isNumber() const { return type == Type::Number; }
    bool isString() const { return type == Type::String; }
    bool isArray()  const { return type == Type::Array; }
    bool isObject() const { return type == Type::Object; }

    bool asBool()   const { return boolVal; }
    double asNumber() const { return numberVal; }
    float asFloat() const { return (float)numberVal; }
    int asInt()     const { return (int)numberVal; }
    const std::string& asString() const { return stringVal; }

    ValuePtr get(const std::string& key) const {
        auto it = objectVal.find(key);
        return it != objectVal.end() ? it->second : nullptr;
    }

    float getFloat(const std::string& key, float def = 0.0f) const {
        auto v = get(key);
        return (v && v->isNumber()) ? v->asFloat() : def;
    }
    int getInt(const std::string& key, int def = 0) const {
        auto v = get(key);
        return (v && v->isNumber()) ? v->asInt() : def;
    }
    std::string getString(const std::string& key, const std::string& def = "") const {
        auto v = get(key);
        return (v && v->isString()) ? v->asString() : def;
    }
    bool getBool(const std::string& key, bool def = false) const {
        auto v = get(key);
        return (v && v->isBool()) ? v->asBool() : def;
    }
};

ValuePtr parse(const std::string& text);
std::string error();

} // namespace json
