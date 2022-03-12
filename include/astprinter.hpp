#pragma once

#include "ast.hpp"

struct AstPrinter : public AstVisitor {
	auto visit(IdentifierNode& node) -> void override;
	auto visit(StringLiteralNode& node) -> void override;
	auto visit(BoolLiteralNode& node) -> void override;
	auto visit(DeclarationNode& node) -> void override;
	auto visit(VariableNode& node) -> void override;
	auto visit(AssignmentNode& node) -> void override;
	auto visit(FunctionCallNode& node) -> void override;
	auto visit(RootNode& node) -> void override;
private:
	auto pad() const -> void;
	size_t depth = 0;
};
