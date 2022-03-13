#include "interpreter.hpp"

#include "core/print.hpp"
#include "spawn.hpp"

using Builtin = void(*)(const Array<Value>&);

static auto builtinPrint(const Array<Value>& args) -> void {
	for(const auto& arg : args) {
		fprint(stdout, arg);
		fprint(stdout, " ");
	}
	fprint(stdout, "\n");
}

HashTable<StringView, Builtin> builtins = {
	{ "print", builtinPrint },
};

auto Interpreter::interpret(RootNode& root) -> bool {
	symTable.addScope();
	root.accept(*this);
	symTable.dropScope();
	return true;
}

auto Interpreter::visit(IdentifierNode& node) -> void {
	collectedValues.append(Value{
		.string = node.token->value,
		.kind = Value::Kind::String,
		.ownerIndex = static_cast<size_t>(-1),
	});
}

auto Interpreter::visit(StringLiteralNode& node) -> void {
	collectedValues.append(Value{
		.string = node.token->value,
		.kind = Value::Kind::String,
		.ownerIndex = static_cast<size_t>(-1),
	});
}

auto Interpreter::visit(BoolLiteralNode& node) -> void {
	auto value = Value{
		.kind = Value::Kind::Bool,
		.ownerIndex = static_cast<size_t>(-1),
	};

	value.boolean = node.token->kind == Token::Kind::True;

	collectedValues.append(value);
}

auto Interpreter::visit(DeclarationNode& node) -> void {
	auto identifier = node.token->value;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	assert(collectedValues.size() == 1);
	//TODO: check for redeclaration
	symTable.putVariable(identifier, collectedValues[0]);
	collectedValues.clear();
}

auto Interpreter::visit(VariableNode& node) -> void {
	auto identifier = node.token->value;
	auto variable = symTable.getVariable(identifier);

	//TODO: check for usage of undeclared variables
	assert(variable != nullptr);

	lastVisitedVariable = &node;
	collectedValues.append(*variable);
}

auto Interpreter::visit(AssignmentNode& node) -> void {
	assert(node.children.size() == 2);

	// find target
	node.children[0]->accept(*this);
	auto identifier = lastVisitedVariable->token->value;
	collectedValues.clear();

	// find value
	node.children[1]->accept(*this);
	assert(collectedValues.size() == 1);
	symTable.putVariable(identifier, collectedValues[0]);
	// reset
	collectedValues.clear();
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

	// try to find builtin
	auto builtin = builtins.get(identifier);
	if(builtin != nullptr) {
		(*builtin)(args);
		return;
	}

	// if no builtin is found

	// try spawn external program
	Array<String> strings;
	strings.reserve(1 + args.size());
	strings.append(identifier);
	for(auto& arg : args) {
		strings.append(arg.toString());
	}
	spawn(strings);
}
