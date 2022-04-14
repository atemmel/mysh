#include "spawn.hpp"

#include "core/stringbuilder.hpp"
#include "globals.hpp"

#include "core/print.hpp"

#include <errno.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>

//auto spawnImpl(StringView prefix, const Array<String>& strings, bool captureStdout) -> SpawnResult {
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

	// capture stdout
	constexpr size_t bufferSize = 512;
	int pipefd[2];
	StaticArray<char, bufferSize> buffer;
	StringBuilder bob;

	if(options.captureStdout) {
		bob.reserve(bufferSize);
	}

	if(options.captureStdout || options.stdinView.hasValue()) {
		pipe(pipefd);
	}

	// end of capture stdout

	auto pid = fork();
	if(pid == 0) {	// child code
		if(!options.stdinView.hasValue() && options.captureStdout) {
			close(pipefd[0]);
		} 

		if(options.captureStdout) {
			dup2(pipefd[1], STDOUT_FILENO);
			dup2(pipefd[1], STDOUT_FILENO);
		}

		if(options.stdinView.hasValue()) {
			dup2(pipefd[0], STDIN_FILENO);
		}

		if(options.stdinView.hasValue() && !options.captureStdout) {
			close(pipefd[1]);
		}

		auto result = execv(command.data(), (char* const*)args.data());
		//println(strerror(errno), result);
		exit(result);
	} else if(pid == -1) {
		assert(false);
	} else {
		int status;

		if(options.stdinView.hasValue()) {
			write(pipefd[1], options.stdinView.value().data(),
				options.stdinView.value().size());
			close(pipefd[1]);
		}

		if(options.captureStdout) {
			if(!options.stdinView.hasValue()) {
				close(pipefd[1]);
			}
			auto output = fdopen(pipefd[0], "r");

			for(size_t len = fread(buffer.data(), sizeof(char), buffer.size(), output);
				len > 0; len = fread(buffer.data(), sizeof(char), buffer.size(), output)) {

				auto view = StringView(buffer.data(), len);
				bob.append(view);
			}
			bob.append('\0');
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

//auto spawn(const Array<String>& strings, bool captureStdout) -> SpawnResult {
auto spawn(const SpawnOptions& options) -> SpawnResult {
	SpawnResult result;
	for(auto path : globals::paths) {
		result = spawnImpl(path, options);
		if(result.code == 0) {
			return result;
		}
		//println("Result was", result);
	}
	return result;
}
