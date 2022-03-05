#pragma once

#include "core/array.hpp"
#include "core/stringview.hpp"

namespace globals {

auto init() -> void;

extern bool verbose;
extern Array<StringView> paths;

};
