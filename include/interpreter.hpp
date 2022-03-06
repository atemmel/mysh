#pragma once

#include "ast.hpp"
#include "core/array.hpp"
#include "symtable.hpp"

struct Interpreter : public AstVisitor {
	auto interpret(RootNode& root) -> bool;
	auto visit(IdentifierNode& node) -> void override;
	auto visit(StringLiteralNode& node) -> void override;
	auto visit(DeclarationNode& node) -> void override;
	auto visit(VariableNode& node) -> void override;
	auto visit(AssignmentNode& node) -> void override;
	auto visit(FunctionCallNode& node) -> void override;
	auto visit(RootNode& node) -> void override;
private:

	auto executeFunction(StringView identifier,
		const Array<StringView>& args) -> void;

	SymTable symTable;
	Array<StringView> collectedStrings;
};