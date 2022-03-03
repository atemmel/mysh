#include "core/assert.hpp"
#include "core/print.hpp"
#include "core/mem.hpp"
#include "core/array.hpp"
#include "core/buffer.hpp"
#include "core/list.hpp"

struct Nugget {
	float spiciness;
	float friedness;
	int value;
	bool vego;
};

auto myprint(List<int> numbers) -> void {
	for(const auto& e : numbers) {
		println("There!", e);
	}
}

auto main() -> int {
	//println("Gaming", 'h', 4, 3.145f, 3.145);
	//errprintln("this is error :)");
	//println("Gaming");
	//assert(true);

	/*
	Buffer<Nugget> nuggets(20);

	mem::fill(nuggets, sample);

	for(auto& nugget : nuggets) {
		println("friedness:", nugget.friedness, 
				"spiciness:", nugget.spiciness,
				"value:", nugget.value,
				"vego:", nugget.vego);
	}
	*/

	/*
	auto sample = Nugget{
		.spiciness = 0.2,
		.friedness = 0.4,
		.value = 60,
		.vego = false,
	};

	
	Array<Nugget> nuggets;
	nuggets.resize(4);

	println("Before append:", nuggets.size(), nuggets.capacity());

	nuggets.append(sample);

	println("After append:", nuggets.size(), nuggets.capacity());
	nuggets.append(sample);

	println("After append:", nuggets.size(), nuggets.capacity());
	nuggets.append(sample);

	println("After append:", nuggets.size(), nuggets.capacity());
	nuggets.append(sample);

	println("After append:", nuggets.size(), nuggets.capacity());
	nuggets.append(sample);

	println("After append:", nuggets.size(), nuggets.capacity());
	nuggets.append(sample);

	println("After append:", nuggets.size(), nuggets.capacity());
	*/

	/*
	Array<int> numbers;
	numbers.reserve(5);
	for(int i = 0; i < 5; i++) {
		numbers.append(i);
	}
	println(numbers);
	*/

	List<int> numbers;
	for(int i = 0; i < 5; i++) {
		numbers.append(i);
	}
	myprint(numbers);
}
