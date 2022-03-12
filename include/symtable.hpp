#pragma once

#include "core/hashtable.hpp"
#include "core/string.hpp"
#include "core/stringview.hpp"

struct SymTable;

struct Value {
	constexpr static auto OwnerLess = static_cast<size_t>(-1);
	enum struct Kind {
		String,
		Bool,
		Null,
	};
	union {
		StringView string;
		bool boolean;
	};
	Kind kind;
	size_t ownerIndex = OwnerLess;

	auto toString() const -> StringView;
	auto free(SymTable& owner) -> void;
};

auto fprintType(FILE* desc, const Value& value) -> void;

struct SymTable {
	friend struct Value;

	auto putVariable(StringView identifier, const Value& value) -> void;
	auto getVariable(StringView identifier) -> Value*;

	auto dump() const -> void;
private:
	auto createValue(const Value& value) -> Value;
	auto createValue(StringView value) -> Value;
	auto createValue(bool value) -> Value;

	auto createString(StringView string) -> size_t;
	auto freeString(const Value* variable) -> void;

	Array<String> strings;
	Array<size_t> freeStrings;
	HashTable<StringView, Value> variables;
};
