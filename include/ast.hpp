#pragma once

#include "core/array.hpp"
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

struct StringLiteralNode : public AstNode {
	StringLiteralNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct BoolLiteralNode : public AstNode {
	BoolLiteralNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct DeclarationNode : public AstNode {
	DeclarationNode(const Token* token);
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

struct AssignmentNode : public AstNode {
	AssignmentNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct FunctionCallNode : public AstNode {
	FunctionCallNode(const Token* token);
	auto accept(AstVisitor& visitor) -> void;
};

struct RootNode : public AstNode {
	RootNode();
	auto accept(AstVisitor& visitor) -> void;
};

using AstRoot = OwnPtr<RootNode>;

struct AstVisitor {
	virtual ~AstVisitor() = default;
	virtual auto visit(IdentifierNode& node) -> void = 0;
	virtual auto visit(StringLiteralNode& node) -> void = 0;
	virtual auto visit(BoolLiteralNode& node) -> void = 0;
	virtual auto visit(DeclarationNode& node) -> void = 0;
	virtual auto visit(VariableNode& node) -> void = 0;
	virtual auto visit(BranchNode& node) -> void = 0;
	virtual auto visit(ScopeNode& node) -> void = 0;
	virtual auto visit(AssignmentNode& node) -> void = 0;
	virtual auto visit(FunctionCallNode& node) -> void = 0;
	virtual auto visit(RootNode& node) -> void = 0;
};

struct AstParser {
	auto parse(const Array<Token>& tokens) -> AstRoot;
private:
	auto parseStatement() -> Child;
	auto parseFunctionCall() -> Child;
	auto parseDeclaration() -> Child;
	auto parseExpr() -> Child;
	auto parseIdentifier() -> Child;
	auto parseVariable() -> Child;
	auto parseBranch() -> Child;
	auto parseScope(bool endsWithNewline = true) -> Child;
	auto parseAssignment() -> Child;
	auto parseStringLiteral() -> Child;
	auto parseBoolLiteral() -> Child;

	auto eot() const -> bool;
	auto getIf(Token::Kind kind) -> const Token*;

	const Array<Token>* tokens = nullptr;
	size_t current = 0;
};
