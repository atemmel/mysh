#pragma once

#include "core/assert.hpp"
#include "core/meta.hpp"
#include "core/mem.hpp"

#include <memory>

template<typename Value>
struct OwnPtr {
	OwnPtr() : ptr(nullptr) {};

	OwnPtr(nullptr_t null) : OwnPtr() {};

	template<typename OtherValue>
	OwnPtr(OtherValue* ptr) : ptr(ptr) {};

	OwnPtr(const OwnPtr&) = delete;

	OwnPtr(OwnPtr&& other) : ptr(other.disown()) {
	}

	template<typename OtherValue>
	OwnPtr(OwnPtr<OtherValue>&& other) : ptr(other.disown()) {
	}

	template<typename ...Params>
	static auto create(Params... params) -> OwnPtr<Value> {
		return OwnPtr<Value>(mem::alloc<Value>(
			forward<Params>(params)...));
	}

	~OwnPtr() {
		free();
	}

	auto operator=(const OwnPtr&) = delete;

	auto operator=(OwnPtr&& rhs) -> void {
		swap(ptr, rhs.ptr);
	}

	auto free() -> void {
		mem::free(ptr);
		ptr = nullptr;
	}

	auto disown() -> Value* {
		auto copy = ptr;
		ptr = nullptr;
		return copy;
	}

	auto get() -> Value* {
		return ptr;
	}

	auto get() const -> const Value* {
		return ptr;
	}

	auto operator*() -> Value& {
		assert(ptr);
		return *ptr;
	}

	auto operator*() const -> const Value& {
		assert(ptr);
		return *ptr;
	}

	auto operator->() -> Value* {
		assert(ptr);
		return ptr;
	}

	auto operator->() const -> const Value* {
		assert(ptr);
		return ptr;
	}

private:
	Value* ptr = nullptr;
};

template<typename Value>
auto operator==(const OwnPtr<Value>& lhs, const OwnPtr<Value>& rhs) -> bool{
	return lhs.get() == rhs.get();
}

template<typename Value>
auto operator==(const OwnPtr<Value>& lhs, const Value* rhs) -> bool{
	return lhs.get() == rhs;
}

template<typename Value>
auto operator==(const Value* lhs, const OwnPtr<Value>& rhs) -> bool{
	return rhs.get() == lhs;
}

template<typename Value>
auto operator==(const OwnPtr<Value>& lhs, nullptr_t rhs) -> bool{
	return lhs.get() == rhs;
}

template<typename Value>
auto operator==(nullptr_t lhs, const OwnPtr<Value>& rhs) -> bool{
	return lhs == rhs.get();
}
