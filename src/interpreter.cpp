#include "interpreter.hpp"

#include <ctype.h>

#include "core/meta.hpp"
#include "core/print.hpp"
#include "core/stringbuilder.hpp"
#include "spawn.hpp"

using Builtin = Optional<Value>(*)(Interpreter&, const Array<Value>&);

static auto builtinPrint(Interpreter& interpreter, const Array<Value>& args) -> Optional<Value> {
	for(size_t i = 0; i < args.size(); ++i) {
		fprint(stdout, args[i]);
		fprint(stdout, " ");
	}

	// trailing newline check
	if(!args.empty()) {
		const auto& last = args[args.size() - 1];
		if(last.kind == Value::Kind::String) {
			const auto& str = last.string;
			if(!str.empty() && str[str.size() - 1] == '\n') {
				return {};
			}
		}
	}
	fprint(stdout, "\n");
	return {};
}

static auto builtinAppend(Interpreter& interpreter, const Array<Value>& args) -> Optional<Value> {
	assert(args.size() >= 2);
	assert(args[0].kind == Value::Kind::Array);

	auto value = args[0];
	auto& array = value.array;
	for(size_t i = 1; i < args.size(); ++i) {
		array.append(args[i]);
	}
	return value;
}

static auto builtinFilter(Interpreter& interpreter, const Array<Value>& args) -> Optional<Value> {
	assert(args.size() == 2);
	assert(args[0].kind == Value::Kind::Array);
	assert(args[1].kind == Value::Kind::String);

	const auto& array = args[0].array;

	Array<Value> result;
	result.reserve(array.size() / 2);
	Array<Value> arg(1);
	for(const auto& value : array) {
		arg[0] = value;
		auto boolean = interpreter.executeFunction(args[1].string, arg, {});
		assert(boolean.hasValue());
		assert(boolean.value().kind == Value::Kind::Bool);

		if(boolean.value().boolean) {
			result.append(value);
		}
	}

	return Value(result);
}

static auto builtinLength(Interpreter& interpret, const Array<Value>& args) -> Optional<Value> {
	assert(args.size() == 1);

	switch(args[0].kind) {
		case Value::Kind::String:
			return Value(int64_t(args[0].string.size()));
		case Value::Kind::Array:
			return Value(int64_t(args[0].array.size()));
		case Value::Kind::Bool:
		case Value::Kind::Integer:
			break;
	}

	assert(args[0].kind == Value::Kind::Array);
	return {};
}

HashTable<StringView, Builtin> builtins = {
	{ "print", builtinPrint },
	{ "append", builtinAppend },
	{ "filter", builtinFilter },
	{ "len", builtinLength },
};

auto Interpreter::interpret(RootNode& root) -> bool {
	this->root = &root;
	symTable.addScope();
	root.accept(*this);
	symTable.dropScope();
	return true;
}

auto Interpreter::visit(IdentifierNode& node) -> void {
	collectedValues.append(Value(node.token->value));
}

auto Interpreter::visit(BarewordNode& node) -> void {
	collectedValues.append(Value(node.token->value));
}

auto Interpreter::visit(StringLiteralNode& node) -> void {
	collectedValues.append(escape(interpolate(Value(node.token->value))));
}

auto Interpreter::visit(BoolLiteralNode& node) -> void {
	auto value = Value();
	value.boolean = node.token->kind == Token::Kind::True;
	collectedValues.append(value);
}

auto Interpreter::visit(IntegerLiteralNode& node) -> void {
	auto value = Value(node.value);
	value.integer = node.value;
	collectedValues.append(value);
}

auto Interpreter::visit(ArrayLiteralNode& node) -> void {
	for(auto& child : node.children) {
		child->accept(*this);
	}
	collectedValues.append(Value(move(collectedValues)));
}

auto Interpreter::visit(DeclarationNode& node) -> void {
	auto identifier = node.token->value;
	for(auto& child : node.children) {
		piping = true;
		child->accept(*this);
		piping = false;
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
	if(node.condition != nullptr) {
		doRegularLoop(node);
	} else if(node.iterable != nullptr
		&& node.iterator != nullptr) {
		doForInLoop(node);
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
	collectedValues.clear();
}

auto Interpreter::visit(BinaryOperatorNode& node) -> void {
	assert(node.children.size() == 2);



	// pipe
	if(node.token->kind == Token::Kind::Or) {
		pipe(node.children[0], node.children[1]);
		return;
	}

	// collect args
	node.children[0]->accept(*this);
	assert(collectedValues.size() == 1);
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
		case Token::Kind::Modulo:
			result = moduloValues(lhs, rhs);
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

	collectedValues.pop();
	collectedValues.append(result);
}

auto Interpreter::visit(FunctionCallNode& node) -> void {
	// get function name
	const auto func = node.token->value;

	// recieved stdin check
	Value stdinVal;
	Optional<const Value*> stdinArg = {};

	if(!collectedValues.empty()) {
		stdinVal = collectedValues[0];
		stdinArg = &stdinVal;
		collectedValues.clear();
	}

	// collect args
	for(auto& child : node.children) {
		child->accept(*this);
	}
	
	auto args = move(collectedValues);

	// execute
	auto result = executeFunction(func, args, stdinArg);
	if(result.hasValue()) {
		collectedValues.append(result.value());
	} else {
		//TODO: fix this
	}
}

auto Interpreter::visit(RootNode& node) -> void {
	for(auto& child : node.children) {
		collectedValues.clear();
		child->accept(*this);
		if(!collectedValues.empty()) {
			assert(collectedValues.size() == 1);
			builtinPrint(*this, collectedValues);
		}
	}
}

auto Interpreter::doRegularLoop(LoopNode& node) -> void {
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

}

auto Interpreter::doForInLoop(LoopNode& node) -> void {
	node.iterator->accept(*this);
	assert(collectedValues.size() == 1);
	assert(collectedValues[0].kind == Value::Kind::String);
	auto name = move(collectedValues[0].string);
	collectedValues.clear();

	node.iterable->accept(*this);
	assert(collectedValues.size() == 1);
	assert(collectedValues[0].kind == Value::Kind::Array);
	auto iterable = move(collectedValues[0].array);

	size_t i = 0;
	while(i < iterable.size()) {
		const auto& current = iterable[i];

		symTable.putVariable(name, current);
		for(auto& child : node.children) {
			child->accept(*this);
		}
		
		++i;
	}
}

auto Interpreter::addValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == Value::Kind::Integer);
	assert(rhs.kind == Value::Kind::Integer);
	auto left = lhs.integer;
	auto right = rhs.integer;
	return Value(left + right);
}

auto Interpreter::subtractValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == Value::Kind::Integer);
	assert(rhs.kind == Value::Kind::Integer);
	auto left = lhs.integer;
	auto right = rhs.integer;
	return Value(left - right);
}

auto Interpreter::negateValue(const Value& operand) -> Value {
	assert(operand.kind == Value::Kind::Integer);
	auto integer = operand.integer;
	return Value(-integer);
}

auto Interpreter::multiplyValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == Value::Kind::Integer);
	assert(rhs.kind == Value::Kind::Integer);
	auto left = lhs.integer;
	auto right = rhs.integer;
	return Value(left * right);
}

auto Interpreter::divideValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == Value::Kind::Integer);
	assert(rhs.kind == Value::Kind::Integer);
	auto left = lhs.integer;
	auto right = rhs.integer;
	return Value(left / right);
}

auto Interpreter::moduloValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == Value::Kind::Integer);
	assert(rhs.kind == Value::Kind::Integer);
	auto left = lhs.integer;
	auto right = rhs.integer;
	return Value(left % right);
}

auto Interpreter::lessValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind)
	assert(lhs.kind == Value::Kind::Integer || lhs.kind == Value::Kind::String);
	assert(rhs.kind == Value::Kind::Integer || rhs.kind == Value::Kind::String);

	if(lhs.kind == Value::Kind::Integer && rhs.kind == Value::Kind::Integer) {
		auto left = lhs.integer;
		auto right = rhs.integer;
		return Value(left < right);
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
		return Value(left > right);
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
	return Value(!boolean);
}


auto Interpreter::equalsValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind);
	switch(lhs.kind) {
		case Value::Kind::Bool:
			return Value(lhs.boolean == rhs.boolean);
		case Value::Kind::Integer:
			return Value(lhs.integer == rhs.integer);
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
			return Value(lhs.boolean != rhs.boolean);
		case Value::Kind::Integer:
			return Value(lhs.integer != rhs.integer);
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
			return Value(lhs.integer <= rhs.integer);
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
			return Value(lhs.integer >= rhs.integer);
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

	return Value(l && r);
}

auto Interpreter::logicalOrValues(const Value& lhs, const Value& rhs) -> Value {
	assert(lhs.kind == rhs.kind);
	assert(lhs.kind == Value::Kind::Bool);

	auto l = lhs.boolean;
	auto r = rhs.boolean;

	return Value(l || r);
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

	StringBuilder builder;
	builder.reserve(original.string.size());

	auto view = original.string.view(0, original.string.size());
	builder.append(view.view(0, index));

	auto prev = index;
	while(index != -1) {
		++index;
		switch(view[index]) {
			case '\\':
				builder.append("\\");
				break;
			case 'n':
				builder.append("\n");
				break;
			case 't':
				builder.append("\t");
				break;
			case '$':
				builder.append("$");
				break;
			case '{':
				builder.append("{");
				break;
			case '}':
				builder.append("}");
				break;
			case ' ':
				break;
			default:
				assert(false);
				break;
		}

		++index;

		prev = index;
		index = view.find('\\', prev);
		if(index != -1) {
			builder.append(view.view(prev, index));
		}
	}

	if(prev < view.size()) {
		builder.append(original.string.view(prev));
	}

	builder.addNull();

	return symTable.create(move(builder));
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
			case Value::Kind::Array:
				builder.append(var->toString());
				break;
		}
		prev = index;
		index = original.string.find('$', prev - 1);
	}

	if(prev < original.string.size()) {
		auto end = original.string.view(prev - 1, original.string.size());
		builder.append(end);
	}

	builder.addNull();
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
			case Value::Kind::Array:
				builder.append(var->toString());
				break;
		}
		prev = index;
		index = original.string.find('{', prev);
	}

	if(prev < original.string.size()) {
		//auto end = original.string.view(prev - 1, original.string.size());
		//builder.append(end);
		auto end = original.string.view(prev, original.string.size());
		builder.append(end);
	}
	builder.addNull();
	auto str = String(move(builder));
	return symTable.create(move(str));
}

auto Interpreter::pipe(Child& current, Child& next) -> Optional<Value> {
	bool unPipe = false;
	if(!piping) {
		piping = true;
		unPipe = true;
	}
	current->accept(*this);
	if(unPipe) {
		piping = false;
	}
	assert(collectedValues.size() > 0);
	next->accept(*this);
	if(!collectedValues.empty()) {
		return collectedValues[0];
	}
	return {};
}

auto Interpreter::executeFunction(StringView identifier,
	const Array<Value>& args, Optional<const Value*> inArg) -> Optional<Value> {

	// try to find builtin
	auto builtin = builtins.get(identifier);
	if(builtin != nullptr) {
		if(inArg.hasValue()) {
			auto newArgs = Array<Value>(args.size() + 1);
			newArgs[0] = *inArg.value();
			mem::copy(args.begin(), args.end(), newArgs.begin() + 1);
			return (*builtin)(*this, newArgs);
		}
		return (*builtin)(*this, args);
	}

	// if no builtin is found
	// try to find fitting function
	auto function = root->functions.get(identifier);
	if(function != nullptr) {
		if(inArg.hasValue()) {
			auto newArgs = Array<Value>(args.size() + 1);
			newArgs[0] = *inArg.value();
			mem::copy(args.begin(), args.end(), newArgs.begin() + 1);
			return executeUserDefinedFunction(function->get(), newArgs);
		}
		return executeUserDefinedFunction(function->get(), args);
	}

	// try spawn external program
	Array<String> strings;
	strings.reserve(1 + args.size());
	strings.append(identifier);
	for(auto& arg : args) {
		strings.append(arg.toString());
	}

	SpawnResult spawnResult;

	if(inArg.hasValue()) {
		String str;
		StringView view;
		if(inArg.value()->kind == Value::Kind::String) {
			view = inArg.value()->string;
		} else {
			str = inArg.value()->toString();
			view = str;
		}
		spawnResult = spawn(SpawnOptions{
			.args = strings,
			.stdinView = view,
			.captureStdout = piping,
		});
	} else {
		spawnResult = spawn(SpawnOptions{
			.args = strings,
			.stdinView = {},
			.captureStdout = piping,
		});
	}

	if(!spawnResult.out.empty()) {
		spawnResult.out.cropRightWhitespace();
		return symTable.createConverted(move(spawnResult.out));
	}

	return {};
}

auto Interpreter::executeUserDefinedFunction(FnDeclarationNode* func, const Array<Value>& args) -> Optional<Value> {
	callArgs = args;
	visit(*func);
	collectedValues.clear();
	return toReturn;
}
