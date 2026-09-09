cmake_minimum_required(VERSION 3.20)
project(ChemLab VERSION 0.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(IPHREEQC_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/src/iphreeqc-3.8.6-17100")
if(NOT EXISTS "${IPHREEQC_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR "Run python3 scripts/bootstrap.py first")
endif()
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
add_subdirectory("${IPHREEQC_ROOT}" "iphreeqc" EXCLUDE_FROM_ALL)

add_executable(iphreeqc_probe tests/iphreeqc_probe.cpp)
target_link_libraries(iphreeqc_probe PRIVATE IPhreeqc)
target_compile_options(iphreeqc_probe PRIVATE -Wall -Wextra -Wpedantic)
include(CTest)
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/artifacts")
add_test(NAME iphreeqc_science
    COMMAND iphreeqc_probe "${IPHREEQC_ROOT}/database/phreeqc.dat"
    "${CMAKE_BINARY_DIR}/artifacts/iphreeqc_results.csv")
