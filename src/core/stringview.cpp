#include "core/stringview.hpp"

#include "core/assert.hpp"
#include "core/string.hpp"
#include "core/print.hpp"

StringView::StringView(const String& src) 
	: StringView(src.begin(), src.size()) {
}

auto operator==(const String& lhs, const StringView& rhs) -> bool {
	if(lhs.size() != rhs.size()) {
		return false;
	}
	return stringeq(lhs.data(), rhs.data());
}

auto operator==(const StringView& lhs, const String& rhs) -> bool {
	if(lhs.size() != rhs.size()) {
		return false;
	}
	return stringeq(lhs.data(), rhs.data());
}

auto fprintType(FILE* desc, StringView view) -> void {
	fprintf(desc, "%.*s", (int)view.size(), view.data());
}
