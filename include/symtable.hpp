#pragma once

#include "core/hashtable.hpp"
#include "core/string.hpp"
#include "core/stringview.hpp"

struct Variable {
	//TODO: replace type later
	String value;
};

struct SymTable {
	auto putVariable(StringView identifier, StringView value) -> void;
	auto getVariable(StringView identifier) -> Variable*;
private:
	HashTable<StringView, Variable> variables;
};
