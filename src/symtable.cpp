#include "symtable.hpp"

#include "core/print.hpp"

#include <stdlib.h>

auto Value::toString() const -> String {
	switch(kind) {
		case Kind::String:
			return string;
		case Kind::Bool:
			return boolean ?
				"true" : "false";
		case Kind::Integer:
			String buffer(21, '\0');
			//TODO: Look for the appropriate function
			sprintf(buffer.data(), "%ld", integer);
			return buffer;
	}
	assert(false);
	return "";
}

Value::Value() : Value(false) {

}

Value::Value(StringView other) 
	: kind(Value::Kind::String) {
	new (&string) String(other);
}

Value::Value(String&& other) 
	: kind(Value::Kind::String) {
	new (&string) String(::move(other));
}

Value::Value(bool other) 
	: kind(Value::Kind::Bool), boolean(other) {
}

Value::Value(int64_t other) 
	: kind(Value::Kind::Integer), integer(other) {

}

Value::Value(const Value& other) {
	copy(other);
}

Value::Value(Value&& other) {
	move(::move(other));
}

Value::~Value() {
	free();
}


auto Value::operator=(const Value& other) -> void {
	if(this == &other) {
		return;
	}
	free();
	copy(other);
}

auto Value::operator=(Value&& other) -> void {
	free();
	move(::move(other));
}

auto Value::copy(const Value& other) -> void {
	kind = other.kind;
	switch(kind) {
		case Kind::Bool:
			boolean = other.boolean;
			break;
		case Kind::Integer:
			integer = other.integer;
			break;
		case Kind::String:
			new (&string) String(other.string);
			break;
	}
}

auto Value::move(Value&& other) -> void {
	kind = other.kind;
	switch(kind) {
		case Kind::Bool:
			boolean = other.boolean;
			break;
		case Kind::Integer:
			integer = other.integer;
			break;
		case Kind::String:
			new (&string) String(::move(other.string));
			break;
	}
}

auto Value::free() -> void {
	switch(kind) {
		case Kind::String:
			string.~String();
			break;
		// no peculiar freeing policy
		case Kind::Bool:
		case Kind::Integer:
			break;
	}
}

auto fprintType(FILE* desc, const Value& value) -> void {
	switch(value.kind) {
		case Value::Kind::String:
			fprintType(desc, value.string);
			break;
		case Value::Kind::Bool:
			fprintType(desc, value.boolean);
			break;
		case Value::Kind::Integer:
			fprintType(desc, value.integer);
			break;
		default:
			assert(false);
	}
}

auto SymTable::addScope() -> void {
	scopes.append({});
}

auto SymTable::dropScope() -> void {
	assert(!scopes.empty());
	auto& lastScopeVars = scopes[scopes.size() - 1];
	lastScopeVars.clear();
	scopes.pop();
}

auto SymTable::putVariable(StringView identifier, const Value& value) -> void {

	auto newValue = createValue(value);

	size_t scopeIndex;
	// remove prior value (if applicable)
	auto prev = getVariableInfo(identifier);
	if(prev.value != nullptr) {
		scopeIndex = prev.scope;
	} else {
		scopeIndex = scopes.size() - 1;
	}

	auto& scope = scopes[scopeIndex];
	scope.put(identifier, newValue);
}

auto SymTable::createValue(const Value& value) -> Value {
	switch(value.kind) {
		case Value::Kind::String:
			return createValue(value.string);
		case Value::Kind::Bool:
			return createValue(value.boolean);
		case Value::Kind::Integer:
			return createValue(value.integer);
	}
	assert(false);
	return {};
}

auto SymTable::createValue(StringView value) -> Value {
	return Value(value);
}

auto SymTable::createValue(bool value) -> Value {
	return Value(value);
}

auto SymTable::createValue(int64_t value) -> Value {
	return Value(value);
}

auto SymTable::getVariable(StringView identifier) -> Value* {
	for(auto& scope : scopes) {
		auto var = scope.get(identifier);
		if(var != nullptr) {
			return var;
		}
	}
	return nullptr;
}

auto SymTable::create(const String& string) -> Value {
	return createValue(string);
}

auto SymTable::create(String&& string) -> Value {
	return Value(move(string));
}

auto SymTable::createConverted(String&& string) -> Value {
	if(string == "true") {
		return Value(true);
	}

	if(string == "false") {
		return Value(false);
	}

	//TODO: proper conversion error handling
	char* strEnd = nullptr;
	auto value = strtol(string.data(), &strEnd, 10);

	if(*strEnd == '\0') {
		return Value(value);
	}

	// unconvertable, remain as a string
	return create(string);
}

auto SymTable::dump() const -> void {
	for(const auto& scope : scopes) {
		for(auto it = scope.begin();
			it != scope.end(); it++) {
			println(it->key, "=", it->value);
		}
	}
}

auto SymTable::putVariable(size_t scope, StringView identifier, const Value& value) -> void {
	assert(scope < scopes.size());
	auto newValue = createValue(value);
	auto& theScope = scopes[scope];
	theScope.put(identifier, newValue);
}

auto SymTable::getVariableInfo(StringView identifier) -> VariableInfo {
	for(size_t i = 0; i < scopes.size(); ++i) {
		auto& scope = scopes[i];
		auto var = scope.get(identifier);
		if(var != nullptr) {
			return {
				var,
				i,
			};
		}
	}
	return {
		nullptr,
		0,
	};
}
