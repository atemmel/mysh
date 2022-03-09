#pragma once

#include "core/algorithm.hpp"
#include "core/mem.hpp"

#include <stdio.h>

template<typename Value>
struct List {
private:
		struct Node;
public:
	struct Iterator;
	struct ConstIterator;

	List() : head(nullptr) {};

	~List() {
		clear();
	}

	List(const List& other) {
		auto otherPtr = other.head;
		while(otherPtr != nullptr) {
			append(otherPtr->value);
			otherPtr = otherPtr->next;
		}
	}

	List(List&& other) {
		head = other.head;
		other.head = nullptr;
	}

	auto operator=(const List& rhs) -> void {
		if(this == &rhs) {
			return;
		}

		List<Value> copy(rhs);
		swap(*this, copy);
	}

	auto operator=(List&& rhs) -> void {
		swap(rhs);
	}

	auto swap(List& other) -> void {
		::swap(head, other.head);
	}

	auto append(const Value& value) -> void {
		auto node = mem::alloc<Node>();
		node->value = value;

		if(head == nullptr) {
			head = node;
			return;
		}

		auto ptr = head;
		while(ptr->next != nullptr) {
			ptr = ptr->next;
		}

		ptr->next = node;
	}

	auto remove(ConstIterator it) -> bool {
		auto ptr = head;
		while(ptr != nullptr && ptr->next != it.ptr) {
			ptr = ptr->next;
		}
		if(ptr == nullptr) {
			return false;
		}
		ptr->next = it.ptr->next;
		mem::free(it.ptr);
		return true;
	}

	auto clear() -> void {
		auto ptr = head;
		while(ptr != nullptr) {
			auto next = ptr->next;
			mem::free(ptr);
			ptr = next;
		}
	}

	auto empty() const -> bool {
		return head == nullptr;
	}

	struct Iterator {
		Iterator() = default;
		Iterator(Node* ptr) : ptr(ptr) {};

		friend struct List::ConstIterator;

		auto operator==(Iterator rhs) const -> bool {
			return ptr == rhs.ptr;
		}

		auto operator!=(Iterator rhs) const -> bool {
			return !(*this == rhs);
		}

		// prefix
		auto operator++() -> Iterator {
			ptr = ptr->next;
			return ptr;
		}

		// postfix
		auto operator++(int) -> Iterator {
			auto old = ptr;
			ptr = ptr->next;
			return old;
		}

		auto operator*() -> Value& {
			assert(ptr != nullptr);
			return ptr->value;
		}

		auto operator*() const -> const Value& {
			assert(ptr != nullptr);
			return ptr->value;
		}

		auto operator->() -> Value* {
			assert(ptr != nullptr);
			return &ptr->value;
		}

		auto operator->() const -> const Value* {
			assert(ptr != nullptr);
			return &ptr->value;
		}
	private:
		Node* ptr = nullptr;
	};

	struct ConstIterator {
		ConstIterator() = default;
		ConstIterator(Node ptr) : ptr(ptr) {
		}
		ConstIterator(Iterator other) : ptr(other.ptr) {
		}

		friend List;

		auto operator==(ConstIterator rhs) const -> bool {
			return ptr == rhs.ptr;
		}

		auto operator!=(ConstIterator rhs) const -> bool {
			return !(*this == rhs);
		}

		// prefix
		auto operator++() -> Iterator {
			ptr = ptr->next;
			return ptr;
		}

		// postfix
		auto operator++(int) -> Iterator {
			auto old = ptr;
			ptr = ptr->next;
			return old;
		}

		auto operator*() const -> const Value& {
			assert(ptr != nullptr);
			return ptr->value;
		}
	private:
		Node* ptr = nullptr;
	};

	auto begin() -> Iterator {
		return Iterator(head);
	}

	auto end() -> Iterator {
		return Iterator();
	}

	auto begin() const -> ConstIterator {
		return ConstIterator(head);
	}

	auto end() const-> ConstIterator {
		return ConstIterator();
	}

private:
	struct Node {
		Value value;
		Node* next = nullptr;
	};
	Node* head = nullptr;
};
