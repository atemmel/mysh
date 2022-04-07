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
		Integer,
	};
	union {
		StringView string;
		bool boolean;
		int64_t integer;
	};
	Kind kind;
	size_t ownerIndex = OwnerLess;

	auto toString() const -> String;
	auto free(SymTable& owner) -> void;
};

auto fprintType(FILE* desc, const Value& value) -> void;

struct SymTable {
	friend struct Value;

	auto addScope() -> void;
	auto dropScope() -> void;

	auto putVariable(StringView identifier, const Value& value) -> void;
	auto getVariable(StringView identifier) -> Value*;

	auto create(const String& string) -> Value;
	auto create(String&& string) -> Value;

	auto dump() const -> void;
private:
	struct VariableInfo {
		Value* value;
		size_t scope;
	};
	auto putVariable(size_t scope, StringView identifier, const Value& value) -> void;
	auto getVariableInfo(StringView identifier) -> VariableInfo;
	auto createValue(const Value& value) -> Value;
	auto createValue(StringView value) -> Value;
	auto createValue(bool value) -> Value;
	auto createValue(int64_t value) -> Value;

	auto createString(StringView string) -> size_t;
	auto createString(String&& string) -> size_t;
	auto freeString(const Value* variable) -> void;

	using Variables = HashTable<StringView, Value>;
	using Scopes = Array<Variables>;

	Array<String> strings;
	Array<size_t> freeStrings;
	Scopes scopes;
};
