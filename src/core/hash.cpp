#include "core/hash.hpp"

auto hash(const char* value) -> size_t {
	size_t hash = 5381;
	for(int c = *value; c; c = *value++) {
		hash = ((hash << 5) + hash) + c;
	}
	return hash;
}

auto hash(char* value) -> size_t {
	return hash(value);
}

auto hash(StringView value) -> size_t {
	size_t hash = 5381;
	for(int c = 0; c < value.size(); ++c) {
		hash = ((hash << 5) + hash) + c;
	}
	return hash;
}

auto hash(const String& value) -> size_t {
	return hash(value.data());
}

auto hash(size_t value) -> size_t {
	value = ((value >> 16) ^ value) * 0x45d9f3b;
    value = ((value >> 16) ^ value) * 0x45d9f3b;
    value = (value >> 16) ^ value;
    return value;
}
