#pragma once

template<typename Value>
void swap(Value& a, Value& b) {
	auto c = b;
	b = a;
	a = c;
}
