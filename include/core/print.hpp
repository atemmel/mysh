#pragma once

#include <stdio.h>

auto printType(const char* str) -> void;
auto printType(char value) -> void;
auto printType(unsigned char value) -> void;
auto printType(int value) -> void;
auto printType(size_t value) -> void;
auto printType(float value) -> void;
auto printType(double value) -> void;

template<typename Param>
auto print(Param param) -> void {
	printType(param);
}

template<typename Param, typename ...Params>
auto print(Param param, Params... params) -> void {
	printType(param);
	printf(" ");
	print(params...);
}

template<typename Param, typename ...Params>
auto println(Param param, Params... params) -> void {
	print(param, params...);
	printf("\n");
}
