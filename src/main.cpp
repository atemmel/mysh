#include "core/assert.hpp"
#include "core/print.hpp"
#include "core/mem.hpp"
#include "core/buffer.hpp"

struct Nugget {
	float spiciness;
	float friedness;
	int value;
	bool vego;
};

auto main() -> int {
	//println("Gaming", 'h', 4, 3.145f, 3.145);
	//errprintln("this is error :)");
	//println("Gaming");
	//assert(true);

	Buffer<Nugget> nuggets(20);

	auto sample = Nugget{
		.spiciness = 0.2,
		.friedness = 0.4,
		.value = 60,
		.vego = false,
	};

	mem::fill(nuggets, sample);

	for(auto& nugget : nuggets) {
		println("friedness:", nugget.friedness, 
				"spiciness:", nugget.spiciness,
				"value:", nugget.value,
				"vego:", nugget.vego);
	}
}
