#include "astprinter.hpp"

#include "core/print.hpp"

auto AstPrinter::visit(IdentifierNode& node) -> void {
	pad();
	println("IdentifierNode:", node.token->value);
}

auto AstPrinter::visit(StringLiteralNode& node) -> void {
	pad();
	println("StringLiteralNode:", node.token->value);
}

auto AstPrinter::visit(BoolLiteralNode& node) -> void {
	pad();
	println("BoolLiteralNode:", node.token->kind == Token::Kind::True);
}

auto AstPrinter::visit(IntegerLiteralNode& node) -> void {
	pad();
	println("IntegerLiteralNode:", node.value);
}

auto AstPrinter::visit(DeclarationNode& node) -> void {
	pad();
	println("DeclarationNode:", node.token->value);
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
}

auto AstPrinter::visit(VariableNode& node) -> void {
	pad();
	println("VariableNode:", node.token->value);
}

auto AstPrinter::visit(BranchNode& node) -> void {
	pad();
	println("Branch node:");
	++depth;
	node.expression->accept(*this);
	++depth;
	node.statement->accept(*this);
	--depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
}

auto AstPrinter::visit(ScopeNode& node) -> void {
	pad();
	println("ScopeNode:");
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
}

auto AstPrinter::visit(AssignmentNode& node) -> void {
	pad();
	println("AssignmentNode:");
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
}

auto AstPrinter::visit(BinaryOperatorNode& node) -> void {
	pad();
	println("BinaryOperatorNode:", node.token->value);
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
}

auto AstPrinter::visit(FunctionCallNode& node) -> void {
	pad();
	println("FunctionCallNode:", node.token->value);
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
}

auto AstPrinter::visit(RootNode& node) -> void {
	pad();
	println("RootNode");
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
}

auto AstPrinter::pad() const -> void {
	for(size_t i = 0; i < depth; ++i) {
		fprintf(stdout, "  ");
	}
}
