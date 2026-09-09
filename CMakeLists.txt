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
# IPhreeqc transport.cpp exposes a legacy C symbol named `token`; godot-cpp
# exposes another. Scope a build-time rename to that upstream translation unit.
set_property(SOURCE "${IPHREEQC_ROOT}/src/phreeqcpp/transport.cpp"
    DIRECTORY "${IPHREEQC_ROOT}" APPEND PROPERTY
    COMPILE_DEFINITIONS token=chemlab_phreeqc_transport_token)

add_executable(iphreeqc_probe tests/iphreeqc_probe.cpp)
target_link_libraries(iphreeqc_probe PRIVATE IPhreeqc)
target_compile_options(iphreeqc_probe PRIVATE -Wall -Wextra -Wpedantic)
add_library(chemlab_science STATIC src/science/chemistry.cpp src/science/mechanics.cpp)
target_include_directories(chemlab_science PUBLIC src)
target_link_libraries(chemlab_science PUBLIC IPhreeqc)
target_compile_options(chemlab_science PRIVATE -Wall -Wextra -Wpedantic)
add_executable(science_core_test tests/science_core_test.cpp)
target_link_libraries(science_core_test PRIVATE chemlab_science)
include(CTest)
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/artifacts")
add_test(NAME iphreeqc_science
    COMMAND iphreeqc_probe "${IPHREEQC_ROOT}/database/phreeqc.dat"
    "${CMAKE_BINARY_DIR}/artifacts/iphreeqc_results.csv")
add_test(NAME science_core COMMAND science_core_test "${IPHREEQC_ROOT}/database/phreeqc.dat")
add_executable(mechanics_test tests/mechanics_test.cpp)
target_link_libraries(mechanics_test PRIVATE chemlab_science)
add_test(NAME mechanics COMMAND mechanics_test)

add_executable(batch_test tests/batch_test.cpp)
target_link_libraries(batch_test PRIVATE chemlab_science)
add_test(NAME batch_equilibrium COMMAND batch_test "${IPHREEQC_ROOT}/database/phreeqc.dat")

add_executable(aqueous_expansion_test tests/aqueous_expansion_test.cpp)
target_link_libraries(aqueous_expansion_test PRIVATE chemlab_science)
add_test(NAME aqueous_expansion COMMAND aqueous_expansion_test "${IPHREEQC_ROOT}/database/phreeqc.dat")

option(CHEMLAB_BUILD_GODOT "Build the native Godot extension" OFF)
if(CHEMLAB_BUILD_GODOT)
    set(GODOTCPP_ROOT "${CMAKE_SOURCE_DIR}/third_party/src/godot-cpp-e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77")
    set(GODOTCPP_BUILD_PROFILE "${CMAKE_SOURCE_DIR}/cmake/godot_profile.json" CACHE PATH "" FORCE)
    set(GODOTCPP_TARGET "template_release" CACHE STRING "" FORCE)
    set(GODOTCPP_DISABLE_EXCEPTIONS OFF CACHE BOOL "" FORCE)
    add_subdirectory("${GODOTCPP_ROOT}" godot-cpp EXCLUDE_FROM_ALL)
    add_library(chemlab_native SHARED src/godot/register_types.cpp src/godot/lab_core.cpp)
    target_link_libraries(chemlab_native PRIVATE godot::cpp chemlab_science)
    set_target_properties(chemlab_native PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/godot/bin")
    file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/godot/data")
    configure_file("${IPHREEQC_ROOT}/database/phreeqc.dat" "${CMAKE_SOURCE_DIR}/godot/data/phreeqc.dat" COPYONLY)
    configure_file("${CMAKE_SOURCE_DIR}/data/reagents.json" "${CMAKE_SOURCE_DIR}/godot/data/reagents.json" COPYONLY)
endif()
