#pragma once

auto fprintType(FILE* desc, const char* str) -> void;
auto fprintType(FILE* desc, char* str) -> void;
auto fprintType(FILE* desc, char value) -> void;
auto fprintType(FILE* desc, unsigned char value) -> void;
auto fprintType(FILE* desc, int value) -> void;
auto fprintType(FILE* desc, size_t value) -> void;
auto fprintType(FILE* desc, float value) -> void;
auto fprintType(FILE* desc, double value) -> void;
auto fprintType(FILE* desc, bool value) -> void;
