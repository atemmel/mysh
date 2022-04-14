#pragma once

#include "core/hashtable.hpp"
#include "core/optional.hpp"
#include "core/string.hpp"
#include "core/stringview.hpp"

struct SymTable;

struct Value {
	enum struct Kind {
		String,
		Bool,
		Integer,
	};
	union {
		String string;
		bool boolean;
		int64_t integer;
	};
	Kind kind;

	auto toString() const -> String;

	Value();
	explicit Value(StringView other);
	explicit Value(String&& other);
	explicit Value(bool other);
	explicit Value(int64_t other);
	Value(const Value& other);
	Value(Value&& other);
	~Value();

	auto operator=(const Value& other) -> void;
	auto operator=(Value&& other) -> void;

private:
	auto copy(const Value& other) -> void;
	auto move(Value&& other) -> void;
	auto free() -> void;
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

	auto createConverted(String&& string) -> Value;

	auto dump() const -> void;
private:
	using Variables = HashTable<StringView, Value>;
	using Scope = Variables;
	using Scopes = Array<Scope>;

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

	Scopes scopes;
};
