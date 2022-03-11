#include "symtable.hpp"

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
			case Kind::Null:
				break;
		}
	}
	// reset
	kind = Kind::Null;
}

auto SymTable::putVariable(StringView identifier, StringView value) -> void {
	auto index = createString(value);

	variables.put(identifier, Value{
		.string = strings[index],
		.kind = Value::Kind::String,
		.ownerIndex = index,
	});
}

auto SymTable::getVariable(StringView identifier) -> Value* {
	return variables.get(identifier);
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
