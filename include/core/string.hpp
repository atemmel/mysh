#pragma once

#include "core/buffer.hpp"

#include <stdio.h>

struct String {
	String();
	String(const char* other);
	String(const char* other, size_t amount);

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

private:
	Buffer<char> buffer;
};

auto fprintType(FILE* desc, const String& value) -> void;
