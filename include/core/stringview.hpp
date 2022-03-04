#pragma once

#include <stdio.h>

struct String;

struct StringView {
	StringView() = default;
	StringView(const char* src);
	StringView(const String& src);
	StringView(const char* first, const char* last);
	StringView(const char* ptr, size_t amount);

	auto find(char delimeter) const -> size_t;
	auto size() const -> size_t;
	auto empty() const -> bool;
	auto operator[](size_t index) -> char;
	auto data() const -> const char*;
	auto begin() const -> const char*;
	auto end() const -> const char*;

private:
	const char* beginPtr = nullptr;
	// points to one behind last element
	const char* endPtr = nullptr;
};

auto fprintType(FILE* desc, StringView view) -> void;
