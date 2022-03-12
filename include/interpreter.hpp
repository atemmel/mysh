#pragma once

#include "ast.hpp"
#include "core/array.hpp"
#include "symtable.hpp"

struct Interpreter : public AstVisitor {
	auto interpret(RootNode& root) -> bool;
	auto visit(IdentifierNode& node) -> void override;
	auto visit(StringLiteralNode& node) -> void override;
	auto visit(BoolLiteralNode& node) -> void override;
	auto visit(DeclarationNode& node) -> void override;
	auto visit(VariableNode& node) -> void override;
	auto visit(AssignmentNode& node) -> void override;
	auto visit(FunctionCallNode& node) -> void override;
	auto visit(RootNode& node) -> void override;
private:

	auto executeFunction(StringView identifier,
		const Array<Value>& args) -> void;

	Array<Value> collectedValues;
	const VariableNode* lastVisitedVariable;
	SymTable symTable;
};
