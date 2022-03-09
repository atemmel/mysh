#include "interpreter.hpp"

#include "spawn.hpp"

auto Interpreter::interpret(RootNode& root) -> bool {
	root.accept(*this);
	return true;
}

auto Interpreter::visit(IdentifierNode& node) -> void {
	collectedStrings.append(node.token->value);
}

auto Interpreter::visit(StringLiteralNode& node) -> void {
	collectedStrings.append(node.token->value);
}

auto Interpreter::visit(DeclarationNode& node) -> void {
	auto identifier = node.token->value;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	assert(collectedStrings.size() == 1);
	//TODO: check for redeclaration
	symTable.putVariable(identifier, collectedStrings[0]);
	collectedStrings.clear();
}

auto Interpreter::visit(VariableNode& node) -> void {
	auto identifier = node.token->value;
	auto variable = symTable.getVariable(identifier);
	//TODO: check for usage of undeclared variables
	assert(variable != nullptr);
	collectedStrings.append(variable->value);
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
	
	auto args = move(collectedStrings);

	// execute
	executeFunction(func, args);
}

auto Interpreter::visit(RootNode& node) -> void {
	for(auto& child : node.children) {
		child->accept(*this);
	}
}

auto Interpreter::executeFunction(StringView identifier,
	const Array<StringView>& args) -> void {

	Array<String> strings;
	strings.reserve(1 + args.size());
	strings.append(identifier);
	for(auto arg : args) {
		strings.append(arg);
	}
	spawn(strings);
}
