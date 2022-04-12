#pragma once

#include "core/array.hpp"
#include "core/hashtable.hpp"
#include "core/ownptr.hpp"
#include "token.hpp"

struct AstNode;
struct AstVisitor;
using Child = OwnPtr<AstNode>;

struct AstNode {
	AstNode(const Token* token);
	virtual ~AstNode() = default;
	virtual auto accept(AstVisitor& visitor) -> void = 0;
	auto addChild(Child& child) -> void;
	Array<Child> children;
	const Token* token;
};

struct IdentifierNode : public AstNode {
	IdentifierNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct BarewordNode : public AstNode {
	BarewordNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct StringLiteralNode : public AstNode {
	StringLiteralNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct BoolLiteralNode : public AstNode {
	BoolLiteralNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct IntegerLiteralNode : public AstNode {
	IntegerLiteralNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
	int64_t value = 0;
};

struct DeclarationNode : public AstNode {
	DeclarationNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct FnDeclarationNode : public AstNode {
	FnDeclarationNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
	Array<const Token*> args;
};

struct ReturnNode : public AstNode {
	ReturnNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct VariableNode : public AstNode {
	VariableNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct ScopeNode : public AstNode {
	ScopeNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct BranchNode : public AstNode {
	BranchNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
	Child expression;
	Child statement;
};

struct LoopNode : public AstNode {
	LoopNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
	Child init;
	Child condition;
	Child step;
};

struct AssignmentNode : public AstNode {
	AssignmentNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct BinaryOperatorNode : public AstNode {
	BinaryOperatorNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct UnaryOperatorNode : public AstNode {
	UnaryOperatorNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct FunctionCallNode : public AstNode {
	FunctionCallNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct RootNode : public AstNode {
	RootNode();
	auto accept(AstVisitor& visitor) -> void;
	HashTable<StringView, OwnPtr<FnDeclarationNode>> functions;
};

using AstRoot = OwnPtr<RootNode>;

struct AstVisitor {
	virtual ~AstVisitor() = default;
	virtual auto visit(IdentifierNode& node) -> void = 0;
	virtual auto visit(BarewordNode& node) -> void = 0;
	virtual auto visit(StringLiteralNode& node) -> void = 0;
	virtual auto visit(BoolLiteralNode& node) -> void = 0;
	virtual auto visit(IntegerLiteralNode& node) -> void = 0;
	virtual auto visit(DeclarationNode& node) -> void = 0;
	virtual auto visit(FnDeclarationNode& node) -> void = 0;
	virtual auto visit(ReturnNode& node) -> void = 0;
	virtual auto visit(VariableNode& node) -> void = 0;
	virtual auto visit(BranchNode& node) -> void = 0;
	virtual auto visit(LoopNode& node) -> void = 0;
	virtual auto visit(ScopeNode& node) -> void = 0;
	virtual auto visit(AssignmentNode& node) -> void = 0;
	virtual auto visit(BinaryOperatorNode& node) -> void = 0;
	virtual auto visit(UnaryOperatorNode& node) -> void = 0;
	virtual auto visit(FunctionCallNode& node) -> void = 0;
	virtual auto visit(RootNode& node) -> void = 0;
};

struct AstParser {
	auto parse(const Array<Token>& tokens) -> AstRoot;

	auto error() const -> bool;
	auto dumpError() -> void;
private:
	enum struct ExpectableThings {
		Expression,
		Scope,
		Callable,
		NExpectableThings,
	};

	constexpr static StaticArray<StringView, (size_t)ExpectableThings::NExpectableThings> ExpectableStrings = {
		"Expression",
		"Scope",
		"Callable",
	};

	auto parseStatement() -> Child;
	auto parseFunctionCall() -> Child;
	auto parseFunctionCallExpr() -> Child;
	auto parseDeclaration() -> Child;
	auto parseFnDeclaration() -> Child;
	auto parseReturn() -> Child;
	auto parseExpr(bool trailingNewline = false) -> Child;
	auto parsePrimaryExpr() -> Child;
	auto parseIdentifier() -> Child;
	auto parseBareword() -> Child;
	auto parseVariable() -> Child;
	auto parseBranch() -> Child;
	auto parseLoop() -> Child;
	auto parseScope(bool endsWithNewline = true, bool mayReturn = false) -> Child;
	auto parseAssignment() -> Child;
	auto parseBinaryExpression() -> Child;
	auto parseBinaryOperator() -> Child;
	auto parseUnaryExpression() -> Child;
	auto parseUnaryOperator() -> Child;
	auto parseStringLiteral() -> Child;
	auto parseBoolLiteral() -> Child;
	auto parseIntegerLiteral() -> Child;

	auto eot() const -> bool;
	auto getIf(Token::Kind kind) -> const Token*;
	auto expected(Token::Kind kind) -> Child;
	auto expected(ExpectableThings expectable) -> Child;

	Token::Kind whatWeWanted = Token::Kind::NTokens;
	ExpectableThings whatWeWanted2 = ExpectableThings::NExpectableThings;
	const Token* whatWeGot = nullptr;
	const Array<Token>* tokens = nullptr;
	size_t current = 0;
};
