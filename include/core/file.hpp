#pragma once

#include "core/string.hpp"
#include "core/stringview.hpp"

namespace file {
	// reads all contents from path
	// returns empty string on failure
	auto readAll(StringView path) -> String;

	// writes all of contents into file at path
	// returns if operation succeeded
	auto writeAll(StringView path, StringView contents) -> bool;
};
