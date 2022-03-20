#include "interpreter.hpp"

#include "core/print.hpp"
#include "spawn.hpp"

using Builtin = Optional<Value>(*)(const Array<Value>&);

static auto builtinPrint(const Array<Value>& args) -> Optional<Value> {
	for(const auto& arg : args) {
		fprint(stdout, arg);
		fprint(stdout, " ");
	}
	fprint(stdout, "\n");
	return {};
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

auto Interpreter::visit(BarewordNode& node) -> void {
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
		.ownerIndex = Value::OwnerLess,
	});
}

auto Interpreter::visit(BoolLiteralNode& node) -> void {
	auto value = Value{
		.kind = Value::Kind::Bool,
		.ownerIndex = Value::OwnerLess,
	};

	value.boolean = node.token->kind == Token::Kind::True;

	collectedValues.append(value);
}

auto Interpreter::visit(IntegerLiteralNode& node) -> void {
	auto value = Value{
		.kind = Value::Kind::Integer,
		.ownerIndex = Value::OwnerLess,
	};

	value.integer = node.value;

	collectedValues.append(value);
}

auto Interpreter::visit(DeclarationNode& node) -> void {
	auto identifier = node.token->value;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	assert(collectedValues.size() == 1);
	//TODO: check for redeclaration
	assert(symTable.getVariable(identifier) == nullptr);
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

auto Interpreter::visit(BranchNode& node) -> void {
	// if no expression
	if(node.expression == nullptr) {
		// eval statement and be done
		node.statement->accept(*this);
		return;
	}

	node.expression->accept(*this);
	assert(collectedValues.size() == 1);

	auto value = collectedValues[0];
	collectedValues.clear();

	//TODO: check for non-boolean exprs in condition
	assert(value.kind == Value::Kind::Bool);

	// if this is the chosen branch
	if(value.boolean) {
		node.statement->accept(*this);
		return;
	}

	// otherwise, look into the next branches
	for(auto& child : node.children) {
		child->accept(*this);
	}
}

auto Interpreter::visit(ScopeNode& node) -> void {
	symTable.addScope();
	for(auto& child : node.children) {
		collectedValues.clear();
		child->accept(*this);
	}
	symTable.dropScope();
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

auto Interpreter::visit(BinaryOperatorNode& node) -> void {
	assert(node.children.size() == 2);

	// collect args
	node.children[0]->accept(*this);
	auto lhs = collectedValues[0];
	collectedValues.clear();
	node.children[1]->accept(*this);
	auto rhs = collectedValues[0];
	collectedValues.clear();

	Value result;
	switch(node.token->kind) {
		case Token::Kind::Add:
			result = addValues(lhs, rhs);
			break;
		case Token::Kind::Subtract:
			result = subtractValues(lhs, rhs);
			break;
		case Token::Kind::Less:
			result = lessValues(lhs, rhs);
			break;
		case Token::Kind::Greater:
			result = greaterValues(lhs, rhs);
			break;
		default:
			assert(false);
	}

	collectedValues.append(result);
}

auto Interpreter::visit(UnaryOperatorNode& node) -> void {
	assert(node.children.size() == 1);

	// collect args
	for(auto& child : node.children) {
		child->accept(*this);
	}

	assert(collectedValues.size() == 1);

	auto operand = collectedValues[0];

	Value result;
	switch(node.token->kind) {
		case Token::Kind::Subtract:
			result = negateValue(operand);
			break;
		case Token::Kind::Bang:
			result = inverseValue(operand);
			break;
		default:
			assert(false);
	}

	collectedValues.clear();
	collectedValues.append(result);
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
	auto result = executeFunction(func, args);
	if(result.hasValue()) {
		collectedValues.append(result.value());
	}
}

auto Interpreter::visit(RootNode& node) -> void {
	for(auto& child : node.children) {
		collectedValues.clear();
		child->accept(*this);
	}
}

auto Interpreter::addValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == Value::Kind::Integer);
	assert(rhs.kind == Value::Kind::Integer);
	auto left = lhs.integer;
	auto right = rhs.integer;
	return Value{
		.integer = left + right,
		.kind = Value::Kind::Integer,
		.ownerIndex = Value::OwnerLess,
	};
}

auto Interpreter::subtractValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == Value::Kind::Integer);
	assert(rhs.kind == Value::Kind::Integer);
	auto left = lhs.integer;
	auto right = rhs.integer;
	return Value{
		.integer = left - right,
		.kind = Value::Kind::Integer,
		.ownerIndex = Value::OwnerLess,
	};
}

auto Interpreter::negateValue(const Value& operand) -> Value {
	assert(operand.kind == Value::Kind::Integer);
	auto integer = operand.integer;
	return Value{
		.integer = -integer,
		.kind = Value::Kind::Integer,
		.ownerIndex = Value::OwnerLess,
	};
}

auto Interpreter::lessValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind)
	assert(lhs.kind == Value::Kind::Integer || lhs.kind == Value::Kind::String);
	assert(rhs.kind == Value::Kind::Integer || rhs.kind == Value::Kind::String);

	if(lhs.kind == Value::Kind::Integer && rhs.kind == Value::Kind::Integer) {
		auto left = lhs.integer;
		auto right = rhs.integer;
		return Value{
			.boolean = left < right,
			.kind = Value::Kind::Bool,
			.ownerIndex = Value::OwnerLess,
		};
	} 

	//TODO: this
	/*
	else if(lhs.kind == Value::Kind::String && rhs.kind == Value::Kind::String) {
		auto left = lhs.string;
		auto right = rhs.string;
		return Value{
			.boolean = left < right,
			.kind = Value::Kind::Bool,
			.ownerIndex = Value::OwnerLess,
		};
	}
	*/

	assert(false);
	return {};
}

auto Interpreter::greaterValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind)
	assert(lhs.kind == Value::Kind::Integer || lhs.kind == Value::Kind::String);
	assert(rhs.kind == Value::Kind::Integer || rhs.kind == Value::Kind::String);

	if(lhs.kind == Value::Kind::Integer && rhs.kind == Value::Kind::Integer) {
		auto left = lhs.integer;
		auto right = rhs.integer;
		return Value{
			.boolean = left > right,
			.kind = Value::Kind::Bool,
			.ownerIndex = Value::OwnerLess,
		};
	} 

	//TODO: this
	/*
	else if(lhs.kind == Value::Kind::String && rhs.kind == Value::Kind::String) {
		auto left = lhs.string;
		auto right = rhs.string;
		return Value{
			.boolean = left < right,
			.kind = Value::Kind::Bool,
			.ownerIndex = Value::OwnerLess,
		};
	}
	*/

	assert(false);
	return {};
}

auto Interpreter::inverseValue(const Value& operand) -> Value {
	assert(operand.kind == Value::Kind::Bool);
	auto boolean = operand.boolean;
	return Value{
		.boolean = !boolean,
		.kind = Value::Kind::Bool,
		.ownerIndex = Value::OwnerLess,
	};
}


auto Interpreter::executeFunction(StringView identifier,
	const Array<Value>& args) -> Optional<Value> {

	// try to find builtin
	auto builtin = builtins.get(identifier);
	if(builtin != nullptr) {
		return (*builtin)(args);
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
	return {};
}
