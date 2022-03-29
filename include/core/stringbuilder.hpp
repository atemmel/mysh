#pragma once

#include "core/buffer.hpp"
#include "core/staticarray.hpp"
#include "core/string.hpp"
#include "core/stringview.hpp"

struct StringBuilder {
	friend struct String;

	StringBuilder();

	auto reserve(size_t thisMuch) -> void;

	auto append(StringView value) -> StringBuilder&;
	auto append(const String& value) -> StringBuilder&;
	auto append(int value) -> StringBuilder&;
	auto append(int64_t value) -> StringBuilder&;
	auto append(double value) -> StringBuilder&;
	auto append(size_t value) -> StringBuilder&;
	auto append(bool value) -> StringBuilder&;

	auto view() const -> StringView;
	auto copy() const -> String;

private:
	auto growIfLessThan(size_t that) -> void;
	auto appendBytes(const char* data, size_t len) -> void;

	static thread_local StaticArray<char, 16> miniBuffer;
	Buffer<char> buffer;
	size_t used = 0;
};
