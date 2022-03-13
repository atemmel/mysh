#include "symtable.hpp"

#include "core/print.hpp"

auto Value::toString() const -> StringView {
	switch(kind) {
		case Kind::String:
			return string;
		case Kind::Bool:
			return boolean ?
				"true" : "false";
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
				break;
		}
	}
	// reset
	ownerIndex = Value::OwnerLess;
}

auto SymTable::putVariable(StringView identifier, const Value& value) -> void {

	auto newValue = createValue(value);

	// remove prior value (if applicable)
	auto prev = getVariable(identifier);
	if(prev != nullptr) {
		prev->free(*this);
	}

	variables.put(identifier, newValue);
}

auto SymTable::createValue(const Value& value) -> Value {
	switch(value.kind) {
		case Value::Kind::String:
			return createValue(value.string);
		case Value::Kind::Bool:
			return createValue(value.boolean);
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

auto SymTable::getVariable(StringView identifier) -> Value* {
	return variables.get(identifier);
}

auto SymTable::dump() const -> void {
	if(variables.empty()) {
		println("Empty symtable");
	} else {
		println("Symtable was not empty:");
	}

	for(auto it = variables.begin();
		it != variables.end(); it++) {
		println(it->key, "=", it->value);
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
