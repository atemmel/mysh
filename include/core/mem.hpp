#pragma once

#include "core/assert.hpp"

#include <stdlib.h>

namespace mem {

template<typename Container, typename Value>
auto fill(Container& container, const Value& value) -> void {
	for(auto& element : container) {
		element = value;
	}
}

template<typename ContainerA, typename ContainerB>
auto copy(const ContainerA& source, ContainerB& destination) -> void {
	const auto n = source.size();
	assert(n >= destination.size());

	for(decltype(n) i = 0; i < n; i++) {
		destination[i] = source[i];
	}
}

template<typename Value>
auto alloc() -> Value* {
	return new Value;
}

template<typename Value>
auto alloc(size_t amount) -> Value* {
	return new Value[amount];
}

template<typename Value>
auto free(Value* ptr) -> void {
	delete ptr;
}

template<typename Value>
auto freeN(Value* ptr) -> void {
	delete [] ptr;
}

}
