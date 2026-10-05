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

    if(_ADD_TARGET_TYPE STREQUAL "EXECUTABLE")
        add_executable(${_ADD_TARGET_NAME} ${_ADD_TARGET_SOURCES})
    else()
        add_library(${_ADD_TARGET_NAME} ${_ADD_TARGET_TYPE} ${_ADD_TARGET_SOURCES})
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
