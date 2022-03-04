#include "core/string.hpp"

#include <string.h>

String::String() : buffer(0) {
}

String::String(const char* other) : String(other, strlen(other)) {

}

String::String(const char* other, size_t amount) : buffer(other, amount + 1) {

}

String::String(size_t amount, char toFill) : buffer(amount + 1) {
	mem::fill(buffer, toFill);
	buffer[size()] = '\0';
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
	return buffer.end();
}

auto String::begin() const -> const char* {
	return buffer.begin();
}

auto String::end() const -> const char* {
	return buffer.end();
}

auto String::view(size_t first, size_t last) const -> StringView {
	assert(first < size());
	assert(last <= size());
	return StringView(buffer.data() + first, buffer.data() + last);
}

auto fprintType(FILE* desc, const String& value) -> void {
	fprintf(desc, "%s", value.data());
}
