#include "astprinter.hpp"

#include "core/print.hpp"

auto AstPrinter::visit(IdentifierNode& node) -> void {
	pad();
	println("IdentifierNode:", node.token->value);
}

auto AstPrinter::visit(BarewordNode& node) -> void {
	pad();
	println("BarewordNode:", node.token->value);
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

auto AstPrinter::visit(ArrayLiteralNode& node) -> void {
	pad();
	println("IntegerLiteralNode []:");
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
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

auto AstPrinter::visit(FnDeclarationNode& node) -> void {
	pad();
	println("FnDeclarationNode:", node.token->value);
	++depth;
	pad();
	println("Args:");
	++depth;
	for(auto arg : node.args) {
		pad();
		println(arg->value);
	}
	--depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
}

auto AstPrinter::visit(ReturnNode& node) -> void {
	pad();
	println("ReturnNode:");
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
}

auto AstPrinter::visit(VariableNode& node) -> void {
	pad();
	println("VariableNode:", node.token->value);
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
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

auto AstPrinter::visit(LoopNode& node) -> void {
	pad();
	println("Loop node:");
	++depth;
	if(node.condition != nullptr) {
		if(node.init != nullptr) {
			node.init->accept(*this);
		} else {
			pad();
			println("No init");
		}
		node.condition->accept(*this);
		if(node.step != nullptr) {
		node.step->accept(*this);
		} else {
			pad();
			println("No step");
		}
	} else if(node.iterator != nullptr) {
		node.iterator->accept(*this);
		if(node.iterable != nullptr) {
			node.iterable->accept(*this);
		}
	}
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	depth -= 2;
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
	if(node.token->precedence() > 0) {
		pad();
		println(" Precedence:", node.token->precedence());
	}
	++depth;
	for(auto& child : node.children) {
		child->accept(*this);
	}
	--depth;
}

auto AstPrinter::visit(UnaryOperatorNode& node) -> void {
	pad();
	println("UnaryOperatorNode:", node.token->value);
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
	pad();
	println("Functions:");
	for(auto& child : node.functions) {
		visit(*child.value);
	}
	pad();
	println("Statements:");
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
