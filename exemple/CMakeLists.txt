cmake_minimum_required(VERSION 3.16)
project(exemple LANGUAGES CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../CMakeUtils.cmake)

find_package(Qt6 REQUIRED COMPONENTS Core)

add_subdirectory(core)
add_subdirectory(app)
