#pragma once

#include "ast.hpp"
#include "core/array.hpp"
#include "core/optional.hpp"
#include "symtable.hpp"

struct Interpreter : public AstVisitor {
	auto interpret(RootNode& root) -> bool;
	auto visit(IdentifierNode& node) -> void override;
	auto visit(StringLiteralNode& node) -> void override;
	auto visit(BoolLiteralNode& node) -> void override;
	auto visit(IntegerLiteralNode& node) -> void override;
	auto visit(DeclarationNode& node) -> void override;
	auto visit(VariableNode& node) -> void override;
	auto visit(BranchNode& node) -> void override;
	auto visit(ScopeNode& node) -> void override;
	auto visit(AssignmentNode& node) -> void override;
	auto visit(BinaryOperatorNode& node) -> void override;
	auto visit(FunctionCallNode& node) -> void override;
	auto visit(RootNode& node) -> void override;
private:

	auto addValues(const Value& lhs, const Value& rhs) -> Value;
	auto subtractValues(const Value& lhs, const Value& rhs) -> Value;
	auto executeFunction(StringView identifier,
		const Array<Value>& args) -> Optional<Value>;

	Array<Value> collectedValues;
	const VariableNode* lastVisitedVariable;
	SymTable symTable;
};
