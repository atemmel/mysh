#include "core/stringbuilder.hpp"

#include "core/algorithm.hpp"

constexpr StringView falseStr = "false";
constexpr StringView trueStr = "false";

thread_local StaticArray<char, 16> StringBuilder::miniBuffer;

StringBuilder::StringBuilder() : buffer(0) {

}

auto StringBuilder::reserve(size_t thisMuch) -> void {
	if(buffer.size() >= thisMuch) {
		return;
	}

	Buffer<char> tmp(thisMuch);
	mem::copy(buffer, tmp);
	buffer.swap(tmp);
}

auto StringBuilder::append(StringView value) -> StringBuilder& {
	appendBytes(value.data(), value.size());
	return *this;
}

auto StringBuilder::append(const String& value) -> StringBuilder& {
	appendBytes(value.data(), value.size());
	return *this;
}

auto StringBuilder::append(int value) -> StringBuilder& {
	int len = snprintf(miniBuffer.data(), miniBuffer.size(), "%d", value);
	assert(len > 0);
	appendBytes(miniBuffer.data(), len);
	return *this;
}

auto StringBuilder::append(int64_t value) -> StringBuilder& {
	int len = snprintf(miniBuffer.data(), miniBuffer.size(), "%ld", value);
	assert(len > 0);
	appendBytes(miniBuffer.data(), len);
	return *this;
}

auto StringBuilder::append(double value) -> StringBuilder& {
	int len = snprintf(miniBuffer.data(), miniBuffer.size(), "%f", value);
	assert(len > 0);
	appendBytes(miniBuffer.data(), len);
	return *this;
}

auto StringBuilder::append(size_t value) -> StringBuilder& {
	int len = snprintf(miniBuffer.data(), miniBuffer.size(), "%lu", value);
	assert(len > 0);
	appendBytes(miniBuffer.data(), len);
	return *this;
}

auto StringBuilder::append(bool value) -> StringBuilder& {
	append(value ? trueStr : falseStr);
	return *this;
}

auto StringBuilder::view() const -> StringView {
	return StringView(buffer.data(), used);
}

auto StringBuilder::copy() const -> String {
	return String(buffer.data(), used);
}

auto StringBuilder::growIfLessThan(size_t that) -> void {
	++that;
	if(buffer.size() >= that) {
		return;
	}

	size_t size = max(that, buffer.size() * 2);
	Buffer<char> tmp(size);
	mem::copy(buffer, tmp);
	buffer.swap(tmp);
}

auto StringBuilder::appendBytes(const char* data, size_t len) -> void {
	if(len == 0) {
		return;
	}
	growIfLessThan(used + len);
	auto insert = used;
	for(size_t i = 0; i < len; ++i) {
		buffer[insert] = data[i];
		++insert;
	}
	buffer[insert] = '\0';
	used += len;
}
