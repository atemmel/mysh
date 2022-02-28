#pragma once

auto assertCall(const char* file, const int line, const char* function) -> void;

#undef assert

#ifndef NDEBUG
#define assert(x) \
	if (!(x)) { \
		assertCall(__FILE__, __LINE__, __PRETTY_FUNCTION__); \
	}
#else
#define assert(x) (void(0))
#endif
