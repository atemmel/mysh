#include "interpreter.hpp"

#include <ctype.h>

#include "core/print.hpp"
#include "core/stringbuilder.hpp"
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
	this->root = &root;
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
	collectedValues.append(escape(interpolate(Value{
		.string = node.token->value,
		.kind = Value::Kind::String,
		.ownerIndex = Value::OwnerLess,
	})));
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

auto Interpreter::visit(FnDeclarationNode& node) -> void {
	//TODO: arg mismatch
	assert(node.args.size() == callArgs.size());
	symTable.addScope();
	for(size_t i = 0; i < node.args.size(); ++i) {
		symTable.putVariable(node.args[i]->value,
			callArgs[i]);
	}
	for(auto& child : node.children) {
		child->accept(*this);
	}
	symTable.dropScope();
	if(toReturn.hasValue()) {
		collectedValues.append(toReturn.value());
	}
}

auto Interpreter::visit(ReturnNode& node) -> void {
	//TODO: this
	collectedValues.clear();
	toReturn.disown();
	for(auto& child : node.children) {
		child->accept(*this);
	}
	if(!collectedValues.empty()) {
		toReturn = collectedValues[0];
	}
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

auto Interpreter::visit(LoopNode& node) -> void {
	symTable.addScope();
	if(node.init != nullptr) {
		node.init->accept(*this);
	}
	collectedValues.clear();
	node.condition->accept(*this);
	auto value = collectedValues[0];
	collectedValues.clear();

	//TODO: this should be an error
	assert(value.kind == Value::Kind::Bool);

	while(value.boolean) {

		for(auto& child : node.children) {
			child->accept(*this);
		}

		if(node.step != nullptr) {
			node.step->accept(*this);
		}
		collectedValues.clear();
		node.condition->accept(*this);
		value = collectedValues[0];
		collectedValues.clear();
	}

	symTable.dropScope();
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
	collectedValues[0].free(symTable);
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
		case Token::Kind::Multiply:
			result = multiplyValues(lhs, rhs);
			break;
		case Token::Kind::Divide:
			result = divideValues(lhs, rhs);
			break;
		case Token::Kind::Less:
			result = lessValues(lhs, rhs);
			break;
		case Token::Kind::Greater:
			result = greaterValues(lhs, rhs);
			break;
		case Token::Kind::Equals:
			result = equalsValues(lhs, rhs);
			break;
		case Token::Kind::NotEquals:
			result = notEqualsValues(lhs, rhs);
			break;
		case Token::Kind::LessEquals:
			result = lessEqualsValues(lhs, rhs);
			break;
		case Token::Kind::GreaterEquals:
			result = greaterEqualsValues(lhs, rhs);
			break;
		case Token::Kind::LogicalAnd:
			result = logicalAndValues(lhs, rhs);
			break;
		case Token::Kind::LogicalOr:
			result = logicalOrValues(lhs, rhs);
			break;
		default:
			assert(false);
	}

	lhs.free(symTable);
	rhs.free(symTable);
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
			result = notValue(operand);
			break;
		default:
			assert(false);
	}

	operand.free(symTable);
	collectedValues.pop();
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
	for(auto& arg : args) {
		arg.free(symTable);
	}
	if(result.hasValue()) {
		collectedValues.append(result.value());
	} else {
		//TODO: fix this
	}
}

auto Interpreter::visit(RootNode& node) -> void {
	for(auto& child : node.children) {
		child->accept(*this);
		collectedValues.clear();
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

auto Interpreter::multiplyValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == Value::Kind::Integer);
	assert(rhs.kind == Value::Kind::Integer);
	auto left = lhs.integer;
	auto right = rhs.integer;
	return Value{
		.integer = left * right,
		.kind = Value::Kind::Integer,
		.ownerIndex = Value::OwnerLess,
	};
}

auto Interpreter::divideValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == Value::Kind::Integer);
	assert(rhs.kind == Value::Kind::Integer);
	auto left = lhs.integer;
	auto right = rhs.integer;
	return Value{
		.integer = left / right,
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

auto Interpreter::notValue(const Value& operand) -> Value {
	assert(operand.kind == Value::Kind::Bool);
	auto boolean = operand.boolean;
	return Value{
		.boolean = !boolean,
		.kind = Value::Kind::Bool,
		.ownerIndex = Value::OwnerLess,
	};
}


auto Interpreter::equalsValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind);
	switch(lhs.kind) {
		case Value::Kind::Bool:
			return Value{
				.boolean = lhs.boolean == rhs.boolean,
				.kind = Value::Kind::Bool,
				.ownerIndex = Value::OwnerLess,
			};
		case Value::Kind::Integer:
			return Value{
				.boolean = lhs.integer == rhs.integer,
				.kind = Value::Kind::Bool,
				.ownerIndex = Value::OwnerLess,
			};
		default:
			assert(false);
			break;
	}

	assert(false);
	return {};
}

auto Interpreter::notEqualsValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind);
	switch(lhs.kind) {
		case Value::Kind::Bool:
			return Value{
				.boolean = lhs.boolean != rhs.boolean,
				.kind = Value::Kind::Bool,
				.ownerIndex = Value::OwnerLess,
			};
		case Value::Kind::Integer:
			return Value{
				.boolean = lhs.integer != rhs.integer,
				.kind = Value::Kind::Bool,
				.ownerIndex = Value::OwnerLess,
			};
		default:
			assert(false);
			break;
	}

	assert(false);
	return {};
}

auto Interpreter::lessEqualsValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind);
	assert(lhs.kind == Value::Kind::Integer);
	switch(lhs.kind) {
		case Value::Kind::Integer:
			return Value{
				.boolean = lhs.integer <= rhs.integer,
				.kind = Value::Kind::Bool,
				.ownerIndex = Value::OwnerLess,
			};
		default:
			assert(false);
			break;
	}

	assert(false);
	return {};
}

auto Interpreter::greaterEqualsValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind);
	assert(lhs.kind == Value::Kind::Integer);
	switch(lhs.kind) {
		case Value::Kind::Integer:
			return Value{
				.boolean = lhs.integer >= rhs.integer,
				.kind = Value::Kind::Bool,
				.ownerIndex = Value::OwnerLess,
			};
		default:
			assert(false);
			break;
	}

	assert(false);
	return {};
}

auto Interpreter::logicalAndValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind);
	assert(lhs.kind == Value::Kind::Bool);

	auto l = lhs.boolean;
	auto r = rhs.boolean;

	return Value{
		.boolean = l && r,
		.kind = Value::Kind::Bool,
		.ownerIndex = Value::OwnerLess,
	};
}

auto Interpreter::logicalOrValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind);
	assert(lhs.kind == Value::Kind::Bool);

	auto l = lhs.boolean;
	auto r = rhs.boolean;

	return Value{
		.boolean = l || r,
		.kind = Value::Kind::Bool,
		.ownerIndex = Value::OwnerLess,
	};
}


//TODO: the complexity of this algorithm can be improved
//		by removing usage of mem::copy and doing things
//		iteratively
auto Interpreter::escape(const Value& original) -> Value {
	assert(original.kind == Value::Kind::String);
	size_t index = original.string.find('\\');
	if(index == -1) {
		return original;
	}

	auto view = original.string.view(0, original.string.size());
	String string(original.string.size(), '\0');

	mem::copy(view.view(0, index), string);
	auto toIndex = index;

	while(index != -1) {
		++index;
		switch(view[index]) {
			case '\\':
				string[toIndex] = '\\';
				break;
			case 'n':
				string[toIndex] = '\n';
				break;
			case 't':
				string[toIndex] = '\t';
				break;
			case '$':
				string[toIndex] = '$';
				break;
			case '{':
				string[toIndex] = '{';
				break;
			case '}':
				string[toIndex] = '}';
				break;
			case ' ':
				--toIndex;
				break;
			default:
				assert(false);
				break;
		}

		++toIndex;

		auto fromBegin = view.begin() + index + 1;
		auto fromEnd = view.end();
		auto toBegin = string.begin() + toIndex;
		mem::copy(fromBegin, fromEnd, toBegin);

		view = view.view(index + 1, view.size());
		index = view.find('\\');
		if(index == -1) {
			string[toIndex + view.size()] = '\0';
		}
		toIndex += index;
	}

	return symTable.create(string);
}

auto Interpreter::interpolate(const Value& original) -> Value {
	return interpolateBraces(interpolateDollar(original));
}

auto Interpreter::interpolateDollar(const Value& original) -> Value {
	assert(original.kind == Value::Kind::String);
	size_t index = original.string.find('$');

	// skip escaped vars
	while(index != -1 && index > 0 && original.string[index - 1] == '\\') {
		index = original.string.find('$', index + 1);
	}

	// if no var
	if(index == -1) {
		// no interpolation
		return original;
	}

	StringBuilder builder;
	builder.reserve(16);
	size_t prev = 0;

	// while there are vars in string
	while(index != -1) {
		while(index > 0 && original.string[index - 1] == '\\') {
			index = original.string.find('$', index + 1);
		}
		if(index == -1) {
			break;
		}
		if(prev > 0) {
			--prev;
		}
		auto between = original.string.view(prev, index);
		builder.append(between);
		++index;
		auto start = original.string.begin() + index;
		char c = original.string[index];
		auto len = 0;
		for(;(isalnum(c) || c == '_') && index < original.string.size(); ++index, ++len) {
			c = original.string[index];
		}

		if(index != original.string.size()) {
			--len;
		}
		auto name = StringView(start, len);
		auto var = symTable.getVariable(name);

		//TODO: this should be an error
		assert(var != nullptr);

		switch(var->kind) {
			case Value::Kind::String:
				builder.append(var->string);
				break;
			case Value::Kind::Bool:
				builder.append(var->boolean);
				break;
			case Value::Kind::Integer:
				builder.append(var->integer);
				break;
		}
		prev = index;
		index = original.string.find('$', prev - 1);
	}

	if(prev < original.string.size()) {
		auto end = original.string.view(prev - 1, original.string.size());
		builder.append(end);
	}

	return symTable.create(move(builder));
}

auto Interpreter::interpolateBraces(const Value& original) -> Value {
	assert(original.kind == Value::Kind::String);
	size_t index = original.string.find('{');

	// skip escaped vars
	while(index != -1 && index > 0 && original.string[index - 1] == '\\') {
		index = original.string.find('{', index + 1);
	}

	// if no var
	if(index == -1) {
		// no interpolation
		return original;
	}

	StringBuilder builder;
	builder.reserve(16);
	size_t prev = 0;

	// while there are vars in string
	while(index != -1) {
		while(index > 0 && original.string[index - 1] == '\\') {
			index = original.string.find('{', index + 1);
		}
		if(index == -1) {
			break;
		}
		if(prev > 0) {
			--prev;
		}
		auto between = original.string.view(prev, index);
		builder.append(between);
		++index;
		auto start = original.string.begin() + index;
		char c = original.string[index];
		auto len = 0;
		for(; c != '}' && index < original.string.size(); ++index, ++len) {
			c = original.string[index];
		}

		if(index != original.string.size()) {
			--len;
		}
		auto name = StringView(start, len);
		auto var = symTable.getVariable(name);

		//TODO: this should be an error
		assert(var != nullptr);

		switch(var->kind) {
			case Value::Kind::String:
				builder.append(var->string);
				break;
			case Value::Kind::Bool:
				builder.append(var->boolean);
				break;
			case Value::Kind::Integer:
				builder.append(var->integer);
				break;
		}
		prev = index;
		index = original.string.find('{', prev);
	}

	auto end = original.string.view(prev, original.string.size());
	builder.append(end);
	return symTable.create(move(builder));
}

auto Interpreter::executeFunction(StringView identifier,
	const Array<Value>& args) -> Optional<Value> {

	// try to find builtin
	auto builtin = builtins.get(identifier);
	if(builtin != nullptr) {
		return (*builtin)(args);
	}

	// if no builtin is found
	// try to find fitting function
	auto function = root->functions.get(identifier);
	if(function != nullptr) {
		return executeUserDefinedFunction(function->get(), args);
	}

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

auto Interpreter::executeUserDefinedFunction(FnDeclarationNode* func, const Array<Value>& args) -> Optional<Value> {
	callArgs = args;
	visit(*func);
	collectedValues.clear();
	return toReturn;
}
