#pragma once

#include "core/assert.hpp"
#include "core/string.hpp"

struct StringView {
	constexpr StringView() = default;
	constexpr StringView(const char* src) 
		: beginPtr(src), endPtr(beginPtr + ::size(src)) {
	}

	StringView(const String& src);

	constexpr StringView(const char* first, const char* last) : beginPtr(first), endPtr(last) {

	}

	constexpr StringView(const char* ptr, size_t amount) : StringView(ptr, ptr + amount) {

	}

	constexpr auto equals(StringView other) const -> bool {
		if(other.size() != size()) {
			return false;
		}
		return mem::equal(other, *this);
	}

	constexpr auto find(char delimeter) const -> size_t {
		size_t index = 0;
		for(; index < size(); index++) {
			if(beginPtr[index] == delimeter) {
				return index;
			}
		}
		return -1;
	}

	constexpr auto size() const -> size_t {
		return endPtr - beginPtr;
	}

	constexpr auto empty() const -> bool {
		return size() == 0;
	}

	constexpr auto operator[](size_t index) -> char {
		assert(index < size());
		return beginPtr[index];
	}

	constexpr auto data() const -> const char* {
		return beginPtr;
	}

	constexpr auto begin() const -> const char* {
		return beginPtr;
	}

	constexpr auto end() const -> const char* {
		return endPtr;
	}

	auto view(size_t first, size_t last) const -> StringView {
		assert(first < size());
		assert(last <= size());
		return StringView(data() + first, data() + last);
	}

private:
	const char* beginPtr = nullptr;
	// points to one behind last element
	const char* endPtr = nullptr;
};

constexpr auto operator==(const StringView& lhs, const char* rhs) -> bool {
	return stringeq(lhs.data(), rhs);
}

constexpr auto operator==(const char* lhs, const StringView& rhs) -> bool {
	return stringeq(lhs, rhs.data());
}

auto operator==(const String& lhs, const StringView& rhs) -> bool;
auto operator==(const StringView& lhs, const String& rhs) -> bool;

constexpr auto operator==(const StringView& lhs, const StringView& rhs) -> bool {
	if(lhs.size() != rhs.size()) {
		return false;
	}
	return stringeq(lhs.data(), rhs.data());
}

auto fprintType(FILE* desc, StringView view) -> void;
