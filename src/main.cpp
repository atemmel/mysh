#include "core/file.hpp"

#include "tokenizer.hpp"

auto main() -> int {
	auto source = file::readAll("../test/source.mysh");
	Tokenizer tokenizer;
	auto tokens = tokenizer.tokenize(source);

	auto lastToken = tokens[tokens.size() -1];

	for(const auto& token : tokens) {
		println(token);
	}
}
