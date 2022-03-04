#include "core/stringview.hpp"

#include "core/assert.hpp"
#include "core/string.hpp"

#include <string.h>

StringView::StringView(const char* src) 
	: beginPtr(src), endPtr(beginPtr + strlen(src)) {

}
StringView::StringView(const String& src) 
	: StringView(src.begin(), src.end()) {

}
StringView::StringView(const char* first, const char* last) : beginPtr(first), endPtr(last) {

}

StringView::StringView(const char* ptr, size_t amount) : StringView(ptr, ptr + amount) {

}

auto StringView::find(char delimeter) const -> size_t {
	size_t index = 0;
	for(; index < size(); index++) {
		if(beginPtr[index] == delimeter) {
			return index;
		}
	}
	return -1;
}

auto StringView::size() const -> size_t {
	return endPtr - beginPtr;
}

auto StringView::empty() const -> bool {
	return size() == 0;
}

auto StringView::operator[](size_t index) -> char {
	assert(index < size());
	return beginPtr[index];
}

auto StringView::data() const -> const char* {
	return beginPtr;
}

auto StringView::begin() const -> const char* {
	return beginPtr;
}

auto StringView::end() const -> const char* {
	return endPtr;
}

auto fprintType(FILE* desc, StringView view) -> void {
	fprintf(desc, "%.*s", (int)view.size(), view.data());
}
