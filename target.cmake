include_guard(GLOBAL)

# Creates a target; each keyword is forwarded to the matching target_*() command (see README.md).
macro(cmu_add_target)
    # TYPE takes a value, not a flag, so INTERFACE stays usable as a scope keyword in the lists.
    cmake_parse_arguments(_ADD_TARGET
        ""
        "NAME;TYPE"
        "SOURCES;INCLUDE_DIRECTORIES;COMPILE_DEFINITIONS;COMPILE_OPTIONS;COMPILE_FEATURES;LINK_LIBRARIES;LINK_OPTIONS"
        ${ARGN})

    if(DEFINED _ADD_TARGET_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "cmu_add_target: unknown arguments: ${_ADD_TARGET_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT DEFINED _ADD_TARGET_NAME)
        message(FATAL_ERROR "cmu_add_target: NAME is required")
    endif()
    if(NOT "${_ADD_TARGET_TYPE}" MATCHES "^(EXECUTABLE|STATIC|SHARED|MODULE|OBJECT|INTERFACE)$")
        message(FATAL_ERROR "cmu_add_target(${_ADD_TARGET_NAME}): TYPE must be one of "
            "EXECUTABLE, STATIC, SHARED, MODULE, OBJECT, INTERFACE (got '${_ADD_TARGET_TYPE}')")
    endif()

    # Explicit sources: relative ones resolve against cmu_sources_dir; generator expressions are kept as is.
    set(_ADD_TARGET_RESOLVED_SOURCES)
    foreach(_ADD_TARGET_SOURCE IN LISTS _ADD_TARGET_SOURCES)
        if("${_ADD_TARGET_SOURCE}" MATCHES "^\\$<")
            list(APPEND _ADD_TARGET_RESOLVED_SOURCES "${_ADD_TARGET_SOURCE}")
        else()
            if(DEFINED cmu_sources_dir AND NOT IS_ABSOLUTE "${_ADD_TARGET_SOURCE}")
                set(_ADD_TARGET_SOURCE "${cmu_sources_dir}/${_ADD_TARGET_SOURCE}")
            endif()
            get_filename_component(_ADD_TARGET_PATH "${_ADD_TARGET_SOURCE}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
            list(APPEND _ADD_TARGET_RESOLVED_SOURCES "${_ADD_TARGET_PATH}")
        endif()
    endforeach()

    # Every source/header found in the default directories joins the target (an INTERFACE target compiles no source).
    if(DEFINED cmu_sources_dir AND DEFINED cmu_sources_extension AND NOT _ADD_TARGET_TYPE STREQUAL "INTERFACE")
        get_filename_component(_ADD_TARGET_DIR "${cmu_sources_dir}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        foreach(_ADD_TARGET_EXT IN LISTS cmu_sources_extension)
            file(GLOB_RECURSE _ADD_TARGET_FOUND CONFIGURE_DEPENDS "${_ADD_TARGET_DIR}/*.${_ADD_TARGET_EXT}")
            list(APPEND _ADD_TARGET_RESOLVED_SOURCES ${_ADD_TARGET_FOUND})
        endforeach()
    endif()
    # Sources on an INTERFACE target need CMake 3.19.
    if(DEFINED cmu_public_headers_dir AND DEFINED cmu_headers_extension
            AND (NOT _ADD_TARGET_TYPE STREQUAL "INTERFACE" OR NOT CMAKE_VERSION VERSION_LESS 3.19))
        get_filename_component(_ADD_TARGET_DIR "${cmu_public_headers_dir}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        foreach(_ADD_TARGET_EXT IN LISTS cmu_headers_extension)
            file(GLOB_RECURSE _ADD_TARGET_FOUND CONFIGURE_DEPENDS "${_ADD_TARGET_DIR}/*.${_ADD_TARGET_EXT}")
            list(APPEND _ADD_TARGET_RESOLVED_SOURCES ${_ADD_TARGET_FOUND})
        endforeach()
    endif()
    list(REMOVE_DUPLICATES _ADD_TARGET_RESOLVED_SOURCES)

    if(_ADD_TARGET_TYPE STREQUAL "EXECUTABLE")
        add_executable(${_ADD_TARGET_NAME} ${_ADD_TARGET_RESOLVED_SOURCES})
    else()
        add_library(${_ADD_TARGET_NAME} ${_ADD_TARGET_TYPE} ${_ADD_TARGET_RESOLVED_SOURCES})
    endif()

    # Default include directories, only when they exist (relative paths resolve against the caller).
    if(_ADD_TARGET_TYPE STREQUAL "INTERFACE")
        set(_ADD_TARGET_HEADER_SCOPE INTERFACE)
    else()
        set(_ADD_TARGET_HEADER_SCOPE PUBLIC)
    endif()
    if(DEFINED cmu_public_headers_dir)
        get_filename_component(_ADD_TARGET_DIR "${cmu_public_headers_dir}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        if(IS_DIRECTORY "${_ADD_TARGET_DIR}")
            target_include_directories(${_ADD_TARGET_NAME} ${_ADD_TARGET_HEADER_SCOPE} "${cmu_public_headers_dir}")
        endif()
    endif()
    if(DEFINED cmu_sources_dir AND NOT _ADD_TARGET_TYPE STREQUAL "INTERFACE")
        get_filename_component(_ADD_TARGET_DIR "${cmu_sources_dir}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        if(IS_DIRECTORY "${_ADD_TARGET_DIR}")
            target_include_directories(${_ADD_TARGET_NAME} PRIVATE "${cmu_sources_dir}")
        endif()
    endif()

    # DEFINED rather than truthiness: a list ending in "-NOTFOUND" would evaluate to false.
    if(DEFINED _ADD_TARGET_INCLUDE_DIRECTORIES)
        target_include_directories(${_ADD_TARGET_NAME} ${_ADD_TARGET_INCLUDE_DIRECTORIES})
    endif()
    if(DEFINED _ADD_TARGET_COMPILE_DEFINITIONS)
        target_compile_definitions(${_ADD_TARGET_NAME} ${_ADD_TARGET_COMPILE_DEFINITIONS})
    endif()
    if(DEFINED _ADD_TARGET_COMPILE_OPTIONS)
        target_compile_options(${_ADD_TARGET_NAME} ${_ADD_TARGET_COMPILE_OPTIONS})
    endif()
    if(DEFINED _ADD_TARGET_COMPILE_FEATURES)
        target_compile_features(${_ADD_TARGET_NAME} ${_ADD_TARGET_COMPILE_FEATURES})
    endif()
    if(DEFINED _ADD_TARGET_LINK_LIBRARIES)
        target_link_libraries(${_ADD_TARGET_NAME} ${_ADD_TARGET_LINK_LIBRARIES})
    endif()
    if(DEFINED _ADD_TARGET_LINK_OPTIONS)
        target_link_options(${_ADD_TARGET_NAME} ${_ADD_TARGET_LINK_OPTIONS})
    endif()

    # A macro runs in the caller's scope: drop every temporary variable.
    get_cmake_property(_ADD_TARGET_VARIABLES VARIABLES)
    list(FILTER _ADD_TARGET_VARIABLES INCLUDE REGEX "^_ADD_TARGET_")
    foreach(_ADD_TARGET_VARIABLE IN LISTS _ADD_TARGET_VARIABLES)
        unset(${_ADD_TARGET_VARIABLE})
    endforeach()
    unset(_ADD_TARGET_VARIABLES)
    unset(_ADD_TARGET_VARIABLE)
endmacro()
