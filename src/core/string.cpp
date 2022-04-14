#include "core/string.hpp"

#include "core/stringbuilder.hpp"
#include "core/stringview.hpp"

#include <ctype.h>

String::String() : buffer(0) {
}

String::String(const char* other) : String(other, ::size(other)) {

}

String::String(const char* other, size_t amount) : String() {
	if(amount > 0) {
		if(other[amount - 1] == '\0') {
			buffer = Buffer<char>(other, amount);
		} else {
			buffer = Buffer<char>(amount + 1);
			mem::copy(other, other + amount, buffer.begin());
			*(end()) = '\0';
		}
	}
}

String::String(size_t amount, char toFill) : buffer(amount) {
	mem::fill(buffer, toFill);
	buffer[size()] = '\0';
}

String::String(StringView other) : String(other.data(), other.size()) {
}

String::String(StringBuilder&& other) : buffer(other.buffer) {
	buffer.crop(other.used);
	other.used = 0;
}

auto String::size() const -> size_t {
	return empty() ? 0 : buffer.size() - 1;
}

auto String::empty() const -> bool {
	return buffer.size() < 1;
}

auto String::find(char delimeter) const -> size_t {
	size_t index = 0;
	for(; index < size(); index++) {
		if(buffer[index] == delimeter) {
			return index;
		}
	}
	return -1;
}

auto String::operator[](size_t index) -> char& {
	return buffer[index];
}

auto String::operator[](size_t index) const -> const char& {
	return buffer[index];
}

auto String::data() -> char* {
	return buffer.data();
}

auto String::data() const -> const char* {
	return buffer.data();
}

auto String::begin() -> char* {
	return buffer.begin();
}

auto String::end() -> char* {
	return buffer.end() - 1;
}

auto String::begin() const -> const char* {
	return buffer.begin();
}

auto String::end() const -> const char* {
	return buffer.end() - 1;
}

auto String::view() const -> StringView {
	return StringView(buffer.begin(), buffer.end());
}

auto String::view(size_t first, size_t last) const -> StringView {
	assert(first < size());
	assert(last <= size());
	return StringView(buffer.data() + first, buffer.data() + last);
}

auto String::cropRightWhitespace() -> void {
	while(!empty() && isspace(*(end() - 1))) {
		buffer.crop(buffer.size() - 1);
	}
	if(!empty()) {
		*(end()) = '\0';
	}
}

auto operator==(const String& lhs, const String& rhs) -> bool {
	if(lhs.size() != rhs.size()) {
		return false;
	}
	return stringeq(lhs.data(), rhs.data());
}

auto operator==(const String& lhs, const char* rhs) -> bool {
	return stringeq(lhs.data(), rhs);
}

auto operator==(const char* lhs, const String& rhs) -> bool {
	return stringeq(lhs, rhs.data());
}

auto fprintType(FILE* desc, const String& value) -> void {
	if(value.data() != nullptr) {
		printf("'%s'\n", value.data());
		fprintf(desc, "%s", value.data());
	}
}
