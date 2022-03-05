#pragma once

#include "core/meta.hpp"

template<typename Value>
void swap(Value& a, Value& b) {
	auto c = move(b);
	b = move(a);
	a = move(c);
}
