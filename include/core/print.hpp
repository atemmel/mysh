#pragma once

#include <stdio.h>

auto fprintType(FILE* desc, const char* str) -> void;
auto fprintType(FILE* desc, char value) -> void;
auto fprintType(FILE* desc, unsigned char value) -> void;
auto fprintType(FILE* desc, int value) -> void;
auto fprintType(FILE* desc, size_t value) -> void;
auto fprintType(FILE* desc, float value) -> void;
auto fprintType(FILE* desc, double value) -> void;
auto fprintType(FILE* desc, bool value) -> void;

template<typename Container>
auto fprintType(FILE* desc, const Container& container) -> void {
	fprintf(desc, "[ ");
	for(const auto& element : container) {
		fprintType(desc, element);
		fprintf(desc, " ");
	}
	fprintf(desc, "]");
}

template<typename Param>
auto fprint(FILE* desc, Param param) -> void {
	fprintType(desc, param);
}

template<typename Param, typename ...Params>
auto fprint(FILE* desc, Param param, Params... params) -> void {
	fprintType(desc, param);
	fprintf(desc, " ");
	fprint(desc, params...);
}

template<typename Param, typename ...Params>
auto println(Param param, Params... params) -> void {
	fprint(stdout, param, params...);
	fprintf(stdout, "\n");
}

template<typename Param, typename ...Params>
auto errprintln(Param param, Params... params) -> void {
	fprint(stderr, param, params...);
	fprintf(stderr, "\n");
}
