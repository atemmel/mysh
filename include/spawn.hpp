#pragma once

#include "core/array.hpp"
#include "core/optional.hpp"
#include "core/stringview.hpp"

struct SpawnResult {
	int code;
	String out;
};

struct SpawnOptions {
	const Array<String>& args;
	Optional<StringView> stdinView;
	bool captureStdout;
};

auto spawn(const SpawnOptions& input) -> SpawnResult;
