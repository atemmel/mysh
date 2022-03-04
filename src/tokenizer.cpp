#include "tokenizer.hpp"

#include <ctype.h>

auto Tokenizer::tokenize(StringView source) -> Array<Token> {
	Array<Token> tokens;
	this->tokens = &tokens;
	this->source = source;
	this->current = 0;
	this->end = source.size();
	this->currentRow = 1;
	this->currentColumn = 1;

	while(!eof()) {
		char c = peek();
		if(isspace(c)) {
			skipWhitespace();
			continue;
		}
		if(c == '#') {
			skipComments();
			continue;
		}


		Token token;
		auto success = readToken(token);
		if(!success) {
			break;
		}
		tokens.append(token);
	}

	return tokens;
}

auto Tokenizer::peek() -> char {
	assert(current < end);
	return source[current];
}

auto Tokenizer::next() -> void {
	assert(current < end);
	if(source[current] == '\n') {
		++currentRow;
		currentColumn = 0;
	}
	++current;
	++currentColumn;
}

auto Tokenizer::eof() -> bool {
	return current >= end;
}

auto Tokenizer::skipWhitespace() -> void {
	while(isspace(peek())) {
		next();
	}
}

auto Tokenizer::skipComments() -> void {
	if(peek() != '#') {
		return;
	}

	while(!eof() && peek() != '\n') {
		next();
	}
	next();
}

auto Tokenizer::readToken(Token& token) -> bool {
	size_t prevCurrent = current;
	token.column = currentColumn;
	token.row = currentRow;

	while(!eof() && !isspace(peek())) {
		auto view = source.view(current, current + 1);
		if(prevCurrent < current && Token::isOperator(view)) {
			break;
		}
		next();

		view = source.view(prevCurrent, current);
		if(Token::isOperator(view)) {
			break;
		}
	}

	// if we could not create a token
	if(prevCurrent == current) {
		return false;
	}

	token.kind = Token::Kind::Variable;
	token.value = source.view(prevCurrent, current);

	if(isKeyword(token)) {
		return true;
	}

	if(isOperator(token)) {
		return true;
	}

	if(isStringLiteral(token)) {
		return true;
	}

	if(isVariable(token)) {
		return true;
	}

	if(isIdentifier(token)) {
		return true;
	}

	// otherwise, the token is unrecognized
	return false;
}

auto Tokenizer::isKeyword(Token& token) -> bool {
	size_t keywordIndex = Token::KeywordBegin;
	for(; keywordIndex < Token::KeywordEnd; ++keywordIndex) {
		if(token.value == Token::Strings[keywordIndex]) {
			token.kind = (Token::Kind)keywordIndex;
			return true;
		}
	}
	return false;
}

auto Tokenizer::isVariable(Token& token) -> bool {
	auto firstChar = token.value[0];

	if(firstChar != '$') {
		return false;
	}

	auto v = token.value;
	token.value = StringView(v.begin() + 1, v.end());
	token.kind = Token::Kind::Variable;

	return true;
}

auto Tokenizer::isIdentifier(Token& token) -> bool {
	token.kind = Token::Kind::Identifier;
	return true;
}

auto Tokenizer::isStringLiteral(Token& token) -> bool {
	auto firstChar = token.value[0];
	auto lastChar = token.value[token.value.size() - 1];

	if(firstChar != '"' || lastChar != '"') {
		return false;
	}

	auto v = token.value;
	token.value = StringView(v.begin() + 1, v.end() - 1);
	token.kind = Token::Kind::StringLiteral;

	return true;
}

auto Tokenizer::isOperator(Token& token) -> bool {
	size_t operatorIndex = Token::OperatorBegin;
	for(; operatorIndex < Token::OperatorEnd; ++operatorIndex) {
		if(token.value == Token::Strings[operatorIndex]) {
			token.kind = (Token::Kind)operatorIndex;
			return true;
		}
	}
	return false;
}
