#include "spawn.hpp"

#include "core/stringbuilder.hpp"
#include "globals.hpp"

#include <errno.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>

auto spawnImpl(StringView prefix, const SpawnOptions& options) -> SpawnResult {
	const auto& strings = options.args;

	//TODO: redo with stringbuilder
	String command(strings[0].size() + prefix.size() + 2, ' ');
	mem::copy(prefix, command);
	size_t insertionPoint = prefix.size();
	if(command[insertionPoint - 1] != '/') {
		command[insertionPoint] = '/';
		++insertionPoint;
	}
	mem::copy(strings[0].begin(), strings[0].end(), command.begin() + insertionPoint);
	*(command.end()) = '\0';
	// end of todo

	Array<const char*> args;
	args.reserve(strings.size() + 1);
	for(size_t i = 0; i < strings.size(); i++) {
		args.append(strings[i].data());
	}
	args.append(nullptr);

	// piping
	constexpr size_t bufferSize = 512;
	int meRead, meWrite, youRead, youWrite;
	StaticArray<char, bufferSize> buffer;
	StringBuilder bob;

	if(options.captureStdout) {
		int pipefd[2];
		bob.reserve(bufferSize);
		pipe(pipefd);
		meRead = pipefd[0];
		youWrite = pipefd[1];
	}

	if(options.stdinView.hasValue()) {
		int pipefd[2];
		pipe(pipefd);
		youRead = pipefd[0];
		meWrite = pipefd[1];
	}

	// end of piping

	auto pid = fork();
	if(pid == 0) {	// child code

		if(options.stdinView.hasValue()) {
			dup2(youRead, STDIN_FILENO);
			close(youRead);
			close(meWrite);
		}

		if(options.captureStdout) {
			dup2(youWrite, STDOUT_FILENO);
			close(meRead);
			close(youWrite);
		}

		auto result = execv(command.data(), (char* const*)args.data());
		exit(result);
	} else if(pid == -1) {
		assert(false);
	} else {
		int status;

		if(options.stdinView.hasValue()) {
			close(youRead);
			auto view = options.stdinView.value();
			write(meWrite, view.data(), view.size());
			close(meWrite);
		}

		if(options.captureStdout) {
			close(youWrite);
			auto output = fdopen(meRead, "r");

			size_t len = fread(buffer.data(), sizeof(char), buffer.size(), output);
			for(; len > 0; len = fread(buffer.data(), sizeof(char), buffer.size(), output)) {
				auto view = StringView(buffer.data(), len);
				bob.append(view);
			}
			bob.append('\0');
			close(meRead);
		}

		wait(&status);
		return {
			.code = status,
			.out = options.captureStdout ? String(move(bob)) : String(),
		};
	}
	assert(false);
	return {};
}

auto spawn(const SpawnOptions& options) -> SpawnResult {
	SpawnResult result;
	for(auto path : globals::paths) {
		result = spawnImpl(path, options);
		if(result.code == 0) {
			return result;
		}
	}
	return result;
}
