cmake_minimum_required(VERSION 3.10)
project(mysh)

# Set a default build type if none was specified
set(default_build_type "Release")
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to '${default_build_type}' as none was specified.")
  set(CMAKE_BUILD_TYPE "${default_build_type}")
endif()

set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-O3")

file(GLOB_RECURSE SOURCES RELATIVE ${CMAKE_SOURCE_DIR} "./src/*.cpp")
add_executable(mysh ${SOURCES})
set_property(TARGET mysh PROPERTY CXX_STANDARD 20)
include_directories(include)
add_compile_options(-Wall -Wextra -Wpedantic -Wfloat-equal -Wwrite-strings -Wno-unused-parameter -Wundef -Wcast-qual -Wshadow -Wredundant-decls)

if(NOT WIN32)
	set(CMAKE_EXE_LINKER_FLAGS "-Wl,-export-dynamic")
endif()
