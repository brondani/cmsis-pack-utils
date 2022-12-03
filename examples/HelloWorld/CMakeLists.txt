# Copyright (c) 2022 Arm Limited and Contributors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.25)

# fetch iotsdk-toolchains
include(FetchContent)
FetchContent_Declare(iotsdk-toolchains
    GIT_REPOSITORY  https://git.gitlab.arm.com/iot/open-iot-sdk/toolchain.git
    GIT_TAG         126d2092a2325c77fdf36043e931293c62e2ad29
    SOURCE_DIR      ${CMAKE_BINARY_DIR}/toolchains
)
FetchContent_MakeAvailable(iotsdk-toolchains)

project(HelloWorld LANGUAGES C ASM)

set(CC_SRC_FILES
  "${CMAKE_CURRENT_LIST_DIR}/main.c"
)

add_executable(HelloWorld ${CC_SRC_FILES})

# ARMClang linker script
if(NOT CMAKE_C_COMPILER_ID STREQUAL "ARMClang")
  message(FATAL_ERROR "this project example requires ARMClang")
endif()
set(LINKER_SCRIPT "${CMAKE_CURRENT_LIST_DIR}/linker.sct")
target_link_options(HelloWorld PRIVATE --scatter=${LINKER_SCRIPT})
set_target_properties(HelloWorld PROPERTIES LINK_DEPENDS ${LINKER_SCRIPT})


# include module "CMSIS-Pack-Utils"
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../modules")
include(CMSIS-Pack-Utils)

set(CMSIS_PACKS
  "ARM::CMSIS@5.9.0"
  "Keil::ARM_Compiler"
)

set(CMSIS_COMPONENTS
  "Device:Startup"
  "CMSIS:CORE"
  "CMSIS:RTOS2:Keil RTX5&Source"
  "Compiler&ARM Compiler:Event Recorder&Semihosting"
)

add_cmsis_library(
  cmsis-lib         # library target name
  ARMCM4_FP         # device
  AC6               # compiler
  CMSIS_PACKS       # list of packs
  CMSIS_COMPONENTS  # list of components
)

# add generated 'cmsis' library as a dependency
target_link_libraries(HelloWorld cmsis-lib)
