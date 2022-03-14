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

auto fprintType(FILE* desc, const Value& value) -> void {
	fprintType(desc, value.toString());
}

auto Value::free(SymTable& owner) -> void {
	// if has owner
	if(ownerIndex != Value::OwnerLess) {
		// notify owner
		switch(kind) {
			case Kind::String:
				owner.freeString(this);
				break;
			// no peculiar freeing policy
			case Kind::Bool:
			case Kind::Integer:
				break;
		}
	}
	// reset
	ownerIndex = Value::OwnerLess;
}

auto SymTable::addScope() -> void {
	scopes.append({});
}

auto SymTable::dropScope() -> void {
	assert(!scopes.empty());
	auto& lastScope = scopes[scopes.size() - 1];
	for(auto it = lastScope.begin(); it != lastScope.end(); ++it) {
		it->value.free(*this);
	}
	lastScope.clear();
	scopes.pop();
}

auto SymTable::putVariable(StringView identifier, const Value& value) -> void {

	auto newValue = createValue(value);

	// remove prior value (if applicable)
	auto prev = getVariable(identifier);
	if(prev != nullptr) {
		prev->free(*this);
	}

	auto& scope = scopes[scopes.size() - 1];
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
	auto index = createString(value);
	return Value{
		.string = strings[index],
		.kind = Value::Kind::String,
		.ownerIndex = index,
	};
}

auto SymTable::createValue(bool value) -> Value {
	return Value{
		.boolean = value,
		.kind = Value::Kind::Bool,
		.ownerIndex = Value::OwnerLess,
	};
}

auto SymTable::createValue(int64_t value) -> Value {
	return Value{
		.integer = value,
		.kind = Value::Kind::Integer,
		.ownerIndex = Value::OwnerLess,
	};
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

auto SymTable::dump() const -> void {
	for(const auto& scope : scopes) {
		for(auto it = scope.begin();
			it != scope.end(); it++) {
			println(it->key, "=", it->value);
		}
	}
}

auto SymTable::createString(StringView string) -> size_t {
	if(freeStrings.empty()) {
		strings.append(string);
		return strings.size() - 1;
	}

	auto index = freeStrings[0];
	freeStrings.remove(0);
	strings[index] = string;
	return index;
}

auto SymTable::freeString(const Value* variable) -> void {
	freeStrings.append(variable->ownerIndex);
}
