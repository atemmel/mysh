#include "ast.hpp"

#include "core/meta.hpp"
#include "core/print.hpp"

#include <memory>

AstNode::AstNode(const Token* token) : token(token) {

}

auto AstNode::addChild(Child& child) -> void {
	children.append(move(child));
}

IdentifierNode::IdentifierNode(const Token* token)
	: AstNode(token) {
	
}
auto IdentifierNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

StringLiteralNode::StringLiteralNode(const Token* token)
	: AstNode(token) {

}
auto StringLiteralNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

BoolLiteralNode::BoolLiteralNode(const Token* token)
	: AstNode(token) {

}
auto BoolLiteralNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

DeclarationNode::DeclarationNode(const Token* token) 
	: AstNode(token) {

}

auto DeclarationNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

VariableNode::VariableNode(const Token* token) 
	: AstNode(token) {

}

auto VariableNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

AssignmentNode::AssignmentNode(const Token* token) 
	: AstNode(token) {

}

auto AssignmentNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

FunctionCallNode::FunctionCallNode(const Token* token) 
	: AstNode(token) {

}

auto FunctionCallNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

RootNode::RootNode() : AstNode(nullptr) {
}

auto RootNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}


auto AstParser::parse(const Array<Token>& tokens) -> AstRoot {
	this->tokens = &tokens;

	auto root = OwnPtr<RootNode>::create();
	while(!eot()) {
		if(auto child = parseFunctionCall();
			child != nullptr) {
			root->addChild(child);
			continue;
		}

		if(auto child = parseDeclaration(); 
			child != nullptr) {
			root->addChild(child);
			continue;
		}

		if(auto child = parseAssignment();
			child != nullptr) {
			root->addChild(child);
			continue;
		}

		println("");
		println("");
		println(tokens[current]);
		println("");
		println("");
		assert(false);
	}

	return root;
}

auto AstParser::parseFunctionCall() -> Child {
	auto checkpoint = current;
	auto token = getIf(Token::Kind::Identifier);
	if(token == nullptr) {
		return nullptr;
	}

	Child node = OwnPtr<FunctionCallNode>::create(token);

	Child child = parseExpr();
	while(child != nullptr) {
		node->addChild(child);
		child = parseExpr();
	}

	if(!eot()) {
		assert(getIf(Token::Kind::Newline) != nullptr);
	}

	return node;
}

auto AstParser::parseDeclaration() -> Child {
	auto token = getIf(Token::Kind::VarKeyword);
	if(token == nullptr) {
		return nullptr;
	}

	auto identifier = getIf(Token::Kind::Identifier);
	if(identifier == nullptr) {
		//TODO: Print error message
		println("failure 1");
		return nullptr;
	}

	if(getIf(Token::Kind::Equals) == nullptr) {
		//TODO: Print error message
		println("failure 2");
		return nullptr;
	}

	auto expr = parseExpr();
	if(expr == nullptr) {
		//TODO: Print error message
		println("failure 3");
		return nullptr;
	}

	if(!eot()) {
		assert(getIf(Token::Kind::Newline) != nullptr);
	}

	Child decl = OwnPtr<DeclarationNode>::create(identifier);
	decl->addChild(expr);

	return decl;
}

auto AstParser::parseExpr() -> Child {
	if(auto identifier = parseIdentifier(); 
		identifier != nullptr) {
		return identifier;
	}
	if(auto variable = parseVariable(); 
		variable != nullptr) {
		return variable;
	}
	if(auto stringLiteral = parseStringLiteral();
		stringLiteral != nullptr) {
		return stringLiteral;
	}
	if(auto boolLiteral = parseBoolLiteral();
		boolLiteral != nullptr) {
		return boolLiteral;
	}
	return nullptr;
}

auto AstParser::parseIdentifier() -> Child {
	auto token = getIf(Token::Kind::Identifier);
	if(token == nullptr) {
		return nullptr;
	}
	return OwnPtr<IdentifierNode>::create(token);
}

auto AstParser::parseVariable() -> Child {
	auto token = getIf(Token::Kind::Variable);
	if(token == nullptr) {
		return nullptr;
	}
	return OwnPtr<VariableNode>::create(token);
}

auto AstParser::parseAssignment() -> Child {
	auto checkpoint = current;
	auto variable = parseVariable();
	if(variable == nullptr) {
		return nullptr;
	}


	auto equals = getIf(Token::Kind::Equals);
	if(equals == nullptr) {
		current = checkpoint;
		return nullptr;
	}

	auto expr = parseExpr();
	if(expr == nullptr) {
		//TODO: expected expression
		assert(false);
		return nullptr;
	}

	auto newline = getIf(Token::Kind::Newline);
	if(newline == nullptr) {
		//TODO: expected newline
		assert(false);
		return nullptr;
	}

	auto assign = OwnPtr<AssignmentNode>::create(equals);
	assign->children.reserve(2);
	assign->addChild(variable);
	assign->addChild(expr);
	return assign;
}

auto AstParser::parseStringLiteral() -> Child {
	auto token = getIf(Token::Kind::StringLiteral);
	if(token == nullptr) {
		return nullptr;
	}
	return OwnPtr<StringLiteralNode>::create(token);
}

auto AstParser::parseBoolLiteral() -> Child {
	if(auto fals = getIf(Token::Kind::False); fals != nullptr) {
		return OwnPtr<BoolLiteralNode>::create(fals);
	}
	if(auto tru = getIf(Token::Kind::True); tru != nullptr) {
		return OwnPtr<BoolLiteralNode>::create(tru);
	}
	return nullptr;
}

auto AstParser::eot() const -> bool {
	return current >= tokens->size();
}

auto AstParser::getIf(Token::Kind kind) -> const Token* {
	if(!eot() && (*tokens)[current].kind == kind) {
		auto ptr = &(*tokens)[current];
		++current;
		return ptr;
	}
	return nullptr;
}
