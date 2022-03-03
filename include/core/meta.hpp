#pragma once

template<typename Type>
struct RemoveReference { 
	typedef Type type; 
};

template<typename Type>
struct RemoveReference<Type&> { 
	typedef Type type; 
};

template<typename Type>
struct RemoveReference<Type&&> { 
	typedef Type type; 
};

template<typename Value>
constexpr Value&& forward(typename RemoveReference<Value>::type& value) noexcept {
      return static_cast<Value&&>(value);
}

template<typename Value>
constexpr Value&& forward(typename RemoveReference<Value>::type&& value) noexcept {
      return static_cast<Value&&>(value);
}
