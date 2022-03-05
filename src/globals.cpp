#include "globals.hpp"

#include "core/print.hpp"

bool globals::verbose = false;
Array<StringView> globals::paths;

auto globals::init() -> void {
	auto path = StringView(getenv("PATH"));
	for(size_t i = 0; i < path.size(); ++i) {
		auto next = path.view(i, path.size()).find(':');
		if(next == -1) {
			paths.append(path.view(i, path.size()));
			break;
		}

		next += i;
		paths.append(path.view(i, next));
		i = next;
	}
}
