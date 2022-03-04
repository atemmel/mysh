#pragma once

#include "core/staticarray.hpp"
#include "core/stringview.hpp"

struct Token {
	enum struct Kind {
		VarKeyword,		// var
		Equals,			// =
		Variable,		// $hello
		StringLiteral,	// "hello"
		Identifier,		// hello
		NTokens,		// keep this last
	};

	static constexpr StaticArray<StringView, (size_t)Kind::NTokens> PrintableStrings = {
		"VarKeyword",
		"Equals",
		"Variable",
		"StringLiteral",
		"Identifier",
	};

	static constexpr StaticArray<StringView, (size_t)Kind::NTokens> Strings = {
		"var",
		"=",
		"",
		"",
		"",
	};

	static constexpr size_t KeywordBegin = 0;
	static constexpr size_t KeywordEnd = 1;

	static constexpr size_t OperatorBegin = 1;
	static constexpr size_t OperatorEnd = 2;

	static auto isOperator(StringView view) -> bool;

	Kind kind;
	StringView value;
	size_t column;
	size_t row;
};

auto fprintType(FILE* desc, const Token& token) -> void;
