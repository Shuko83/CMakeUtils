# Copyright (C) 2026 Fabien Di Grande
# SPDX-License-Identifier: MPL-2.0

include_guard(GLOBAL)

# Downloads <url> with file(DOWNLOAD) (CMake's built-in libcurl) into <build>/_downloads and extracts it in
# <destination>, once: the archive is kept, and only a new URL extracts again.
function(_cmu_download_archive url sha256 destination)
    if(CMAKE_VERSION VERSION_LESS 3.18)
        message(FATAL_ERROR "cmu_download_package requires CMake 3.18 (file(ARCHIVE_EXTRACT))")
    endif()

    get_filename_component(_name "${url}" NAME)
    set(_archive "${CMAKE_BINARY_DIR}/_downloads/${_name}")
    # Records which URL was extracted, so that a new version extracts again.
    set(_stamp "${destination}/.cmu_download")

    if(EXISTS "${_archive}" AND sha256)
        file(SHA256 "${_archive}" _actual)
        if(NOT _actual STREQUAL sha256)
            file(REMOVE "${_archive}")
        endif()
    endif()

    if(NOT EXISTS "${_archive}")
        set(_hash_option "")
        if(sha256)
            set(_hash_option EXPECTED_HASH "SHA256=${sha256}")
        endif()

        message(STATUS "Downloading ${url}")
        # Temporary name: an interrupted download is not mistaken for a complete archive.
        file(DOWNLOAD "${url}" "${_archive}.part"
            ${_hash_option}
            TLS_VERIFY ON
            INACTIVITY_TIMEOUT 60
            STATUS _status
            LOG _log
        )
        list(GET _status 0 _code)
        if(NOT _code EQUAL 0)
            list(GET _status 1 _message)
            file(REMOVE "${_archive}.part")
            message(FATAL_ERROR "cmu_download_package: cannot download ${url}: ${_message} (curl code ${_code})\n${_log}")
        endif()
        file(RENAME "${_archive}.part" "${_archive}")
    endif()

    set(_extracted "")
    if(EXISTS "${_stamp}")
        file(READ "${_stamp}" _extracted)
    endif()
    if(NOT _extracted STREQUAL url)
        message(STATUS "Extracting ${_name} to ${destination}")
        set(_extract_dir "${destination}.extract")
        file(REMOVE_RECURSE "${destination}" "${_extract_dir}")
        file(ARCHIVE_EXTRACT INPUT "${_archive}" DESTINATION "${_extract_dir}")

        # A release archive usually wraps everything in one folder (Name-1.0.0-x64/): strip it,
        # so that <destination> is the package prefix.
        file(GLOB _entries LIST_DIRECTORIES true "${_extract_dir}/*")
        list(LENGTH _entries _count)
        if(_count EQUAL 1 AND IS_DIRECTORY "${_entries}")
            file(RENAME "${_entries}" "${destination}")
            file(REMOVE_RECURSE "${_extract_dir}")
        else()
            file(RENAME "${_extract_dir}" "${destination}")
        endif()
        file(WRITE "${_stamp}" "${url}")
    endif()
endfunction()

# cmu_download_package(NAME <package> URL <url> [SHA256 <hash>] [DESTINATION <dir>] [FIND_PACKAGE_ARGS <args>...])
# A macro, so that find_package() runs in the caller's scope: the variables set by the package's Config
# (<package>_FOUND, its dependencies' variables, paths captured at include time) stay visible.
macro(cmu_download_package)
    cmake_parse_arguments(_CMU_DOWNLOAD "" "NAME;URL;SHA256;DESTINATION" "FIND_PACKAGE_ARGS" ${ARGN})
    if(_CMU_DOWNLOAD_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "cmu_download_package: unknown arguments: ${_CMU_DOWNLOAD_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT _CMU_DOWNLOAD_NAME OR NOT _CMU_DOWNLOAD_URL)
        message(FATAL_ERROR "cmu_download_package: NAME and URL are required")
    endif()
    if(NOT _CMU_DOWNLOAD_DESTINATION)
        set(_CMU_DOWNLOAD_DESTINATION "${CMAKE_BINARY_DIR}/_deps/${_CMU_DOWNLOAD_NAME}")
    endif()
    get_filename_component(_CMU_DOWNLOAD_DESTINATION "${_CMU_DOWNLOAD_DESTINATION}" ABSOLUTE
        BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")

    _cmu_download_archive("${_CMU_DOWNLOAD_URL}" "${_CMU_DOWNLOAD_SHA256}" "${_CMU_DOWNLOAD_DESTINATION}")

    # Found through CMAKE_PREFIX_PATH rather than PATHS: the recorded find_package() call, repeated in the
    # generated Config.cmake files, must not contain a path of this build tree.
    if(NOT _CMU_DOWNLOAD_DESTINATION IN_LIST CMAKE_PREFIX_PATH)
        list(APPEND CMAKE_PREFIX_PATH "${_CMU_DOWNLOAD_DESTINATION}")
    endif()
    find_package(${_CMU_DOWNLOAD_NAME} ${_CMU_DOWNLOAD_FIND_PACKAGE_ARGS})

    unset(_CMU_DOWNLOAD_NAME)
    unset(_CMU_DOWNLOAD_URL)
    unset(_CMU_DOWNLOAD_SHA256)
    unset(_CMU_DOWNLOAD_DESTINATION)
    unset(_CMU_DOWNLOAD_FIND_PACKAGE_ARGS)
    unset(_CMU_DOWNLOAD_UNPARSED_ARGUMENTS)
    unset(_CMU_DOWNLOAD_KEYWORDS_MISSING_VALUES)
endmacro()
