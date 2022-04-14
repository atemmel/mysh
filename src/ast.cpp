#include "ast.hpp"

#include "core/meta.hpp"
#include "core/print.hpp"

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

BarewordNode::BarewordNode(const Token* token)
	: AstNode(token) {
	
}
auto BarewordNode::accept(AstVisitor& visitor) -> void {
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

FnDeclarationNode::FnDeclarationNode(const Token* token) 
	: AstNode(token) {

}

auto FnDeclarationNode::accept(AstVisitor& visitor) -> void {
	visitor.visit(*this);
}

ReturnNode::ReturnNode(const Token* token) 
	: AstNode(token) {

}

auto ReturnNode::accept(AstVisitor& visitor) -> void {
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

LoopNode::LoopNode(const Token* token) 
	: AstNode(token) {
	
}

auto LoopNode::accept(AstVisitor& visitor) -> void {
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
		} else if(auto child = parseFnDeclaration();
			child != nullptr) {
			auto ptr = static_cast<FnDeclarationNode*>(child.disown());
			auto fn = OwnPtr<FnDeclarationNode>(ptr);
			root->functions.put(fn->token->value, 
				move(fn));
			continue;
		}

		assert(error());
		return nullptr;
	}

	return root;
}

auto AstParser::dumpError() -> void {
	if(whatWeGot == nullptr) {
		whatWeGot = &(*tokens)[tokens->size() - 1];
	}

	println("Error when parsing file");
	print("row:", whatWeGot->row, "column:", whatWeGot->column, "");

	// if not using whatWeWanted
	if(whatWeWanted == Token::Kind::NTokens) {
		// use whatWeWanted2
		print("expected:", ExpectableStrings[(size_t)whatWeWanted2]);
	} else {
		print("expected:", whatWeWanted);
	}

	if(!eot()) {
		print(", found:", whatWeGot->kind);
		switch(whatWeGot->kind) {
			case Token::Kind::Newline:
				println(" ( \\n )");
				break;
			default:
				println(" (", whatWeGot->value, ")");
				break;
		}
	} else {
		println(", found: end of file");
	}
}

auto AstParser::parseStatement() -> Child {
	auto checkpoint = current;
	if(auto child = parseFunctionCall();
		child != nullptr) {
		if((!eot() && getIf(Token::Kind::Newline) != nullptr) || eot()) {
			return child;
		}
		current = checkpoint;
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

	if(auto child = parseLoop();
		child != nullptr) {
		return child;
	}

	if(auto child = parseExpr(true);
		child != nullptr) {
		return child;
	}

	return nullptr;
}

auto AstParser::parseFunctionCall() -> Child {
	auto token = getIf(Token::Kind::Identifier);
	if(token == nullptr) {
		return nullptr;
	}

	Child node = OwnPtr<FunctionCallNode>::create(token);

	mayReadPipe = false;

	Child child = parseExpr();
	while(child != nullptr) {
		node->addChild(child);
		child = parseExpr();
	}

	mayReadPipe = true;

	// pipe chain check
	token = getIf(Token::Kind::Or);
	if(token != nullptr) {
		auto rhs = parseFunctionCall();
		if(rhs == nullptr) {
			return expected(ExpectableThings::Callable);
		}

		auto pipe = OwnPtr<BinaryOperatorNode>::create(token);
		pipe->addChild(node);
		pipe->addChild(rhs);
		return pipe;
	}

	return node;
}

auto AstParser::parseFunctionCallExpr() -> Child {
	auto checkpoint = current;
	auto token = getIf(Token::Kind::LeftPar);
	if(token == nullptr) {
		return nullptr;
	}

	auto call = parseFunctionCall();

	if(call == nullptr) {
		current = checkpoint;
		return nullptr;
	}

	if(getIf(Token::Kind::RightPar) == nullptr) {
		return expected(Token::Kind::LeftPar);
	}

	return call;
}

auto AstParser::parseDeclaration() -> Child {
	auto token = getIf(Token::Kind::VarKeyword);
	if(token == nullptr) {
		return nullptr;
	}

	auto identifier = getIf(Token::Kind::Identifier);
	if(identifier == nullptr) {
		return expected(Token::Kind::Identifier);
	}

	if(getIf(Token::Kind::Assign) == nullptr) {
		return expected(Token::Kind::Assign);
	}

	auto expr = parseExpr();
	if(expr == nullptr) {
		return expected(ExpectableThings::Expression);
	}

	if(!eot()) {
		if(getIf(Token::Kind::Newline) == nullptr) {
			return expected(Token::Kind::Newline);
		}
	}

	Child decl = OwnPtr<DeclarationNode>::create(identifier);
	decl->addChild(expr);

	return decl;
}

auto AstParser::parseFnDeclaration() -> Child {
	auto token = getIf(Token::Kind::FnKeyword);
	if(token == nullptr) {
		return nullptr;
	}

	auto identifier = getIf(Token::Kind::Identifier);
	if(identifier == nullptr) {
		return expected(Token::Kind::Identifier);
	}

	auto fn = OwnPtr<FnDeclarationNode>::create(identifier);

	for(const Token* arg = getIf(Token::Kind::Identifier); arg != nullptr;
			arg = getIf(Token::Kind::Identifier)) {
		fn->args.append(arg);
	}
	
	auto scope = parseScope(true, true);
	if(scope == nullptr) {
		return expected(ExpectableThings::Scope);
	}

	fn->addChild(scope);
	return fn;
}

auto AstParser::parseReturn() -> Child {
	auto token = getIf(Token::Kind::Return);
	if(token == nullptr) {
		return nullptr;
	}

	auto ret = OwnPtr<ReturnNode>::create(token);

	auto expr = parseExpr();
	if(expr != nullptr) {
		ret->addChild(expr);
	}

	if(getIf(Token::Kind::Newline) == nullptr) {
		return expected(Token::Kind::Newline);
	}

	return ret;
}

auto AstParser::parseExpr(bool trailingNewline) -> Child {
	if(auto bin = parseBinaryExpression();
		bin != nullptr) {
		if(trailingNewline && !eot() 
			&& getIf(Token::Kind::Newline) == nullptr) {
			return expected(Token::Kind::Newline);
		}
		return bin;
	}

	if(error()) {
		return nullptr;
	}
	if(auto expr = parsePrimaryExpr();
		expr != nullptr) {
		if(trailingNewline && !eot() 
			&& getIf(Token::Kind::Newline) == nullptr) {
			return expected(Token::Kind::Newline);
		}
		return expr;
	}
	return nullptr;
}

auto AstParser::parsePrimaryExpr() -> Child {
	if(auto un = parseUnaryExpression();
		un != nullptr) {
		return un;
	}
	if(auto call = parseFunctionCallExpr();
		call != nullptr) {
		return call;
	}
	if(auto identifier = parseIdentifier(); 
		identifier != nullptr) {
		return identifier;
	}
	if(auto bareword = parseBareword();
		bareword != nullptr) {
		return bareword;
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

auto AstParser::parseBareword() -> Child {
	auto token = getIf(Token::Kind::Bareword);
	if(token == nullptr) {
		return nullptr;
	}
	return OwnPtr<BarewordNode>::create(token);
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
		return expected(ExpectableThings::Expression);
	}

	auto branch = OwnPtr<BranchNode>::create(branchBegin);
	branch->expression = move(expr);

	auto scope = parseScope(false);
	if(scope == nullptr) {
		return expected(ExpectableThings::Scope);
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
	
	return expected(Token::Kind::Else);
}

auto AstParser::parseLoop() -> Child {
	auto token = getIf(Token::Kind::While);
	if(token == nullptr) {
		return nullptr;
	}

	auto loop = OwnPtr<LoopNode>::create(token);
	auto expr = parseExpr();
	if(expr == nullptr) {
		return expected(ExpectableThings::Expression);
	}

	loop->condition = move(expr);
	auto scope = parseScope();
	if(scope == nullptr) {
		return expected(ExpectableThings::Scope);
	}

	loop->addChild(scope);
	return loop;
}

auto AstParser::parseScope(bool endsWithNewline, bool mayReturn) -> Child {
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

		if(mayReturn) {
			if(auto ret = parseReturn();
				ret != nullptr) {
				scope->addChild(ret);
				continue;
			}
		}

		if(auto rbrace = getIf(Token::Kind::RightBrace);
			rbrace != nullptr) {
			break;
		}

		return expected(Token::Kind::RightBrace);
	}

	if(endsWithNewline) {
		if(!eot()) {
			if(getIf(Token::Kind::Newline) == nullptr) {
				return expected(Token::Kind::Newline);
			}
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

	auto equals = getIf(Token::Kind::Assign);
	if(equals == nullptr) {
		current = checkpoint;
		return nullptr;
	}

	auto expr = parseExpr();
	if(expr == nullptr) {
		return expected(ExpectableThings::Expression);
	}

	auto newline = getIf(Token::Kind::Newline);
	if(newline == nullptr) {
		return expected(Token::Kind::Newline);
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

	// pipe edge case, may only be followed by callables
	if(op->token->kind == Token::Kind::Or) {
		if(!mayReadPipe) {
			current = checkpoint;
			return nullptr;
		}
		auto rhs = parseFunctionCall();
		if(rhs == nullptr) {
			return expected(ExpectableThings::Callable);
		}
		op->addChild(lhs);
		op->addChild(rhs);
		return op;
	}

	auto rhs = parseExpr();
	if(rhs == nullptr) {
		return expected(ExpectableThings::Expression);
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
		case Token::Kind::Multiply:
		case Token::Kind::Divide:
		case Token::Kind::Less:
		case Token::Kind::Greater:
		case Token::Kind::Equals:
		case Token::Kind::NotEquals:
		case Token::Kind::GreaterEquals:
		case Token::Kind::LessEquals:
		case Token::Kind::LogicalAnd:
		case Token::Kind::LogicalOr:
		case Token::Kind::Or:
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

	auto expr = parsePrimaryExpr();

	if(expr == nullptr) {
		return expected(ExpectableThings::Expression);
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

auto AstParser::error() const -> bool {
	//return whatWeGot != nullptr;
	return whatWeGot != nullptr || whatWeWanted != Token::Kind::NTokens
		|| whatWeWanted2 != ExpectableThings::NExpectableThings;
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

auto AstParser::expected(Token::Kind kind) -> Child {
	if(error()) {
		return nullptr;
	}
	whatWeWanted = kind;
	if(!eot()) {
		whatWeGot = &(*tokens)[current];
	} else {
		whatWeGot = nullptr;
	}
	return nullptr;
}

auto AstParser::expected(ExpectableThings expectable) -> Child {
	if(error()) {
		return nullptr;
	}
	whatWeWanted2 = expectable;
	if(!eot()) {
		whatWeGot = &(*tokens)[current];
	} else {
		whatWeGot = nullptr;
	}
	return nullptr;
}
