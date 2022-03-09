#pragma once

#include "core/string.hpp"
#include "core/stringview.hpp"

auto hash(const char* value) -> size_t;
auto hash(char* value) -> size_t;
auto hash(StringView value) -> size_t;
auto hash(const String& value) -> size_t;
auto hash(size_t value) -> size_t;
