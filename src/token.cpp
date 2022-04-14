#include "token.hpp"

#include "core/print.hpp"

auto Token::isOperator(StringView view) -> bool {
	auto i = Token::OperatorBegin;

	for(; i < Token::OperatorEnd; ++i) {
		if(view == Token::Strings[i]) {
			return true;
		}
	}

	return false;
}

auto Token::precedence() const -> int {
	auto prec = Token::Precedences[(size_t)kind];
	return prec;
}

auto fprintType(FILE* desc, Token::Kind kind) -> void {
	fprintType(desc, Token::PrintableStrings[(size_t)kind]);
}

auto fprintType(FILE* desc, const Token& token) -> void {
	fprintf(desc, "Row: ");
	fprintType(desc, token.row);
	fprintf(desc, ", Column: ");
	fprintType(desc, token.column);
	fprintf(desc, ", Kind: ");
	fprintType(desc, Token::PrintableStrings[(size_t)token.kind]);
	if(!token.value.empty()) {
		fprintf(desc, ", Value: ");
		if(token.kind == Token::Kind::Newline) {
			fprintf(desc, "\\n");
		} else {
			fprintType(desc, token.value);
		}
	}
}
