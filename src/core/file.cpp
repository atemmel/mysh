#include "core/file.hpp"

#include <stdio.h>

namespace file {
auto readAll(StringView path) -> String {
	auto handle = fopen(path.data(), "r");
	if(handle == nullptr) {
		return "";
	}
	fseek(handle, 0, SEEK_END);
	size_t size = ftell(handle);
	String buffer(size, ' ');
	fseek(handle, 0, SEEK_SET);
	fread(buffer.data(), sizeof(char), buffer.size(), handle);
	fclose(handle);
	return buffer;
}

auto writeAll(StringView path, StringView contents) -> bool {
	auto handle = fopen(path.data(), "w");
	if(handle == nullptr) {
		return false;
	}
	fwrite(contents.data(), sizeof(char), contents.size(), handle);
	fclose(handle);
	return true;
}

};
