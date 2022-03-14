#pragma once

#include "core/array.hpp"
#include "core/stringview.hpp"
#include "token.hpp"

struct Tokenizer {
	auto tokenize(StringView source) -> Array<Token>;
private:
	auto next() -> void;
	auto peek() -> char;
	auto eof() -> bool;
	auto skipWhitespace() -> void;
	auto skipComments() -> void;
	auto readToken(Token& token) -> bool;

	auto isKeyword(Token& token) -> bool;
	auto isVariable(Token& token) -> bool;
	auto isIdentifier(Token& token) -> bool;
	auto isStringLiteral(Token& token) -> bool;
	auto isIntegerLiteral(Token& token) -> bool;
	auto isOperator(Token& token) -> bool;

	Array<Token>* tokens;
	StringView source;
	size_t current;
	size_t end;
	size_t currentColumn;
	size_t currentRow;
};
