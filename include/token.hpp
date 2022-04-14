#pragma once

#include "core/staticarray.hpp"
#include "core/stringview.hpp"

struct Token {
	enum struct Kind {
		Newline,		// \n
		VarKeyword,		// var
		FnKeyword,		// fn
		False,			// false
		True,			// true
		If,				// if
		Else,			// else
		While,			// while
		Return,			// return
		Assign,			// =
		Add,			// +
		Subtract,		// -
		Multiply,		// *
		Divide,			// /
		Modulo,			// %
		Less,			// <
		Greater,		// >
		Bang,			// !
		Equals,			// ==
		NotEquals,		// !=
		GreaterEquals,	// >=
		LessEquals,		// <=
		And,			// &
		Or,				// |
		LogicalAnd,		// &&
		LogicalOr,		// ||
		LeftBrace,		// {
		RightBrace,		// }
		LeftPar,		// (
		RightPar,		// )
		LeftBrack,		// [
		RightBrack,		// ]
		Variable,		// $hello
		StringLiteral,	// "hello"
		Identifier,		// hello
		Bareword,		// --help
		IntegerLiteral,	// 123678
		NTokens,		// keep this last
	};

	static constexpr StaticArray<StringView, (size_t)Kind::NTokens> PrintableStrings = {
		"Newline",
		"VarKeyword",
		"FnKeyword",
		"False",
		"True",
		"If",
		"Else",
		"While",
		"Return",
		"Assign",
		"Add",
		"Subtract",
		"Multiply",
		"Divide",
		"Modulo",
		"Less",
		"Greater",
		"Bang",
		"Equals",
		"NotEquals",
		"EqualsGreater",
		"EqualsLess",
		"And",
		"Or",
		"LogicalAnd",
		"LogicalOr",
		"LeftBrace",
		"RightBrace",
		"LeftPar",
		"RightPar",
		"LeftBrack",
		"RightBrack",
		"Variable",
		"StringLiteral",
		"Identifier",
		"Bareword",
		"IntegerLiteral",
	};

	static constexpr StaticArray<StringView, (size_t)Kind::NTokens> Strings = {
		"\n",
		"var",
		"fn",
		"false",
		"true",
		"if",
		"else",
		"while",
		"return",
		"=",
		"+",
		"-",
		"*",
		"/",
		"%",
		"<",
		">",
		"!",
		"==",
		"!=",
		"<=",
		">=",
		"&",
		"|",
		"&&",
		"||",
		"{",
		"}",
		"(",
		")",
		"[",
		"]",
		"",
		"",
		"",
		"",
		"",
	};

	static constexpr StaticArray<int, (size_t)Kind::NTokens> Precedences = {
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		16,		// =
		6,		// +
		6,		// -
		5,		// *
		5,		// /
		5,		// %
		9,		// <
		9,		// >
		3,		// !
		10,		// ==
		10,		// !=
		9,		// <=
		9,		// >=
		11,		// &
		13,		// |
		14,		// &&
		15,		// ||
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
	};

	static constexpr size_t KeywordBegin = 1;
	static constexpr size_t KeywordEnd = 9;

	static constexpr size_t OperatorBegin = 9;
	static constexpr size_t OperatorEnd = 32;

	static auto isOperator(StringView view) -> bool;

	auto precedence() const -> int;

	Kind kind;
	StringView value;
	size_t column;
	size_t row;
};

auto fprintType(FILE* desc, Token::Kind kind) -> void;
auto fprintType(FILE* desc, const Token& token) -> void;
