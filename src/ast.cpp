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

IntegerLiteralNode::IntegerLiteralNode(const Token* token) 
	: AstNode(token) {

}
auto IntegerLiteralNode::accept(AstVisitor& visitor) -> void {
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

ScopeNode::ScopeNode(const Token* token) 
	: AstNode(token) {

}
auto ScopeNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

BranchNode::BranchNode(const Token* token) 
	: AstNode(token) {

}

auto BranchNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

AssignmentNode::AssignmentNode(const Token* token) 
	: AstNode(token) {

}

auto AssignmentNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

BinaryOperatorNode::BinaryOperatorNode(const Token* token)
	: AstNode(token) {

}

auto BinaryOperatorNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

UnaryOperatorNode::UnaryOperatorNode(const Token* token) 
	: AstNode(token) {

}

auto UnaryOperatorNode::accept(AstVisitor& visitor) -> void {
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
		if(auto child = parseStatement();
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

auto AstParser::parseStatement() -> Child {
	if(auto child = parseFunctionCall();
		child != nullptr) {
		return child;
	}

	if(auto child = parseDeclaration(); 
		child != nullptr) {
		return child;
	}

	if(auto child = parseAssignment();
		child != nullptr) {
		return child;
	}

	if(auto child = parseScope();
		child != nullptr) {
		return child;
	}

	if(auto child = parseBranch();
		child != nullptr) {
		return child;
	}

	return nullptr;
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
	if(auto bin = parseBinaryExpression();
		bin != nullptr) {
		return bin;
	}
	if(auto un = parseUnaryExpression();
		un != nullptr) {
		return un;
	}
	if(auto expr = parsePrimaryExpr();
		expr != nullptr) {
		return expr;
	}
	return nullptr;
}

auto AstParser::parsePrimaryExpr() -> Child {
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
	if(auto integerLiteral = parseIntegerLiteral();
		integerLiteral != nullptr) {
		return integerLiteral;
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

auto AstParser::parseBranch() -> Child {
	auto branchBegin = getIf(Token::Kind::If);
	if(branchBegin == nullptr) {
		return nullptr;
	}

	auto expr = parseExpr();
	if(expr == nullptr){
		assert(false);
	}

	auto branch = OwnPtr<BranchNode>::create(branchBegin);
	branch->expression = move(expr);

	auto scope = parseScope(false);
	if(scope == nullptr) {
		assert(false);
	}

	branch->statement = move(scope);

	// single if
	if(eot() || getIf(Token::Kind::Newline) != nullptr) {
		return branch;
	}

	// else could mean:
	if(getIf(Token::Kind::Else) != nullptr) {
		// if else check
		if(auto child = parseBranch();
			child != nullptr) {
			branch->addChild(child);
			return branch;
		// solo else check
		} else if(auto child = parseScope();
			child != nullptr) {
			branch->addChild(child);
			return branch;
		}
	}
	
	assert(false);
	return nullptr;
}

auto AstParser::parseScope(bool endsWithNewline) -> Child {
	auto checkpoint = current;
	auto lbrace = getIf(Token::Kind::LeftBrace);
	if(lbrace == nullptr) {
		return nullptr;
	}

	if(getIf(Token::Kind::Newline) == nullptr) {
		current = checkpoint;
		return nullptr;
	}

	auto scope = OwnPtr<ScopeNode>::create(lbrace);

	while(true) {
		if(auto stmnt = parseStatement();
			stmnt != nullptr) {
			scope->addChild(stmnt);
			continue;
		}

		if(auto rbrace = getIf(Token::Kind::RightBrace);
			rbrace != nullptr) {
			break;
		}

		//TODO: poor candidate for statement
		assert(false);
		return nullptr;
	}

	if(endsWithNewline) {
		if(!eot()) {
			assert(getIf(Token::Kind::Newline) != nullptr);
		}
	}

	return scope;
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

auto AstParser::parseBinaryExpression() -> Child {
	auto checkpoint = current;
	auto lhs = parsePrimaryExpr();
	if(lhs == nullptr) {
		return nullptr;
	}

	auto op = parseBinaryOperator();
	if(op == nullptr) {
		current = checkpoint;
		return nullptr;
	}

	auto rhs = parseExpr();
	if(rhs == nullptr) {
		//TODO: more error handling
		assert(false);
		return nullptr;
	}

	op->addChild(lhs);
	op->addChild(rhs);

	return op;
};

auto AstParser::parseBinaryOperator() -> Child {
	if(eot()) {
		return nullptr;
	}
	switch((*tokens)[current].kind) {
		case Token::Kind::Add:
		case Token::Kind::Subtract:
		case Token::Kind::Less:
		case Token::Kind::Greater:
			break;
		default:
			return nullptr;
	}

	auto token = &(*tokens)[current];
	auto op = OwnPtr<BinaryOperatorNode>::create(token);
	++current;

	return op;
}

auto AstParser::parseUnaryExpression() -> Child {
	auto checkpoint = current;
	auto unary = parseUnaryOperator();
	if(unary == nullptr) {
		return nullptr;
	}

	auto expr = parseExpr();

	if(expr == nullptr) {
		//TODO: expect expression here
		current = checkpoint;
		return nullptr;
	}

	unary->addChild(expr);
	return unary;
}

auto AstParser::parseUnaryOperator() -> Child {
	if(eot()) {
		return nullptr;
	}
	switch((*tokens)[current].kind) {
		case Token::Kind::Subtract:
		case Token::Kind::Bang:
			break;
		default:
			return nullptr;
	}

	auto token = &(*tokens)[current];
	auto op = OwnPtr<UnaryOperatorNode>::create(token);
	++current;

	return op;
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

auto AstParser::parseIntegerLiteral() -> Child {
	auto token = getIf(Token::Kind::IntegerLiteral);
	if(token == nullptr) {
		return nullptr;
	}

	auto integer = OwnPtr<IntegerLiteralNode>::create(token);
	//TODO: replace builtin
	//TODO: handle error
	auto value = strtol(token->value.data(), nullptr, 10);
	integer->value = value;
	return integer;
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
