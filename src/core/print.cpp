#include "core/print.hpp"

auto printType(const char* str) -> void {
	printf("%s", str);
}

auto printType(char value) -> void {
	printf("%c", value);
}
auto printType(unsigned char value) -> void {
	printf("%c", value);
}
auto printType(int value) -> void {
	printf("%d", value);
}
auto printType(size_t value) -> void {
	printf("%lu", value);
}
auto printType(float value) -> void {
	printf("%f", value);
}
auto printType(double value) -> void {
	printf("%f", value);
}
