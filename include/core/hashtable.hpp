#pragma once

#include "core/array.hpp"
#include "core/hash.hpp"
#include "core/list.hpp"

template<typename Key, typename Value>
struct HashTable {
	struct KeyValuePair {
		Key key;
		Value value;
	};

	using Bucket = List<KeyValuePair>;
	using Buckets = Array<Bucket>;
	struct Iterator;
	struct ConstIterator;

	auto get(const Key& key) -> Value* {
		auto it = lookup(key);
		if(it == end()) {
			return nullptr;
		}
		return &it->value;
	}

	auto get(const Key& key) const -> const Value* {
		auto it = lookup(key);
		if(it == end()) {
			return nullptr;
		}
		return &it->value;
	}

	auto put(const Key& key, const Value& value) -> void {
		maybeRehash();
		auto it = lookup(key);
		if(it == end()) {
			insert(key, value);
		} else {
			it->value = value;
		}
	}

	auto has(const Key& key) const -> bool {
		return lookup(key) != end();
	}

	auto remove(const Key& key) -> bool {
		auto it = lookup(key);
		if(it == end()) {
			return false;
		}

		assert(it.currentBucket->erase(it.currentPair));
		--elements;
		return true;
	}

	auto empty() const -> bool {
		return elements == 0;
	}

	auto size() const -> size_t {
		return elements;
	}

	auto clear() -> void;

	auto begin() -> Iterator {
		auto firstBucket = buckets.begin();
		while(firstBucket != buckets.end() && firstBucket->empty()) {
			++firstBucket;
		}
		if(firstBucket == buckets.end()) {
			return end();
		}
		return Iterator(firstBucket->begin(), firstBucket, buckets.end());
	}

	auto begin() const -> ConstIterator {
		auto firstBucket = buckets.begin();
		while(firstBucket != buckets.end() && firstBucket->empty()) {
			++firstBucket;
		}
		if(firstBucket == buckets.end()) {
			return end();
		}
		return ConstIterator(firstBucket->begin(), firstBucket, buckets.end());
	}

	auto end() -> Iterator {
		return Iterator(buckets.end(), buckets.end());
	}

	auto end() const -> ConstIterator {
		return ConstIterator(buckets.end(), buckets.end());
	}

	struct Iterator {
		Iterator() = default;
		Iterator(Bucket* currentBucket, const Bucket* lastBucket) 
			: currentBucket(currentBucket), currentPair(nullptr), lastBucket(lastBucket) {}
		Iterator(typename Bucket::Iterator it, Bucket* currentBucket, const Bucket* lastBucket) 
			: currentBucket(currentBucket), currentPair(it), lastBucket(lastBucket) {}

		friend struct HashTable;
		friend struct HashTable::ConstIterator;

		auto operator==(Iterator rhs) const -> bool {
			return currentBucket == rhs.currentBucket && currentPair == rhs.currentPair;
		}

		auto operator!=(Iterator rhs) const -> bool {
			return !(*this == rhs);
		}

		// prefix
		auto operator++() -> Iterator {
			++currentPair;
			if(currentPair == currentBucket->end()) {
				++currentBucket;
				while(currentBucket != lastBucket
					&& currentBucket->empty()) {
					++currentBucket;
				}
				if(currentBucket == lastBucket) {
					currentPair = nullptr;
				} else {
					currentPair = currentBucket->begin();
				}
			}
			return *this;
		}

		// postfix
		auto operator++(int) -> Iterator {
			auto old = *this;
			++(*this);
			return old;
		}

		auto operator*() -> KeyValuePair& {
			assert(currentPair != currentBucket->end());
			return *currentPair;
		}

		auto operator*() const -> const KeyValuePair& {
			assert(currentPair != currentBucket->end());
			return *currentPair;
		}

		auto operator->() -> KeyValuePair* {
			assert(currentPair != currentBucket->end());
			return &*currentPair;
		}

		auto operator->() const -> const KeyValuePair* {
			assert(currentPair != currentBucket->end());
			return &*currentPair;
		}

	private:
		typename Bucket::Iterator currentPair;
		Bucket* currentBucket;
		const Bucket* lastBucket;
	};

	struct ConstIterator {
		ConstIterator() = default;
		ConstIterator(const Bucket* currentBucket, const Bucket* lastBucket) 
			: currentBucket(currentBucket), currentPair(nullptr), lastBucket(lastBucket) {}
		ConstIterator(typename Bucket::ConstIterator it, const Bucket* currentBucket, const Bucket* lastBucket) 
			: currentBucket(currentBucket), currentPair(it), lastBucket(lastBucket) {}
		ConstIterator(Iterator it)
			: currentBucket(it.currentBucket), currentPair(it.currentPair), lastBucket(it.lastBucket) {}

		friend struct HashTable;

		auto operator==(ConstIterator rhs) const -> bool {
			return currentBucket == rhs.currentBucket && currentPair == rhs.currentPair;
		}

		auto operator!=(ConstIterator rhs) const -> bool {
			return !(*this == rhs);
		}

		// prefix
		auto operator++() -> ConstIterator {
			++currentPair;
			if(currentPair == currentBucket->end()) {
				++currentBucket;
				while(currentBucket != lastBucket
					&& currentBucket->empty()) {
					++currentBucket;
				}
				if(currentBucket == lastBucket) {
					currentPair = nullptr;
				} else {
					currentPair = currentBucket->begin();
				}
			}
			return *this;
		}

		// postfix
		auto operator++(int) -> ConstIterator {
			auto old = *this;
			++(*this);
			return old;
		}

		auto operator*() const -> const KeyValuePair& {
			return *currentPair;
		}

		auto operator->() const -> const KeyValuePair* {
			return &*currentPair;
		}
	private:
		typename Bucket::ConstIterator currentPair;
		const Bucket* currentBucket;
		const Bucket* lastBucket;
	};
private:
	auto lookup(const Key& key) -> Iterator {
		if(empty()) {
			return end();
		}
		size_t index = hash(key) % buckets.size();
		Bucket& bucket = buckets[index];
		auto it = bucket.begin();
		while(it != bucket.end() && it->key != key) {
			++it;
		}
		if(it == bucket.end()) {
			return end();
		}
		return Iterator(it, &bucket, buckets.end());
	}

	auto lookup(const Key& key) const -> ConstIterator {
		if(empty()) {
			return end();
		}
		size_t index = hash(key) % buckets.size();
		const Bucket& bucket = buckets[index];
		auto it = bucket.begin();
		auto end = bucket.end();
		while(it != end && it->key != key) {
			++it;
		}
		return ConstIterator(it, &bucket, buckets.end());
	}

	auto insert(const Key& key, const Value& value) -> void {
		size_t index = hash(key) % buckets.size();
		Bucket& bucket = buckets[index];
		bucket.append(KeyValuePair{
			.key = key,
			.value = value,
		});
		++elements;
	}

	auto maybeRehash() -> bool {
		if(buckets.empty()) { // there is not table, rehash
			buckets.resize(128);
			return true;
		} 

		float loadFactor = (float)elements / (float)buckets.size();
		if(loadFactor > 0.7f) {	// then we rehash
			auto newSize = elements * 2;
			auto oldBuckets = move(buckets);
			buckets.resize(newSize);
			for(const auto& bucket : oldBuckets) {
				for(const auto& pair : bucket) {
					//TODO: can be moved
					insert(pair.key, pair.value);
				}
			}
			return true;
		}
		return false;
	}

	Buckets buckets;
	size_t elements = 0;
};

