#pragma once

#include "core/buffer.hpp"

template<typename Value>
struct Array {
	Array() : buffer(0) {}

	Array(size_t amount) : buffer(amount), currentSize(amount) {}

	Array(size_t amount, const Value& value) : buffer(amount) {
		mem::fill(buffer, value);
	}

	Array(const Array& other) 
		: buffer(other.buffer), currentSize(other.currentSize) {}

	Array(Array&& other) 
		: buffer(move(other.buffer)), currentSize(other.currentSize) {
		other.currentSize = 0;
	}

	auto operator=(const Array& other) -> void {
		if(size() < other.size()) {
			buffer = other.buffer;
			currentSize = other.size();
		} else {
			currentSize = other.size();
			mem::copy(other, buffer);
		}
	}

	auto operator=(Array&& other) -> void {
		swap(currentSize, other.currentSize);
		buffer.swap(other.buffer);
	}

	auto resize(size_t newSize) -> void {
		if(newSize <= capacity()) {
			currentSize = newSize;
			return;
		}

		Buffer<Value> newBuffer(newSize);
		mem::moveRange(buffer, newBuffer);
		buffer = move(newBuffer);
		currentSize = newSize;
	}

	auto reserve(size_t newCapacity) -> void {
		if(newCapacity <= capacity()) {
			return;
		}

		Buffer<Value> newBuffer(newCapacity);
		mem::moveRange(buffer, newBuffer);
		buffer = move(newBuffer);
	}

	auto append(const Value& toAppend) -> void {
		if(capacity() == size()) {
			grow();
		}

		buffer[currentSize] = toAppend;
		currentSize++;
	}

	auto append(Value&& toAppend) -> void {
		if(capacity() == size()) {
			grow();
		}

		buffer[currentSize] = move(toAppend);
		currentSize++;
	}

	auto remove(size_t index) -> void {
		assert(index >= 0);
		assert(index < size());
		mem::moveRange(begin() + index + 1, end(), begin() + index);
		pop();
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

	auto empty() const -> bool {
		return currentSize == 0;
	}

private:
	auto grow() -> void {
		size_t newCapacity = buffer.size() * 2;
		if(newCapacity == 0) {
			newCapacity = 4;
		}
		Buffer<Value> newBuffer(newCapacity);
		mem::moveRange(buffer, newBuffer);
		buffer = move(newBuffer);
	}

	Buffer<Value> buffer;
	size_t currentSize = 0;

};
