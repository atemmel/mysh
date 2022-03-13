#pragma once

#include "core/staticarray.hpp"
#include "core/stringview.hpp"

struct Token {
	enum struct Kind {
		Newline,		// \n
		VarKeyword,		// var
		False,			// false
		True,			// true
		If,				// if
		Else,			// else
		Equals,			// =
		LeftBrace,		// {
		RightBrace,		// }
		Variable,		// $hello
		StringLiteral,	// "hello"
		Identifier,		// hello
		NTokens,		// keep this last
	};

	static constexpr StaticArray<StringView, (size_t)Kind::NTokens> PrintableStrings = {
		"Newline",
		"VarKeyword",
		"False",
		"True",
		"If",
		"Else",
		"Equals",
		"LeftBrace",
		"RightBrace",
		"Variable",
		"StringLiteral",
		"Identifier",
	};

	static constexpr StaticArray<StringView, (size_t)Kind::NTokens> Strings = {
		"\n",
		"var",
		"false",
		"true",
		"if",
		"else",
		"=",
		"{",
		"}",
		"",
		"",
		"",
	};

	static constexpr size_t KeywordBegin = 1;
	static constexpr size_t KeywordEnd = 6;

	static constexpr size_t OperatorBegin = 6;
	static constexpr size_t OperatorEnd = 9;

	static auto isOperator(StringView view) -> bool;

	Kind kind;
	StringView value;
	size_t column;
	size_t row;
};

auto fprintType(FILE* desc, const Token& token) -> void;
