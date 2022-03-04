#include "core/argparser.hpp"
#include "core/file.hpp"
#include "globals.hpp"

#include "tokenizer.hpp"

auto doEverything(StringView path) {
	auto source = file::readAll(path);
	Tokenizer tokenizer;
	auto tokens = tokenizer.tokenize(source);

	auto lastToken = tokens[tokens.size() -1];

	for(const auto& token : tokens) {
		println(token);
	}
}

auto main(int argc, char** argv) -> int {
	ArgParser parser;
	parser.flag(&globals::verbose,
		"--verbose",
		"Enable verbose mode");
	parser.parse(argc, argv);
	auto args = parser.args();

	if(args.size() > 0) {
		auto path = args[0];
		doEverything(path);
		return EXIT_SUCCESS;
	}

	errprintln("No file specified, exiting...");
	return EXIT_FAILURE;
}
