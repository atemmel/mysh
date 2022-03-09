#include "symtable.hpp"

auto SymTable::putVariable(StringView identifier, StringView value) -> void {
	variables.put(identifier, Variable{
		.value = value,
	});
}

auto SymTable::getVariable(StringView identifier) -> Variable* {
	return variables.get(identifier);
}
