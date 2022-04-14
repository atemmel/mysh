#pragma once

#include "core/buffer.hpp"

#include <stdio.h>

struct StringView;
struct StringBuilder;

struct String {
	String();
	String(const char* other);
	String(const char* other, size_t amount);
	String(size_t amount, char toFill);
	String(StringView other);
	String(StringBuilder&& other);

	auto size() const -> size_t;
	auto empty() const -> bool;

	auto find(char delimeter) const -> size_t;

	auto operator[](size_t index) -> char&;
	auto operator[](size_t index) const -> const char&;

	auto data() -> char*;
	auto data() const -> const char*;
	auto begin() -> char*;
	auto end() -> char*;
	auto begin() const -> const char*;
	auto end() const -> const char*;

	auto view() const -> StringView;
	auto view(size_t first, size_t last) const -> StringView;

	auto cropRightWhitespace() -> void;

private:
	Buffer<char> buffer;
};

auto operator==(const String& lhs, const String& rhs) -> bool;
auto operator==(const String& lhs, const char* rhs) -> bool;
auto operator==(const char* lhs, const String& rhs) -> bool;

auto fprintType(FILE* desc, const String& value) -> void;

constexpr auto size(const char* ptr) -> size_t {
	size_t len = 0;
	while(ptr[len] != '\0') {
		++len;
	}
	return len;
}

constexpr auto stringeq(const char* lhs, const char* rhs) -> bool {
	if(lhs == nullptr && rhs == nullptr) {
		return true;
	}
	size_t i = 0;
	for(; lhs[i] != '\0' && rhs[i] != '\0'; i++) {
		if(lhs[i] != rhs[i]) {
			return false;
		}
	}
	return i == 0 ? lhs[i] == rhs[i]
		: lhs[i - 1] == rhs[i - 1];
}

constexpr auto stringeq(const char* lhsFirst, const char* lhsLast, const char* rhs) -> bool {
	size_t lhsLen = lhsLast - lhsFirst;
	if(lhsLen == 0 && (rhs == nullptr || rhs[0] == '\0')) {
		return true;
	}
	size_t i = 0;
	for(; i < lhsLen && rhs[i] != '\0'; ++i) {
		if(lhsFirst[i] != rhs[i]) {
			return false;
		}
	}

	return i == lhsLen;
}

constexpr auto stringeq(const char* lhsFirst, const char* lhsLast,
	const char* rhsFirst, const char* rhsLast) -> bool {
	if(lhsLast - lhsFirst != rhsLast - rhsFirst) {
		return false;
	}
	size_t len = lhsLast - lhsFirst;
	size_t i = 0;
	for(; i < len; i++) {
		if(lhsFirst[i] != rhsFirst[i]) {
			return false;
		}
	}
	return true;
}
