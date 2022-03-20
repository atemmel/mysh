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
	auto readNewline() -> bool;
	auto skipWhitespace() -> void;
	auto skipComments() -> void;
	auto readKeyword() -> bool;
	auto readVariable() -> bool;
	auto readIdentifier() -> bool;
	auto readBareword() -> bool;
	auto readStringLiteral() -> bool;
	auto readIntegerLiteral() -> bool;
	auto readSymbol() -> bool;

	Array<Token>* tokens;
	StringView source;
	size_t current;
	size_t end;
	size_t currentColumn;
	size_t currentRow;
};
