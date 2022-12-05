# CMSIS-Pack-Utils: CMake module PoC

The CMake module [`CMSIS-Pack-Utils.cmake`](./modules/CMSIS-Pack-Utils.cmake) is an experimental proof of concept for yet another approach aimed at closing the gap between generic CMake based projects and CMSIS-Packs. It generates `csolution.yml` and `cproject.yml` and orchestrates calls to `csolution` and `cpackget` to download required packs and generate build instructions. It parses the generated `cbuild.yml` for getting source files, include paths and defines and then it generates CMake library targets. Several limitations such as device attributes, pre-includes and generators handling are currently not addressed in this PoC.

## Prerequisites

The following applications are required to be installed before calling functions from `CMSIS-Pack-Utils`. Make sure they are in the system `PATH`.

- [CMSIS Toolbox](https://github.com/Open-CMSIS-Pack/cmsis-toolbox/blob/main/docs/installation.md): for using `cpackget` and `csolution`

- [yq](https://github.com/mikefarah/yq#install): for converting YAML into JSON for using CMake parser

## How to use

1. Add the module into the `CMAKE_MODULE_PATH` and include it in the project's `CMakeLists.txt`:
```
include(CMSIS-Pack-Utils)
```

2. Add the function `add_cmsis_library` into the `CMakeLists.txt`:
```
add_cmsis_library(
  target
  device
  compiler
  packs
  components
)
```
- `target`: cmsis target library name, freely chosen
- `device`: device identifier according to the `csolution` [device name convention](https://github.com/Open-CMSIS-Pack/devtools/blob/main/tools/projmgr/docs/Manual/YML-Input-Format.md#device-name-conventions)
- `compiler`: one of the supported compilers supported by `csolution` [`AC6`, `GCC`, `IAR`]
- `packs`: list of required pack identifiers according to the `csolution` [pack name convention](https://github.com/Open-CMSIS-Pack/devtools/blob/main/tools/projmgr/docs/Manual/YML-Input-Format.md#pack-name-conventions).
- `components`: list of required component identifiers according to the `csolution` [component name convention](https://github.com/Open-CMSIS-Pack/devtools/blob/main/tools/projmgr/docs/Manual/YML-Input-Format.md#component-name-conventions).

3. Specify the generated cmsis library among the project dependencies.
For example:
```
target_link_libraries(MyEmbeddedProject cmsis-lib)
```

## Configuration

The location of the pack repository can be configured by setting the environment variable `CMSIS_PACK_ROOT`. By default the module `CMSIS-Pack-Utils` uses the folder `${CMAKE_BINARY_DIR}/cmsis-packs`.

The location of configuration files and related [`PLM`](https://github.com/Open-CMSIS-Pack/devtools/blob/main/tools/projmgr/docs/Manual/Overview.md#plm-of-configuration-files) files belonging to CMSIS components is set to `${CMAKE_CURRENT_LIST_DIR}/${target}/RTE`.

## Example

The [HelloWorld](./examples/HelloWorld) example uses the `open-iot-sdk` toolchain setup as it's done in other [open-iot-sdk examples](https://gitlab.arm.com/iot/open-iot-sdk/examples). Make sure `CMake`, `ninja` and `ARMClang` are available on the PATH before running this example.

Configure:
```
cmake -B __build -GNinja --toolchain=toolchains/toolchain-armclang.cmake -DCMAKE_SYSTEM_PROCESSOR=cortex-m4
```

Build:
```
cmake --build __build
```
