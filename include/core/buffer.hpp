#pragma once

#include "core/algorithm.hpp"
#include "core/mem.hpp"

template<typename Value>
struct Buffer {
	Buffer(size_t amount) 
		: beginPtr(mem::allocN<Value>(amount)),
		endPtr(beginPtr + amount){}

	Buffer(const Value* data, size_t amount) 
		: Buffer(amount) {
		mem::copy(data, data + amount, beginPtr);
	}

	~Buffer() {
		free();
	}

	Buffer(const Buffer<Value>& other) : Buffer(other.size()) {
		mem::copy(other, *this);
	}

	Buffer(Buffer<Value>&& other) {
		beginPtr = other.beginPtr;
		endPtr = other.endPtr;
		other.beginPtr = nullptr;
		other.endPtr = nullptr;
	}

	auto operator=(const Buffer<Value>& other) -> void {
		// prevent self assignment
		if(this == &other) {
			return;
		}

		Buffer copy(other);
		swap(copy);
	}

	auto operator=(Buffer<Value>&& other) -> void {
		swap(other);
	}

	auto operator==(const Buffer<Value>& rhs) const -> void {
		return mem::equal(*this, rhs);
	}

	auto swap(Buffer<Value>& other) -> void {
		::swap(beginPtr, other.beginPtr);
		::swap(endPtr, other.endPtr);
	}

	auto free() -> void {
		mem::freeN(beginPtr);
		beginPtr = nullptr;
		endPtr = nullptr;
	}

	auto size() const -> size_t {
		return endPtr - beginPtr;
	}

	auto operator[](size_t index) -> Value& {
		assert(index < size());
		return beginPtr[index];
	}

	auto operator[](size_t index) const  -> const Value& {
		assert(index < size());
		return beginPtr[index];
	}

	auto begin() -> Value* {
		return beginPtr;
	}

	auto end() -> Value* {
		return endPtr;
	}

	auto begin() const -> const Value* {
		return beginPtr;
	}

	auto end() const -> const Value* {
		return endPtr;
	}

	auto data() -> Value* {
		return beginPtr;
	}

	auto data() const -> const Value* {
		return beginPtr;
	}
	
	auto empty() const -> bool {
		return beginPtr == endPtr;
	}

private:
	Value* beginPtr = nullptr;
	Value* endPtr = nullptr;
};

