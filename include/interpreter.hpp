#pragma once

#include "ast.hpp"
#include "core/array.hpp"
#include "core/optional.hpp"
#include "symtable.hpp"

struct Interpreter : public AstVisitor {
	auto interpret(RootNode& root) -> bool;
	auto visit(IdentifierNode& node) -> void override;
	auto visit(BarewordNode& node) -> void override;
	auto visit(StringLiteralNode& node) -> void override;
	auto visit(BoolLiteralNode& node) -> void override;
	auto visit(IntegerLiteralNode& node) -> void override;
	auto visit(ArrayLiteralNode& node) -> void override;
	auto visit(DeclarationNode& node) -> void override;
	auto visit(FnDeclarationNode& node) -> void override;
	auto visit(ReturnNode& node) -> void override;
	auto visit(VariableNode& node) -> void override;
	auto visit(BranchNode& node) -> void override;
	auto visit(LoopNode& node) -> void override;
	auto visit(ScopeNode& node) -> void override;
	auto visit(AssignmentNode& node) -> void override;
	auto visit(BinaryOperatorNode& node) -> void override;
	auto visit(UnaryOperatorNode& node) -> void override;
	auto visit(FunctionCallNode& node) -> void override;
	auto visit(RootNode& node) -> void override;

	auto executeFunction(StringView identifier,
		const Array<Value>& args, Optional<const Value*> inArg) -> Optional<Value>;
private:
	auto doRegularLoop(LoopNode& node) -> void;
	auto doForInLoop(LoopNode& node) -> void;

	// arithmetic operators
	auto addValues(const Value& lhs, const Value& rhs) -> Value;
	auto subtractValues(const Value& lhs, const Value& rhs) -> Value;
	auto negateValue(const Value& operand) -> Value;
	auto multiplyValues(const Value& lhs, const Value& rhs) -> Value;
	auto divideValues(const Value& lhs, const Value& rhs) -> Value;
	auto moduloValues(const Value& lhs, const Value& rhs) -> Value;

	// logical operators
	auto lessValues(const Value& lhs, const Value& rhs) -> Value;
	auto greaterValues(const Value& lhs, const Value& rhs) -> Value;
	auto notValue(const Value& operand) -> Value;
	auto equalsValues(const Value& lhs, const Value& rhs) -> Value;
	auto notEqualsValues(const Value& lhs, const Value& rhs) -> Value;
	auto lessEqualsValues(const Value& lhs, const Value& rhs) -> Value;
	auto greaterEqualsValues(const Value& lhs, const Value& rhs) -> Value;
	auto logicalAndValues(const Value& lhs, const Value& rhs) -> Value;
	auto logicalOrValues(const Value& lhs, const Value& rhs) -> Value;


	// string operators
	auto escape(const Value& original) -> Value;
	auto interpolate(const Value& original) -> Value;
	auto interpolateDollar(const Value& original) -> Value;
	auto interpolateBraces(const Value& original) -> Value;

	// other operators
	auto pipe(Child& current, Child& next) -> Optional<Value>;

	auto executeUserDefinedFunction(FnDeclarationNode* func,
		const Array<Value>& args) -> Optional<Value>;

	RootNode* root;
	Array<Value> collectedValues;
	Array<Value> callArgs;
	Optional<Value> toReturn;
	const VariableNode* lastVisitedVariable;
	SymTable symTable;
	bool piping = false;
};
