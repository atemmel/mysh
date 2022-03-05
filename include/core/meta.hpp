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

template <typename Value>
typename RemoveReference<Value>::type&& move(Value&& arg)
{
  return static_cast<typename RemoveReference<Value>::type&&>(arg);
}

using nullptr_t = decltype(nullptr);
