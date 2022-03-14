#pragma once

#include "core/assert.hpp"
#include "core/meta.hpp"

template<typename Value>
struct Optional {
	Optional() = default;
	Optional(const Value& value) 
	: theValue(value), attained(true) {}
	Optional(Value&& value) 
	: theValue(move(value)), attained(true) {}

	auto operator=(const Value& value) -> void {
		theValue = value;
		attained = true;
	}

	auto operator=(Value&& value) -> void {
		theValue = value;
		attained = true;
	}

	auto hasValue() const -> bool {
		return attained;
	}

	auto disown() -> void {
		~theValue();
		attained = false;
	}

	auto value() -> Value& {
		assert(attained);
		return theValue;
	}

	auto value() const -> const Value& {
		assert(attained);
		return theValue;
	}

private:
	Value theValue;
	bool attained = false;
};
