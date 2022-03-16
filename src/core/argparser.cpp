#include "core/argparser.hpp"

#include "core/assert.hpp"
#include "core/staticarray.hpp"
#include "core/print.hpp"

auto ArgParser::flag(bool* result, 
		StringView flagName, 
		StringView helpText) -> void {
	assert(result != nullptr);
	flags.append(Flag{
		.type = Flag::Type::Boolean,
		.ptr = (void*)result,
		.flagName = flagName,
		.helpText = helpText,
	});
}

auto ArgParser::parse(int argc, char** argv) -> void {
	checkHelp(argc, argv);

	for(int i = 1; i < argc; ++i) {
		auto index = flagIndex(argv[i]);
		if(index == -1) {
			otherArgs.append(argv[i]);
			continue;
		}

		handleFlag(argv[i], index);
	}
}

auto ArgParser::args() const -> const Array<StringView>& {
	return otherArgs;
}

auto ArgParser::flagIndex(const char* arg) -> size_t {
	for(size_t i = 0; i < flags.size(); ++i) {
		if(flags[i].flagName == arg) {
			return i;
		}
	}
	return -1;
}

auto ArgParser::handleFlag(const char* arg,
		size_t flagIndex) -> void {
	auto& flag = flags[flagIndex];

	switch(flag.type) {
		case Flag::Type::Boolean:
			bool* ptr = (bool*)flag.ptr;
			*ptr = true;
			break;
	}
}

auto ArgParser::checkHelp(int argc, char** argv) const -> void {
	StaticArray<StringView, 4> helps = {
		"--help",
		"-help",
		"help",
		"-h",
	};

	for(int index = 1; index < argc; ++index) {
		for(auto help : helps) {
			if(argv[index] == help) {
				printHelp(argv);
				exit(EXIT_SUCCESS);
			}
		}
	}
}

auto ArgParser::printHelp(char** argv) const -> void {
	auto exeName = argv[0];
	println(exeName, "usage:");
	for(const auto& flag : flags) {
		fprintf(stdout, "  ");
		fprintType(stdout, flag.flagName);

		switch(flag.type) {
			case Flag::Type::Boolean:
				fprintf(stdout, ": bool");
				break;
		}

		fprintf(stdout, "  ");
		fprintType(stdout, flag.helpText);
	}

	fprintf(stdout, "\n");
}
