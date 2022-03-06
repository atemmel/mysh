#include "core/assert.hpp"

#include "core/stacktrace.hpp"

#include <stdio.h>
#include <stdlib.h>

auto assertCall(const char* file, const int line, const char* function) -> void {
	char stacktrace[4096];
	StackTrace::dump(stacktrace, sizeof(stacktrace));
	fprintf(stderr, 
		"Assertion failed in:\nfile:%s, line:%d, "
		"function:%s\nstacktrace:\n\n%s",
		file, line, function, stacktrace);
	exit(EXIT_FAILURE);
}
