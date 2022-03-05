#pragma once

#include "core/array.hpp"
#include "core/string.hpp"
#include "core/stringview.hpp"

struct SymTable {
	auto putVariable(StringView identifier, StringView value) -> void;
	auto getVariable(StringView identifier) -> String*;
private:
	struct Variable {
		StringView identifier;
		//TODO: replace type later
		String value;
	};
	Array<Variable> variables;
};
