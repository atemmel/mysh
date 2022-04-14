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
	auto& lastScopeVars = scopes[scopes.size() - 1];
	for(auto it = lastScopeVars.begin(); it != lastScopeVars.end(); ++it) {
		it->value.free(*this);
	}
	lastScopeVars.clear();
	scopes.pop();
}

auto SymTable::putVariable(StringView identifier, const Value& value) -> void {

	auto newValue = createValue(value);

	size_t scopeIndex;
	// remove prior value (if applicable)
	auto prev = getVariableInfo(identifier);
	if(prev.value != nullptr) {
		prev.value->free(*this);
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
	assert(value.size() < 1024);
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

auto SymTable::create(const String& string) -> Value {
	return createValue(string);
}

auto SymTable::create(String&& string) -> Value {
	auto index = createString(move(string));
	return Value{
		.string = strings[index].view(),
		.kind = Value::Kind::String,
		.ownerIndex = index,
	};
}

auto SymTable::createConverted(String&& string) -> Value {
	if(string == "true") {
		return Value{
			.boolean = true,
			.kind = Value::Kind::Bool,
			.ownerIndex = Value::OwnerLess,
		};
	}

	if(string == "false") {
		return Value{
			.boolean = false,
			.kind = Value::Kind::Bool,
			.ownerIndex = Value::OwnerLess,
		};
	}

	//TODO: proper conversion error handling
	char* strEnd = nullptr;
	auto value = strtol(string.data(), &strEnd, 10);

	if(*strEnd == '\0') {
		return Value{
			.integer = value,
			.kind = Value::Kind::Integer,
			.ownerIndex = Value::OwnerLess,
		};
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

	auto prev = getVariable(identifier);
	if(prev != nullptr) {
		prev->free(*this);
	}
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

auto SymTable::createString(String&& string) -> size_t {
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
