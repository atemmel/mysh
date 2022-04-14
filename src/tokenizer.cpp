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

		if(readNewline()) {
			continue;
		}

		if(isspace(c) && c != '\n') {
			skipWhitespace();
			continue;
		}
		if(c == '#') {
			skipComments();
			continue;
		}

		if(readVariable()
			|| readKeyword()
			|| readIdentifier()
			|| readSymbol()
			|| readStringLiteral()
			|| readIntegerLiteral()
			|| readBareword()) {
			continue;
		}

		assert(false);
	}

	return tokens;
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

auto Tokenizer::peek() -> char {
	assert(current < end);
	return source[current];
}

auto Tokenizer::eof() -> bool {
	return current >= end;
}

auto Tokenizer::readNewline() -> bool {
	char c = peek();
	if(c != '\n') {
		return false;
	}
	if(tokens->empty()) {
		next();
		return true;
	}
	if((*tokens)[tokens->size() - 1].kind == Token::Kind::Newline) {
		next();
		return true;
	}
	tokens->append(Token{
		.kind = Token::Kind::Newline,
		.value = source.view(current, current + 1),
		.column = currentColumn,
		.row = currentRow,
	});
	next();
	return true;
}

auto Tokenizer::skipWhitespace() -> void {
	while(isspace(peek()) && peek() != '\n') {
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

	if(!eof()) {
		next();
	}
}

auto Tokenizer::readKeyword() -> bool {
	auto oldCurrent = current;
	auto oldCol = currentColumn;
	auto oldRow = currentRow;

	for(auto c = peek(); !eof() ; next()) {
		c = peek();
		if(!isalpha(c)) {
			break;
		}
	}

	if(oldCurrent == current) {
		return false;
	}

	auto view = source.view(oldCurrent, current);

	size_t keywordIndex = Token::KeywordBegin;
	for(; keywordIndex < Token::KeywordEnd; ++keywordIndex) {
		if(view == Token::Strings[keywordIndex]) {
			break;
		}
	}

	if(keywordIndex == Token::KeywordEnd) {
		current = oldCurrent;
		currentColumn = oldCol;
		currentRow = oldRow;
		return false;
	}

	tokens->append(Token{
		.kind = (Token::Kind)keywordIndex,
		.value = view,
		.column = oldCol,
		.row = oldRow,
	});
	return true;
}

auto Tokenizer::readVariable() -> bool {
	auto oldCurrent = current;
	auto oldCol = currentColumn;
	auto oldRow = currentRow;
	if(peek() != '$') {
		return false;
	}
	next();

	auto c = peek();
	// must begin with a letter
	if(!isalpha(c)) {
		return false;
	}

	for(; !eof() ; next()) {
		c = peek();
		if(!isalnum(c) && c != '_') {
			break;
		}
	}

	tokens->append(Token{
		.kind = Token::Kind::Variable,
		.value = source.view(oldCurrent + 1, current),
		.column = oldCol,
		.row = oldRow,
	});
	return true;
}

auto Tokenizer::readIdentifier() -> bool {
	auto oldCurrent = current;
	auto oldCol = currentColumn;
	auto oldRow = currentRow;

	auto c = peek();
	// must begin with a letter
	if(!isalpha(c)) {
		return false;
	}
	
	next();

	for(; !eof() ; next()) {
		c = peek();
		if(!isalnum(c) && c != '_') {
			break;
		}
	}

	// bad identifier :(
	if(c == '-' || c == '+' || c == '/' || c == '*') {
		current = oldCurrent;
		currentColumn = oldCol;
		currentRow = oldRow;
		return false;
	}

	// good identifier :)
	tokens->append(Token{
		.kind = Token::Kind::Identifier,
		.value = source.view(oldCurrent, current),
		.column = oldCol,
		.row = oldRow,
	});
	return true;
}

auto Tokenizer::readBareword() -> bool {
	auto oldCurrent = current;
	auto oldCol = currentColumn;
	auto oldRow = currentRow;
	for(auto c = peek(); !eof(); next()) {
		c = peek();
		if(isspace(c)) {
			break;
		}
		//TODO: handle forward slashes
		// \n, \t, etc...
	}
	tokens->append(Token{
		.kind = Token::Kind::Bareword,
		.value = source.view(oldCurrent, current),
		.column = oldCol,
		.row = oldRow,
	});
	return true;
}

auto Tokenizer::readStringLiteral() -> bool {
	auto oldCurrent = current;
	auto oldCol = currentColumn;
	auto oldRow = currentRow;

	if(peek() != '"') {
		return false;
	}

	next();

	while(!eof() && peek() != '"') {
		if(peek() == '\\') {
			next();
			if(!eof()) {
				next();
				continue;
			}
		}
		next();
	}

	if(eof()) {
		//TODO: handle unterminated string literal
		assert(false);
	}

	tokens->append(Token{
		.kind = Token::Kind::StringLiteral,
		.value = source.view(oldCurrent + 1, current),
		.column = oldCol,
		.row = oldRow,
	});
	next();
	return true;
}

auto Tokenizer::readIntegerLiteral() -> bool {
	// leading negation (-)
	// -1
	// first char
	// - 0 1 2 3 4 5 6 7 8 9
	// if leading negation + not digit
	if(peek() == '-' && current + 1 < source.size() 
		&& !isdigit(source[current + 1])) {
		return false;
	}

	// if not leading negation + not digit
	if(peek() != '-' && !isdigit(peek())) {
		return false;
	}
	
	auto oldCurrent = current;
	auto oldCol = currentColumn;
	auto oldRow = currentRow;

	next();

	// all the others
	// 0 1 2 3 4 5 6 7 8 9
	while(!eof() && isdigit(peek())) {
		next();
	}

	tokens->append(Token{
		.kind = Token::Kind::IntegerLiteral,
		.value = source.view(oldCurrent, current),
		.column = oldCol,
		.row = oldRow,
	});

	if(eof()) {
		return true;
	}

	if(isspace(peek())) {
		return true;
	}

	auto upcoming = source.view(current, current + 1);
	if(Token::isOperator(upcoming)) {
		return true;
	}

	tokens->pop();
	current = oldCurrent;
	currentColumn = oldCol;
	currentRow = oldRow;
	return false;
}

auto Tokenizer::readSymbol() -> bool {
	auto oldCurrent = current;
	auto oldCol = currentColumn;
	auto oldRow = currentRow;

	auto upcoming = source.view(current, current + 1);
	auto index = Token::OperatorBegin;
	for(; index < Token::OperatorEnd; ++index) {
		if(upcoming == Token::Strings[index]) {
			break;
		}
	}

	if(index == Token::OperatorEnd) {
		return false;
	}

	next();

	//TODO: handle special cases
	// ==, <=, >=, !=, etc...
	switch((Token::Kind)index) {
		case Token::Kind::Subtract:
		case Token::Kind::Add:
		case Token::Kind::Multiply:
		case Token::Kind::Divide:
			if(isalpha(peek())) {
				current = oldCurrent;
				currentColumn = oldCol;
				currentRow = oldRow;
				return false;
			}
			break;
		case Token::Kind::Assign:
		case Token::Kind::Bang:
		case Token::Kind::Less:
		case Token::Kind::Greater:
			if(!eof() && peek() == '=') {
				switch((Token::Kind)index) {
					case Token::Kind::Assign:
						index = (size_t)Token::Kind::Equals;
						break;
					case Token::Kind::Bang:
						index = (size_t)Token::Kind::NotEquals;
						break;
					case Token::Kind::Less:
						index = (size_t)Token::Kind::LessEquals;
						break;
					case Token::Kind::Greater:
						index = (size_t)Token::Kind::GreaterEquals;
						break;
					default:
						assert(false);
				}
				next();
			}
		case Token::Kind::And:
			if(!eof() && peek() == '&') {
				index = (size_t)Token::Kind::LogicalAnd;
				next();
			}
			break;
		case Token::Kind::Or:
			if(!eof() && peek() == '|') {
				index = (size_t)Token::Kind::LogicalOr;
				next();
			}
			break;
		default:
			break;
	}

	tokens->append(Token{
		.kind = (Token::Kind)index,
		.value = source.view(oldCurrent, current),
		.column = oldCol,
		.row = oldRow,
	});
	return true;
}
