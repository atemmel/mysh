#include "spawn.hpp"

#include "globals.hpp"

#include <errno.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>

auto spawnImpl(StringView prefix, const Array<String>& strings) -> int {
	String command(strings[0].size() + prefix.size() + 2, ' ');
	mem::copy(prefix, command);
	size_t insertionPoint = prefix.size();
	if(command[insertionPoint - 1] != '/') {
		command[insertionPoint] = '/';
		++insertionPoint;
	}
	mem::copy(strings[0].begin(), strings[0].end(), command.begin() + insertionPoint);

	*command.end() = '\0';

	Array<const char*> args;
	args.reserve(strings.size() + 1);
	for(size_t i = 0; i < strings.size(); i++) {
		args.append(strings[i].data());
	}
	args.append(nullptr);

	auto pid = fork();
	if(pid == 0) {	// child code
		//println("Exec:", command, args);
		auto result = execv(command.data(), (char* const*)args.data());
		//println(strerror(errno), result);
		exit(result);
	} else {
		int status;
		wait(&status);
		return status;
	}
	assert(false);
	return 0;
}

auto spawn(const Array<String>& strings) -> void {
	for(auto path : globals::paths) {
		auto result = spawnImpl(path, strings);
		if(result == 0) {
			return;
		}
		//println("Result was", result);
	}
}
