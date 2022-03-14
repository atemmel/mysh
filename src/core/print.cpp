#include "core/print.hpp"

auto fprintType(FILE* desc, const char* str) -> void {
	if(str == nullptr) {
		fprintf(desc, "null str");
	} else {
		fprintf(desc, "%s", str);
	}
}

auto fprintType(FILE* desc, char* str) -> void {
	if(str == nullptr) {
		fprintf(desc, "null str");
	} else {
		fprintf(desc, "%s", str);
	}
}

auto fprintType(FILE* desc, char value) -> void {
	fprintf(desc, "%c", value);
}

auto fprintType(FILE* desc, unsigned char value) -> void {
	fprintf(desc, "%c", value);
}

auto fprintType(FILE* desc, int value) -> void {
	fprintf(desc, "%d", value);
}

auto fprintType(FILE* desc, int64_t value) -> void {
	fprintf(desc, "%ld", value);
}

auto fprintType(FILE* desc, size_t value) -> void {
	fprintf(desc, "%lu", value);
}

auto fprintType(FILE* desc, float value) -> void {
	fprintf(desc, "%f", value);
}

auto fprintType(FILE* desc, double value) -> void {
	fprintf(desc, "%f", value);
}

auto fprintType(FILE* desc, bool value) -> void {
	fprintf(desc, value ? "true" : "false");
}
