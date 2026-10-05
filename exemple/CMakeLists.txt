cmake_minimum_required(VERSION 3.13)
project(exemple LANGUAGES CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../CMakeUtils.cmake)

add_subdirectory(core)
add_subdirectory(app)
