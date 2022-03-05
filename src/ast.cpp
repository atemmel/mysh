#include "ast.hpp"

#include "core/meta.hpp"

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
		auto child = parseFunctionCall();
		if(child != nullptr) {
			root->addChild(child);
			continue;
		}

		assert(false);
	}

	return root;
}

auto AstParser::parseFunctionCall() -> Child {
	auto token = getIf(Token::Kind::Identifier);
	if(token == nullptr) {
		return nullptr;
	}

	Child node = OwnPtr<FunctionCallNode>::create(token);

	Child child = parseIdentifier();
	while(child != nullptr) {
		node->addChild(child);
		child = parseIdentifier();
	}

	if(!eot()) {
		assert(getIf(Token::Kind::Newline) != nullptr);
	}

	return node;
}

auto AstParser::parseIdentifier() -> Child {
	auto token = getIf(Token::Kind::Identifier);
	if(token == nullptr) {
		return nullptr;
	}
	return OwnPtr<IdentifierNode>::create(token);
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
