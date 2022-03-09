#pragma once

#include "core/assert.hpp"

#include <stdlib.h>

namespace mem {

template<typename Container, typename Value>
constexpr auto fill(Container& container, const Value& value) -> void {
	for(auto& element : container) {
		element = value;
	}
}

template<typename SrcIterator, typename DestIterator>
constexpr auto copy(SrcIterator begin, SrcIterator end, DestIterator dest) -> void {
	for(; begin != end; ++begin) {
		*dest = *begin;
		dest++;
	}
}

template<typename ContainerA, typename ContainerB>
constexpr auto copy(const ContainerA& source, ContainerB& destination) -> void {
	mem::copy(source.begin(), source.end(), destination.begin());
}

template<typename SrcIterator, typename DestIterator>
constexpr auto moveRange(SrcIterator begin, SrcIterator end, DestIterator dest) -> void {
	for(; begin != end; ++begin) {
		*dest = move(*begin);
		dest++;
	}
}

template<typename ContainerA, typename ContainerB>
constexpr auto moveRange(ContainerA& source, ContainerB& dest) -> void {
	mem::moveRange(source.begin(), source.end(), dest.begin());
}

template<typename ContainerA, typename ContainerB>
constexpr auto equal(const ContainerA& lhs, ContainerB& rhs) -> bool {
	auto lit = lhs.begin();
	auto rit = rhs.begin();
	for(; lit != lhs.end() && rit != rhs.end(); ++lit, ++rit) {
		if(!(*lit == *rit)) {
			return false;
		}
	}
	return lit == lhs.end() && rit == rhs.end();
}

template<typename Value>
auto alloc() -> Value* {
	return new Value;
}

template<typename Value, typename ...Params>
auto alloc(Params... params) -> Value* {
	return new Value(forward<Params>(params)...);
}

template<typename Value>
auto allocN(size_t amount) -> Value* {
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
