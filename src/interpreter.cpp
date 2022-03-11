#include "interpreter.hpp"

#include "spawn.hpp"

auto Interpreter::interpret(RootNode& root) -> bool {
	root.accept(*this);
	return true;
}

auto Interpreter::visit(IdentifierNode& node) -> void {
	auto value = Value{
		.kind = Value::Kind::String,
		.ownerIndex = static_cast<size_t>(-1),
	};

	value.string = node.token->value;

	collectedValues.append(value);
}

auto Interpreter::visit(StringLiteralNode& node) -> void {
	auto value = Value{
		.kind = Value::Kind::String,
		.ownerIndex = static_cast<size_t>(-1),
	};

	value.string = node.token->value;

	collectedValues.append(value);
}

auto Interpreter::visit(DeclarationNode& node) -> void {
	auto identifier = node.token->value;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	assert(collectedValues.size() == 1);
	//TODO: check for redeclaration
	auto& value = collectedValues[0];
	switch(value.kind) {
		case Value::Kind::String:
			symTable.putVariable(identifier, collectedValues[0].string);
			break;
			//TODO: this
		case Value::Kind::Bool:
		case Value::Kind::Null:
			break;
	}
	collectedValues.clear();
}

auto Interpreter::visit(VariableNode& node) -> void {
	auto identifier = node.token->value;
	auto variable = symTable.getVariable(identifier);
	//TODO: check for usage of undeclared variables
	assert(variable != nullptr);
	collectedValues.append(*variable);
}

auto Interpreter::visit(AssignmentNode& node) -> void {

}

auto Interpreter::visit(FunctionCallNode& node) -> void {
	// get function name
	const auto func = node.token->value;

	// collect args
	for(auto& child : node.children) {
		child->accept(*this);
	}
	
	auto args = move(collectedValues);

	// execute
	executeFunction(func, args);
}

auto Interpreter::visit(RootNode& node) -> void {
	for(auto& child : node.children) {
		child->accept(*this);
	}
}

auto Interpreter::executeFunction(StringView identifier,
	const Array<Value>& args) -> void {

	Array<String> strings;
	strings.reserve(1 + args.size());
	strings.append(identifier);
	for(auto& arg : args) {
		switch(arg.kind) {
			case Value::Kind::String:
				strings.append(arg.string);
				break;
			//TODO: this
			case Value::Kind::Bool:
			case Value::Kind::Null:
				assert(false);
				break;
		}
	}
	spawn(strings);
}
