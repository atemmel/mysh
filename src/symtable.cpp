#include "symtable.hpp"

auto SymTable::putVariable(StringView identifier, StringView value) -> void {
	auto it = variables.begin();
	for(; it != variables.end(); ++it) {
		if(it->identifier == identifier) {
			it->value = value;
			return;
		}
	}

	// identifier is never found
	variables.append(Variable{
		.identifier = identifier,
		.value = value,
	});
}

auto SymTable::getVariable(StringView identifier) -> String* {
	auto it = variables.begin();
	for(; it != variables.end(); ++it) {
		if(it->identifier.equals(identifier)) {
			return &it->value;
		}
		println(it->identifier, "is not", identifier);
		println(it->identifier.size(), "is not", identifier.size());
	}

	// lookup failed
	return nullptr;
}
