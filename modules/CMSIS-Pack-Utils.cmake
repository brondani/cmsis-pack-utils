# Copyright (c) 2022 Arm Limited and Contributors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# add_cmsis_library
# https://github.com/brondani/cmsis-packs-utils#readme

function(add_cmsis_library target device compiler packs components)
  # find required tools
  find_program(CSOLUTION csolution)
  if(NOT CSOLUTION)
    message(FATAL_ERROR "csolution not found!")
  endif()

  find_program(CPACKGET cpackget)
  if(NOT CPACKGET)
    message(FATAL_ERROR "cpackget not found!")
  endif()

  find_program(YAML_JSON_CONVERTER yq)
  if(NOT YAML_JSON_CONVERTER)
    message(FATAL_ERROR "yq not found!")
  endif()

  set(CSOLUTION_DIR ${CMAKE_BINARY_DIR}/${target})
  set(RTE_DIR ${CMAKE_CURRENT_LIST_DIR}/${target}/RTE)
  cmake_path(RELATIVE_PATH RTE_DIR BASE_DIRECTORY ${CSOLUTION_DIR} OUTPUT_VARIABLE RTE_DIR)

  # initialize CMSIS_PACK_ROOT variable
  if(NOT DEFINED ENV{CMSIS_PACK_ROOT})
    set(ENV{CMSIS_PACK_ROOT} ${CMAKE_BINARY_DIR}/cmsis-packs)
  endif()
  cmake_path(SET CMSIS_PACK_ROOT "$ENV{CMSIS_PACK_ROOT}")

  # initialize/update pack repository
  execute_process(
    COMMAND ${CPACKGET} update-index
    RESULT_VARIABLE RESULT
  )
  if(NOT ${RESULT} EQUAL 0)
    message(STATUS "creating pack repository in ${CMSIS_PACK_ROOT}")
    execute_process(
      COMMAND ${CPACKGET} init https://www.keil.com/pack/index.pidx
      RESULT_VARIABLE RESULT
    )
    if(NOT ${RESULT} EQUAL 0)
      message(FATAL_ERROR "initializing pack repository failed")
    endif()
  endif()

  # generate csolution.yml and cproject.yml files
  set(CSOLUTION_CONTENT "{\"solution\": {\"projects\": [{\"project\": \"${target}.cproject.yml\"}], \"output-dirs\": {\"rtedir\": \"${RTE_DIR}\"}, \"packs\": []}}")
  list(LENGTH ${packs} PACKS_LENGTH)
  if(PACKS_LENGTH GREATER 0)
    math(EXPR PACKS_LENGTH "${PACKS_LENGTH}-1")
    foreach(INDEX RANGE ${PACKS_LENGTH})
      list(GET ${packs} ${INDEX} PACK)
      string(JSON CSOLUTION_CONTENT SET ${CSOLUTION_CONTENT} "solution" "packs" ${INDEX} "{\"pack\": \"${PACK}\"}")
    endforeach()
  else()
    string(JSON CSOLUTION_CONTENT REMOVE ${CSOLUTION_CONTENT} "solution" "packs")
  endif()
  set(CSOLUTION_FILENAME ${CSOLUTION_DIR}/${target}.csolution.yml)
  file(WRITE ${CSOLUTION_FILENAME} ${CSOLUTION_CONTENT})

  set(CPROJECT_CONTENT "{\"project\": { \"device\": \"${device}\", \"compiler\": \"${compiler}\", \"components\": []}}")
  list(LENGTH ${components} COMPONENT_LENGTH)
  if(COMPONENT_LENGTH GREATER 0)
    math(EXPR COMPONENT_LENGTH "${COMPONENT_LENGTH}-1")
    foreach(INDEX RANGE ${COMPONENT_LENGTH})
      list(GET ${components} ${INDEX} COMPONENT)
      string(JSON CPROJECT_CONTENT SET ${CPROJECT_CONTENT} "project" "components" ${INDEX} "{\"component\": \"${COMPONENT}\"}")
    endforeach()
  else()
    string(JSON CPROJECT_CONTENT REMOVE ${CPROJECT_CONTENT} "project" "components")
  endif()
  set(CPROJECT_FILENAME ${CSOLUTION_DIR}/${target}.cproject.yml)
  file(WRITE ${CPROJECT_FILENAME} ${CPROJECT_CONTENT})

  # get missing packs
  execute_process(
    COMMAND ${CSOLUTION} -s ${CSOLUTION_FILENAME} list packs --missing
    OUTPUT_VARIABLE PACKS
    RESULT_VARIABLE RESULT
  )
  if(NOT ${RESULT} EQUAL 0)
    message(FATAL_ERROR "csolution list missing packs failed")
  endif()

  if(NOT ${PACKS} STREQUAL "")
    set(PACKS_FILENAME ${CSOLUTION_DIR}/${target}.packs)
    file(WRITE ${PACKS_FILENAME} ${PACKS})
    execute_process(
      COMMAND ${CPACKGET} add -a -f "${PACKS_FILENAME}"
      RESULT_VARIABLE RESULT
    )
    if(NOT ${RESULT} EQUAL 0)
      message(FATAL_ERROR "cpackget adding missing packs failed")
    endif()
    file(REMOVE ${PACKS_FILENAME})
  endif()

  # call csolution convert to obtain cbuild.yml
  execute_process(
    COMMAND ${CSOLUTION} -s ${CSOLUTION_FILENAME} convert
    RESULT_VARIABLE RESULT
  )
  if(NOT ${RESULT} EQUAL 0)
    message(FATAL_ERROR "csolution convert failed")
  endif()

  # read cbuild.yml in json format for easier cmake parsing
  set(CBUILD_YML_FILENAME ${CSOLUTION_DIR}/${target}.cbuild.yml)
  execute_process(
    COMMAND ${YAML_JSON_CONVERTER} ${CBUILD_YML_FILENAME} -o=json
    OUTPUT_VARIABLE CBUILD_CONTENT
    RESULT_VARIABLE RESULT
  )
  if(NOT ${RESULT} EQUAL 0)
    message(FATAL_ERROR "reading cbuild failed")
  endif()

  # get component sources
  cmsis_get_component_sources("${CBUILD_CONTENT}" SOURCE_FILES)

  # get include paths
  cmsis_get_include_paths("${CBUILD_CONTENT}" INCLUDE_PATHS)

  # get defines
  cmsis_get_defines("${CBUILD_CONTENT}" DEFINES)

  if(NOT SOURCE_FILES)
    add_library(${target} INTERFACE)
    target_include_directories(${target} INTERFACE ${INCLUDE_PATHS})
    target_compile_definitions(${target} INTERFACE ${DEFINES})
  else()
    add_library(${target} ${SOURCE_FILES})
    target_include_directories(${target} PUBLIC ${INCLUDE_PATHS})
    target_compile_definitions(${target} PUBLIC ${DEFINES})
  endif()
endfunction()

function(cmsis_get_defines cbuild defines)
  string(JSON DEFINES ERROR_VARIABLE ERROR GET ${cbuild} "build" "define")
  if(ERROR STREQUAL "NOTFOUND")
    set(INDEX 0)
    while(ERROR STREQUAL "NOTFOUND")
      string(JSON DEFINE ERROR_VARIABLE ERROR GET ${DEFINES} ${INDEX})
      if(ERROR STREQUAL "NOTFOUND")
        list(APPEND DEFINES_LIST "${DEFINE}")
      endif()
      math(EXPR INDEX "${INDEX}+1")
    endwhile()
  endif()
  set(${defines} ${DEFINES_LIST} PARENT_SCOPE)
endfunction()

function(cmsis_get_include_paths cbuild includes)
  string(JSON INCLUDE_PATHS ERROR_VARIABLE ERROR GET ${cbuild} "build" "add-path")
  if(ERROR STREQUAL "NOTFOUND")
    set(INDEX 0)
    while(ERROR STREQUAL "NOTFOUND")
      string(JSON INCLUDE_PATH ERROR_VARIABLE ERROR GET ${INCLUDE_PATHS} ${INDEX})
      if(ERROR STREQUAL "NOTFOUND")
        string(REGEX REPLACE "\\\${CMSIS_PACK_ROOT}" ${CMSIS_PACK_ROOT} INCLUDE_PATH ${INCLUDE_PATH})
        cmake_path(ABSOLUTE_PATH INCLUDE_PATH BASE_DIRECTORY ${CSOLUTION_DIR} OUTPUT_VARIABLE ABSOLUTE_FILE_PATH)
        list(APPEND INCLUDES_LIST ${ABSOLUTE_FILE_PATH})
      endif()
      math(EXPR INDEX "${INDEX}+1")
    endwhile()
  endif()
  set(${includes} ${INCLUDES_LIST} PARENT_SCOPE)
endfunction()

function(cmsis_get_component_sources cbuild sources)
  set(INDEX 0)
  set(ERROR "NOTFOUND")
  while(ERROR STREQUAL "NOTFOUND")
    string(JSON COMPONENTS ERROR_VARIABLE ERROR GET ${cbuild} "build" "components" ${INDEX})
    if(ERROR STREQUAL "NOTFOUND")
      string(JSON COMPONENT_FILES ERROR_VARIABLE ERROR_FILES GET ${COMPONENTS} "files")
      if(ERROR_FILES STREQUAL "NOTFOUND")
        cmsis_get_files("${COMPONENT_FILES}" SOURCES_LIST)
      endif()
    endif()
    math(EXPR INDEX "${INDEX}+1")
  endwhile()
  set(${sources} ${SOURCES_LIST} PARENT_SCOPE)
endfunction()

function(cmsis_get_files files sources)
  set(INDEX 0)
  set(ERROR "NOTFOUND")
  while(ERROR STREQUAL "NOTFOUND")
    string(JSON COMPONENT_FILE ERROR_VARIABLE ERROR GET ${files} ${INDEX} "file")
    if(ERROR STREQUAL "NOTFOUND")
      string(JSON FILE_CATEGORY ERROR_VARIABLE ERROR_CATEGORY GET ${files} ${INDEX} "category")
      if(FILE_CATEGORY MATCHES "source.*")
        string(REGEX REPLACE "\\\${CMSIS_PACK_ROOT}" ${CMSIS_PACK_ROOT} COMPONENT_FILE ${COMPONENT_FILE})
        cmake_path(ABSOLUTE_PATH COMPONENT_FILE BASE_DIRECTORY ${CSOLUTION_DIR} OUTPUT_VARIABLE ABSOLUTE_FILE_PATH)
        list(APPEND SOURCES_LIST ${ABSOLUTE_FILE_PATH})
      endif()
    endif()
    math(EXPR INDEX "${INDEX}+1")
  endwhile()
  set(${sources} ${SOURCES_LIST} PARENT_SCOPE)
endfunction()
