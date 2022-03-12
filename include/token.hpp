#pragma once

#include "core/staticarray.hpp"
#include "core/stringview.hpp"

struct Token {
	enum struct Kind {
		Newline,		// \n
		VarKeyword,		// var
		False,			// false
		True,			// true
		Equals,			// =
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
		"Equals",
		"Variable",
		"StringLiteral",
		"Identifier",
	};

	static constexpr StaticArray<StringView, (size_t)Kind::NTokens> Strings = {
		"\n",
		"var",
		"false",
		"true",
		"=",
		"",
		"",
		"",
	};

	static constexpr size_t KeywordBegin = 1;
	static constexpr size_t KeywordEnd = 4;

	static constexpr size_t OperatorBegin = 4;
	static constexpr size_t OperatorEnd = 5;

	static auto isOperator(StringView view) -> bool;

	Kind kind;
	StringView value;
	size_t column;
	size_t row;
};

auto fprintType(FILE* desc, const Token& token) -> void;
