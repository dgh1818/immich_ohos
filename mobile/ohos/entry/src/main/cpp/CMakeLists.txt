cmake_minimum_required(VERSION 3.5)

project(native_buffer)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

function(immich_dedupe_linker_flags cache_var cache_doc)
    if(NOT DEFINED ${cache_var})
        return()
    endif()

    set(_raw_flags "${${cache_var}}")
    if(_raw_flags STREQUAL "")
        return()
    endif()

    separate_arguments(_flag_list NATIVE_COMMAND "${_raw_flags}")
    set(_deduped_flags "")
    foreach(_flag IN LISTS _flag_list)
        if(NOT _flag IN_LIST _deduped_flags)
            list(APPEND _deduped_flags "${_flag}")
        endif()
    endforeach()

    string(REPLACE ";" " " _joined_flags "${_deduped_flags}")
    if(NOT _joined_flags STREQUAL _raw_flags)
        set(${cache_var} "${_joined_flags}" PARENT_SCOPE)
        set(${cache_var} "${_joined_flags}" CACHE STRING "${cache_doc}" FORCE)
    endif()
endfunction()

# DevEco's OHOS toolchain can append the same linker flags repeatedly
# during configure, which breaks the Windows linker invocation length.
immich_dedupe_linker_flags(CMAKE_SHARED_LINKER_FLAGS "Global shared linker flags")
immich_dedupe_linker_flags(CMAKE_MODULE_LINKER_FLAGS "Global module linker flags")
immich_dedupe_linker_flags(CMAKE_EXE_LINKER_FLAGS "Global executable linker flags")

add_library(native_buffer SHARED
    native_buffer.cpp
)

# N-API (ArkTS) bridge library
target_link_libraries(native_buffer PUBLIC
    ace_napi.z
)
