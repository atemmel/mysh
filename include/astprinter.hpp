#pragma once

#include "ast.hpp"

struct AstPrinter : public AstVisitor {
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
private:
	auto pad() const -> void;
	size_t depth = 0;
};
