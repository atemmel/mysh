#include "core/assert.hpp"
#include "core/print.hpp"

auto main() -> int {
	println("Gaming", 'h', 4, 3.145f, 3.145);
	errprintln("this is error :)");
	//println("Gaming");
	assert(true);
}
