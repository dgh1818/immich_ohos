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

set(IMMICH_ENTRY_LIBS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../libs/${OHOS_ARCH}")
set(IMMICH_THIRDPARTY_DIR "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty")
set(IMMICH_LIBCURL_LIBRARY "${IMMICH_ENTRY_LIBS_DIR}/libcurl.so")
set(IMMICH_LIBCURL_INCLUDE_DIR "${IMMICH_THIRDPARTY_DIR}/curl/${OHOS_ARCH}/include")

function(immich_enable_optional_libcurl target_name)
    if(EXISTS "${IMMICH_LIBCURL_LIBRARY}" AND EXISTS "${IMMICH_LIBCURL_INCLUDE_DIR}")
        message(STATUS "Enabling optional libcurl for ${target_name}")
        target_include_directories(${target_name} PRIVATE
            "${IMMICH_LIBCURL_INCLUDE_DIR}"
        )
        target_link_libraries(${target_name} PRIVATE
            "${IMMICH_LIBCURL_LIBRARY}"
        )
        target_compile_definitions(${target_name} PRIVATE IMMICH_OHOS_HAS_LIBCURL=1)
    endif()
endfunction()

add_library(native_buffer SHARED
    native_buffer.cpp
)

add_library(ohos_http_ffi SHARED
    ../../../../../../../package_flutter/ohos_http/ohos/src/main/cpp/ohos_http_ffi.cpp
    ../../../../../third_party/jni/src/include/dart_api_dl.c
)

target_include_directories(ohos_http_ffi PRIVATE
    ../../../../../third_party/jni/src/include
)

# N-API (ArkTS) bridge library
target_link_libraries(native_buffer PUBLIC
    ace_napi.z
)

# N-API (ArkTS) bridge library
target_link_libraries(ohos_http_ffi PUBLIC
    ace_napi.z
)

immich_enable_optional_libcurl(ohos_http_ffi)
