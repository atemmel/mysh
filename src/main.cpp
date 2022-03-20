#include "core/argparser.hpp"
#include "core/file.hpp"
#include "core/print.hpp"

#include "ast.hpp"
#include "astprinter.hpp"
#include "globals.hpp"
#include "interpreter.hpp"
#include "tokenizer.hpp"
#include "core/hashtable.hpp"

auto doEverything(StringView path) {
	auto source = file::readAll(path);
	Tokenizer tokenizer;

	// make tokens
	auto tokens = tokenizer.tokenize(source);

	if(globals::verbose) {
		for(const auto& token : tokens) {
			println(token);
		}
	}

	// build AST
	AstParser parser;
	auto root = parser.parse(tokens);
	if(root == nullptr) {
		println("main: No root :(");
		parser.dumpError();
		exit(EXIT_FAILURE);
	}

	if(globals::verbose) {
		AstPrinter printer;
		println("Printing AST:");
		root->accept(printer);
	}

	// exec code
	Interpreter interpreter;
	interpreter.interpret(*root);
}

auto main(int argc, char** argv) -> int {
	globals::init();

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
