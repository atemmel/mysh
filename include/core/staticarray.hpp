#pragma once

#include "core/assert.hpp"
#include "core/initializerlist.hpp"
#include "core/mem.hpp"

#include <stdlib.h>

template<typename Value, size_t Size>
struct StaticArray {
	StaticArray() = default;

	constexpr StaticArray(InitializerList<Value> list) {
		mem::copy(list, *this);
	}
	
	constexpr auto operator[](size_t index) -> Value& {
		return arr[index];
	}

	constexpr auto operator[](size_t index) const -> const Value& {
		return arr[index];
	}

	constexpr auto size() const -> size_t {
		return Size;
	}

	constexpr auto begin() -> Value* {
		return &arr[0];
	}

	constexpr auto end() -> Value* {
		return begin() + Size;
	}

	constexpr auto begin() const -> const Value* {
		return &arr[0];
	}

	constexpr auto end() const -> const Value* {
		return begin() + Size;
	}

	constexpr auto data() -> Value* {
		return &arr[0];
	}

	constexpr auto data() const -> const Value* {
		return &arr[0];
	}
	
	constexpr auto empty() const -> bool {
		return Size == 0;
	}
private:

	Value arr[Size];
};
