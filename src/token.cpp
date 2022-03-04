#include "token.hpp"

auto Token::isOperator(StringView view) -> bool {
	auto i = Token::OperatorBegin;

	for(; i < Token::OperatorEnd; ++i) {
		if(view == Token::Strings[i]) {
			return true;
		}
	}

	return false;
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
		fprintType(desc, token.value);
	}
}
