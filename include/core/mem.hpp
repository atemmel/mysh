#pragma once

#include "core/assert.hpp"
#include "core/print.hpp"

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
	auto n = source.size();
	assert(n <= destination.size());

	for(decltype(n) i = 0; i < n; i++) {
		destination[i] = source[i];
	}
}

template<typename SrcIterator, typename DestIterator>
auto copy(SrcIterator begin, SrcIterator end, DestIterator dest) -> void {
	for(; begin != end; ++begin) {
		*dest = *begin;
		dest++;
	}
}

template<typename ContainerA, typename ContainerB>
auto equal(const ContainerA& lhs, ContainerB& rhs) -> bool {
	const auto n = lhs.size();
	assert(n <= rhs.size());
	
	for(decltype(n) i = 0; i < n; i++) {
		if(!(lhs[i] == rhs[i])) {
			return false;
		}
	}
	return true;
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
