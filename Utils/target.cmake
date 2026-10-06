include_guard(GLOBAL)

# Creates a target; each keyword is forwarded to the matching target_*() command (see README.md).
macro(cmu_add_target)
    # TYPE takes a value, not a flag, so INTERFACE stays usable as a scope keyword in the lists.
    cmake_parse_arguments(_ADD_TARGET
        ""
        "NAME;TYPE;SHARED_EXTENSION"
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

    # INTERFACE_SOURCES is exported by install(EXPORT): source-tree paths must not leak into it.
    if(_ADD_TARGET_TYPE STREQUAL "INTERFACE")
        set(_ADD_TARGET_BUILD_SOURCES)
        foreach(_ADD_TARGET_SOURCE IN LISTS _ADD_TARGET_RESOLVED_SOURCES)
            if("${_ADD_TARGET_SOURCE}" MATCHES "^\\$<")
                list(APPEND _ADD_TARGET_BUILD_SOURCES "${_ADD_TARGET_SOURCE}")
            else()
                list(APPEND _ADD_TARGET_BUILD_SOURCES "$<BUILD_INTERFACE:${_ADD_TARGET_SOURCE}>")
            endif()
        endforeach()
        set(_ADD_TARGET_RESOLVED_SOURCES ${_ADD_TARGET_BUILD_SOURCES})
    endif()

    if(_ADD_TARGET_TYPE STREQUAL "EXECUTABLE")
        add_executable(${_ADD_TARGET_NAME} ${_ADD_TARGET_RESOLVED_SOURCES})
    else()
        add_library(${_ADD_TARGET_NAME} ${_ADD_TARGET_TYPE} ${_ADD_TARGET_RESOLVED_SOURCES})
    endif()

    # The extension is accepted with or without its leading dot; SUFFIX needs the dot.
    if(DEFINED _ADD_TARGET_SHARED_EXTENSION)
        if(_ADD_TARGET_TYPE STREQUAL "SHARED")
            string(REGEX REPLACE "^\\." "" _ADD_TARGET_SHARED_EXTENSION "${_ADD_TARGET_SHARED_EXTENSION}")
            if(_ADD_TARGET_SHARED_EXTENSION STREQUAL "")
                set_target_properties(${_ADD_TARGET_NAME} PROPERTIES SUFFIX "")
            else()
                set_target_properties(${_ADD_TARGET_NAME} PROPERTIES SUFFIX ".${_ADD_TARGET_SHARED_EXTENSION}")
            endif()
        else()
            message(WARNING "cmu_add_target(${_ADD_TARGET_NAME}): SHARED_EXTENSION is ignored for TYPE ${_ADD_TARGET_TYPE}")
        endif()
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
            # Source-tree path: usable from the build tree only (cmu_add_package sets the installed one).
            target_include_directories(${_ADD_TARGET_NAME} ${_ADD_TARGET_HEADER_SCOPE} "$<BUILD_INTERFACE:${_ADD_TARGET_DIR}>")
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

    # Collected for the automatic package (package.cmake); an OBJECT library cannot be exported.
    if(NOT _ADD_TARGET_TYPE STREQUAL "OBJECT")
        set_property(GLOBAL APPEND PROPERTY CMU_PACKAGE_TARGETS ${_ADD_TARGET_NAME})
        if(DEFINED cmu_public_headers_dir)
            get_filename_component(_ADD_TARGET_DIR "${cmu_public_headers_dir}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
            if(IS_DIRECTORY "${_ADD_TARGET_DIR}")
                set_property(GLOBAL APPEND PROPERTY CMU_PACKAGE_HEADERS "${_ADD_TARGET_DIR}")
            endif()
        endif()
    endif()

    # Deferred to the end of this directory: add_custom_command(TARGET) is limited to the target's directory.
    # EVAL bakes the name in: deferred arguments are expanded late, after the cleanup below.
    if(_ADD_TARGET_TYPE STREQUAL "EXECUTABLE" AND COMMAND _cmu_qt_deploy AND NOT CMAKE_VERSION VERSION_LESS 3.19)
        cmake_language(EVAL CODE "cmake_language(DEFER CALL _cmu_qt_deploy [[${_ADD_TARGET_NAME}]])")
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

# Shortcuts for cmu_add_target: same keywords, TYPE is fixed by the macro.
macro(cmu_add_executable)
    cmu_add_target(${ARGN} TYPE EXECUTABLE)
endmacro()

macro(cmu_add_static_library)
    cmu_add_target(${ARGN} TYPE STATIC)
endmacro()

macro(cmu_add_shared_library)
    cmu_add_target(${ARGN} TYPE SHARED)
endmacro()

macro(cmu_add_interface_library)
    cmu_add_target(${ARGN} TYPE INTERFACE)
endmacro()

macro(cmu_add_object_library)
    cmu_add_target(${ARGN} TYPE OBJECT)
endmacro()
