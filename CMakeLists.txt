cmake_minimum_required(VERSION 3.16)

project(discrete_local_energy LANGUAGES CXX)

option(DLE_ENABLE_HIP "Enable optional ROCm/HIP backend scaffolding" OFF)

if(DLE_ENABLE_HIP)
  if(CMAKE_VERSION VERSION_LESS 3.21)
    message(FATAL_ERROR "DLE_ENABLE_HIP=ON requires CMake 3.21 or newer for HIP language support")
  endif()

  if(NOT CMAKE_HIP_ARCHITECTURES)
    find_program(DLE_OFFLOAD_ARCH offload-arch HINTS /opt/rocm/bin)
    if(DLE_OFFLOAD_ARCH)
      execute_process(
        COMMAND "${DLE_OFFLOAD_ARCH}"
        OUTPUT_VARIABLE DLE_OFFLOAD_ARCH_OUTPUT
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
      )
      string(REPLACE "\n" ";" DLE_OFFLOAD_ARCH_LIST "${DLE_OFFLOAD_ARCH_OUTPUT}")
      list(LENGTH DLE_OFFLOAD_ARCH_LIST DLE_OFFLOAD_ARCH_COUNT)
      if(DLE_OFFLOAD_ARCH_COUNT GREATER 0)
        list(GET DLE_OFFLOAD_ARCH_LIST 0 DLE_DETECTED_HIP_ARCH)
        set(CMAKE_HIP_ARCHITECTURES "${DLE_DETECTED_HIP_ARCH}" CACHE STRING "HIP architectures" FORCE)
      endif()
    endif()
  endif()

  enable_language(HIP)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_HIP_STANDARD 17)
set(CMAKE_HIP_STANDARD_REQUIRED ON)
set(CMAKE_HIP_EXTENSIONS OFF)

add_library(dm_common INTERFACE)
target_include_directories(dm_common INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/src")
if(DLE_ENABLE_HIP)
  target_compile_definitions(dm_common INTERFACE DLE_ENABLE_HIP=1)
else()
  target_compile_definitions(dm_common INTERFACE DLE_ENABLE_HIP=0)
endif()

add_library(dm_backend STATIC src/backend/RouteQualityBackend.cpp)
target_link_libraries(dm_backend PUBLIC dm_common)
if(DLE_ENABLE_HIP)
  target_sources(dm_backend PRIVATE src/backend/RouteQualityBackendHIP.hip)
  set_source_files_properties(src/backend/RouteQualityBackendHIP.hip PROPERTIES LANGUAGE HIP)
endif()

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
target_link_libraries(dmv02 PRIVATE dm_common dm_backend)

add_executable(
  hip_candidate_weight_parity
  src/tools/hip_candidate_weight_parity.cpp
)
target_link_libraries(hip_candidate_weight_parity PRIVATE dm_common dm_backend)

add_executable(
  expert_ffn_forward_parity
  src/tools/expert_ffn_forward_parity.cpp
)
target_link_libraries(expert_ffn_forward_parity PRIVATE dm_common)

add_executable(
  v02_config_view_contract
  src/tools/v02_config_view_contract.cpp
)
target_link_libraries(v02_config_view_contract PRIVATE dm_common)

add_executable(
  v02_energy_core_contract
  src/tools/v02_energy_core_contract.cpp
  src/v02_pre/FieldTable.cpp
  src/v02_pre/CouplingTable.cpp
)
target_link_libraries(v02_energy_core_contract PRIVATE dm_common)

add_executable(
  v02_route_core_contract
  src/tools/v02_route_core_contract.cpp
)
target_link_libraries(v02_route_core_contract PRIVATE dm_common)

foreach(target dmv01 dmv02)
  target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic)
endforeach()
target_compile_options(dm_backend PRIVATE -Wall -Wextra -Wpedantic)
target_compile_options(hip_candidate_weight_parity PRIVATE -Wall -Wextra -Wpedantic)
target_compile_options(expert_ffn_forward_parity PRIVATE -Wall -Wextra -Wpedantic)
target_compile_options(v02_config_view_contract PRIVATE -Wall -Wextra -Wpedantic)
target_compile_options(v02_energy_core_contract PRIVATE -Wall -Wextra -Wpedantic)
target_compile_options(v02_route_core_contract PRIVATE -Wall -Wextra -Wpedantic)
