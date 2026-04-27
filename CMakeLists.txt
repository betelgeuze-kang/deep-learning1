cmake_minimum_required(VERSION 3.16)

project(discrete_local_energy LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(dm_common INTERFACE)
target_include_directories(dm_common INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/src")

add_executable(
  dmv01
  src/v01/main_v01.cpp
  src/v01/GraphV01.cpp
  src/v01/OptimizerV01.cpp
)
target_link_libraries(dmv01 PRIVATE dm_common)

add_executable(
  dmv02
  src/v02_pre/main_v02.cpp
  src/v02_pre/GraphV02.cpp
  src/v02_pre/FieldTable.cpp
  src/v02_pre/CouplingTable.cpp
  src/v02_pre/RoutingTable.cpp
  src/v02_pre/ByteDataset.cpp
  src/v02_pre/OptimizerV02.cpp
)
target_link_libraries(dmv02 PRIVATE dm_common)

foreach(target dmv01 dmv02)
  target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic)
endforeach()
