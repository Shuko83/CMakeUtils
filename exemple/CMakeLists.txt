cmake_minimum_required(VERSION 3.16)
project(exemple LANGUAGES CXX)

include(${CMAKE_CURRENT_LIST_DIR}/../CMakeUtils.cmake)

find_package(Qt6 REQUIRED COMPONENTS Core)

# Executables and DLLs side by side, so that MySharedLib.dll is found when an application starts.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

add_subdirectory(MyStaticLib)
add_subdirectory(MySharedLib)
add_subdirectory(MyApp)
add_subdirectory(MyQtApp)
