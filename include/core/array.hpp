#pragma once

#include "core/buffer.hpp"

template<typename Value>
struct Array {
	Array() : buffer(0) {
	};
	Array(size_t amount) : buffer(amount) {
	}
	Array(size_t amount, const Value& value) : buffer(amount) {
		mem::fill(buffer, value);
	}

	auto resize(size_t newSize) -> void {
		if(newSize <= capacity()) {
			currentSize = newSize;
			return;
		}

		Buffer<Value> newBuffer(newSize);
		mem::copy(buffer, newBuffer);
		buffer = newBuffer;
		currentSize = newSize;
	}

	auto reserve(size_t newCapacity) -> void {
		if(newCapacity <= capacity()) {
			return;
		}

		Buffer<Value> newBuffer(newCapacity);
		mem::copy(buffer, newBuffer);
		buffer = newBuffer;
	}

	auto append(const Value& toAppend) -> void {
		if(capacity() == size()) {
			grow();
		}

		buffer[currentSize] = toAppend;
		currentSize++;
	}

	auto pop() -> void {
		assert(size() > 0);
		currentSize--;
	}

	auto clear() -> void {
		currentSize = 0;
	}

	auto size() const -> size_t {
		return currentSize;
	}

	auto capacity() const -> size_t {
		return buffer.size();
	}

	auto operator[](size_t index) -> Value& {
		assert(index < currentSize);
		return buffer[index];
	}

	auto operator[](size_t index) const  -> const Value& {
		assert(index < currentSize);
		return buffer[index];
	}

	auto begin() -> Value* {
		return buffer.begin();
	}

	auto end() -> Value* {
		return buffer.begin() + currentSize;
	}

	auto begin() const -> const Value* {
		return buffer.begin();
	}

	auto end() const -> const Value* {
		return buffer.begin() + currentSize;
	}

	auto data() -> Value* {
		return buffer.data();
	}

	auto data() const -> const Value* {
		return buffer.data();
	}

private:
	auto grow() -> void {
		size_t newCapacity = buffer.size() * 2;
		if(newCapacity == 0) {
			newCapacity = 4;
		}
		Buffer<Value> newBuffer(newCapacity);
		mem::copy(buffer, newBuffer);
		buffer = newBuffer;
	}

	Buffer<Value> buffer;
	size_t currentSize = 0;

};
