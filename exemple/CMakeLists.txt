cmake_minimum_required(VERSION 3.13)
project(exemple LANGUAGES CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../target.cmake)

cmu_add_target(
    NAME core
    TYPE STATIC
    SOURCES src/core.cpp
    INCLUDE_DIRECTORIES PUBLIC include PRIVATE src
    COMPILE_DEFINITIONS PUBLIC CORE_VALUE=42
    COMPILE_FEATURES PUBLIC cxx_std_17
)

cmu_add_target(
    NAME app
    TYPE EXECUTABLE
    SOURCES src/main.cpp
    LINK_LIBRARIES PRIVATE core
)
