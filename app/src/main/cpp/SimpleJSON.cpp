#include "SimpleJSON.h"
#include <cctype>
#include <cstdlib>
#include <sstream>

namespace json {

static std::string g_error;

std::string error() { return g_error; }

namespace {

struct Parser {
    const std::string& s;
    size_t i = 0;

    explicit Parser(const std::string& str) : s(str) {}

    void skip_ws() {
        while (i < s.size()) {
            char c = s[i];
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') { ++i; }
            else if (c == '/' && i + 1 < s.size() && s[i+1] == '/') {
                while (i < s.size() && s[i] != '\n') ++i;
            }
            else break;
        }
    }

    bool fail(const std::string& msg) {
        std::ostringstream os;
        os << msg << " at offset " << i;
        g_error = os.str();
        return false;
    }

    ValuePtr parse_value() {
        skip_ws();
        if (i >= s.size()) { fail("unexpected end"); return nullptr; }
        char c = s[i];
        if (c == '{') return parse_object();
        if (c == '[') return parse_array();
        if (c == '"') return parse_string();
        if (c == 't' || c == 'f') return parse_bool();
        if (c == 'n') return parse_null();
        if (c == '-' || (c >= '0' && c <= '9')) return parse_number();
        fail("unexpected character");
        return nullptr;
    }

    ValuePtr parse_object() {
        auto v = std::make_shared<Value>();
        v->type = Value::Type::Object;
        ++i; // {
        skip_ws();
        if (i < s.size() && s[i] == '}') { ++i; return v; }
        while (true) {
            skip_ws();
            auto key = parse_string();
            if (!key) return nullptr;
            skip_ws();
            if (i >= s.size() || s[i] != ':') { fail("expected ':'"); return nullptr; }
            ++i;
            auto val = parse_value();
            if (!val) return nullptr;
            v->objectVal[key->asString()] = val;
            skip_ws();
            if (i >= s.size()) { fail("unterminated object"); return nullptr; }
            if (s[i] == ',') { ++i; continue; }
            if (s[i] == '}') { ++i; return v; }
            fail("expected ',' or '}'");
            return nullptr;
        }
    }

    ValuePtr parse_array() {
        auto v = std::make_shared<Value>();
        v->type = Value::Type::Array;
        ++i; // [
        skip_ws();
        if (i < s.size() && s[i] == ']') { ++i; return v; }
        while (true) {
            auto val = parse_value();
            if (!val) return nullptr;
            v->arrayVal.push_back(val);
            skip_ws();
            if (i >= s.size()) { fail("unterminated array"); return nullptr; }
            if (s[i] == ',') { ++i; continue; }
            if (s[i] == ']') { ++i; return v; }
            fail("expected ',' or ']'");
            return nullptr;
        }
    }

    ValuePtr parse_string() {
        if (i >= s.size() || s[i] != '"') { fail("expected string"); return nullptr; }
        ++i;
        auto v = std::make_shared<Value>();
        v->type = Value::Type::String;
        std::string out;
        while (i < s.size() && s[i] != '"') {
            char c = s[i];
            if (c == '\\') {
                ++i;
                if (i >= s.size()) { fail("unterminated escape"); return nullptr; }
                char e = s[i];
                switch (e) {
                    case 'n': out.push_back('\n'); break;
                    case 't': out.push_back('\t'); break;
                    case 'r': out.push_back('\r'); break;
                    case '\\': out.push_back('\\'); break;
                    case '"': out.push_back('"'); break;
                    case '/': out.push_back('/'); break;
                    default: out.push_back(e); break;
                }
            } else {
                out.push_back(c);
            }
            ++i;
        }
        if (i >= s.size()) { fail("unterminated string"); return nullptr; }
        ++i; // closing quote
        v->stringVal = out;
        return v;
    }

    ValuePtr parse_bool() {
        auto v = std::make_shared<Value>();
        v->type = Value::Type::Bool;
        if (s.compare(i, 4, "true") == 0)  { v->boolVal = true;  i += 4; return v; }
        if (s.compare(i, 5, "false") == 0) { v->boolVal = false; i += 5; return v; }
        fail("invalid literal");
        return nullptr;
    }

    ValuePtr parse_null() {
        if (s.compare(i, 4, "null") == 0) {
            i += 4;
            auto v = std::make_shared<Value>();
            v->type = Value::Type::Null;
            return v;
        }
        fail("invalid literal");
        return nullptr;
    }

    ValuePtr parse_number() {
        size_t start = i;
        if (i < s.size() && s[i] == '-') ++i;
        while (i < s.size() && std::isdigit((unsigned char)s[i])) ++i;
        if (i < s.size() && s[i] == '.') {
            ++i;
            while (i < s.size() && std::isdigit((unsigned char)s[i])) ++i;
        }
        if (i < s.size() && (s[i] == 'e' || s[i] == 'E')) {
            ++i;
            if (i < s.size() && (s[i] == '+' || s[i] == '-')) ++i;
            while (i < s.size() && std::isdigit((unsigned char)s[i])) ++i;
        }
        auto v = std::make_shared<Value>();
        v->type = Value::Type::Number;
        v->numberVal = std::strtod(s.substr(start, i - start).c_str(), nullptr);
        return v;
    }
};

} // anonymous namespace

ValuePtr parse(const std::string& text) {
    g_error.clear();
    Parser p(text);
    auto v = p.parse_value();
    if (!v) return nullptr;
    p.skip_ws();
    if (p.i != text.size()) {
        p.fail("trailing characters after value");
        return nullptr;
    }
    return v;
}

} // namespace json
