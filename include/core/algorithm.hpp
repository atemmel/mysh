#pragma once

#include "core/meta.hpp"

template<typename Value>
void swap(Value& a, Value& b) {
	auto c = move(b);
	b = move(a);
	a = move(c);
}

template<typename Value>
constexpr auto max(Value value) -> Value {
	return value;
}

template<typename Value, typename ...Values>
constexpr auto max(Value lhs, Values... values) -> Value {
	auto rhs = max(forward<Values>(values)...);
	return lhs < rhs ? rhs : lhs;
}

template<typename Value>
constexpr auto min(Value value) -> Value {
	return value;
}

template<typename Value, typename ...Values>
constexpr auto min(Value lhs, Values... values) -> Value {
	auto rhs = min(forward<Values>(values)...);
	return lhs < rhs ? lhs : rhs;
}
