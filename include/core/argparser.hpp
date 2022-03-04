#pragma once

#include "core/array.hpp"
#include "core/stringview.hpp"

struct ArgParser {
	ArgParser() = default;

	auto flag(bool* result, 
			StringView flagName, 
			StringView helpText) -> void;

	auto parse(int argc, char** argv) -> void;

	auto args() const -> const Array<StringView>&;
private:
	
	auto handleFlag(const char* arg, size_t flagIndex) -> void;
	auto flagIndex(const char* arg) -> size_t;

	struct Flag {
		enum struct Type {
			Boolean,
		};
		Type type;
		void* ptr;
		StringView flagName;
		StringView helpText;
	};

	Array<Flag> flags;
	Array<StringView> otherArgs;
};
