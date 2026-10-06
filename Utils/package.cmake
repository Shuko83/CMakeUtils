include_guard(GLOBAL)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

# CMAKE_CURRENT_LIST_DIR is the caller's inside a function: capture the template path at include time.
set(_CMU_PACKAGE_CONFIG_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/PackageConfig.cmake.in")
set(_CMU_PACKAGE_COMPONENT cmu_package)

if(NOT DEFINED cmu_package)
    set(cmu_package ON CACHE BOOL "Build a ready-to-use package of the cmu_add_target targets after the build")
endif()
if(NOT DEFINED cmu_package_dir)
    set(cmu_package_dir "${CMAKE_BINARY_DIR}/package" CACHE PATH "Where the automatic package is staged")
endif()

# Default install prefix: next to the build directory, plus the configuration on install.
# A prefix chosen by the user (-D or --prefix) is kept.
if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    # Only while the prefix is still CMake's own default: later runs keep the cached value.
    if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
        get_filename_component(_CMU_PREFIX "${CMAKE_BINARY_DIR}/../install" ABSOLUTE)
        set(CMAKE_INSTALL_PREFIX "${_CMU_PREFIX}" CACHE PATH "Install path prefix" FORCE)
        set(cmu_default_install_prefix "${_CMU_PREFIX}" CACHE INTERNAL "Default install prefix set by CMakeUtils")
    endif()
    # The configuration is only known when installing (multi-config generators).
    if(DEFINED cmu_default_install_prefix AND CMAKE_INSTALL_PREFIX STREQUAL "${cmu_default_install_prefix}")
        install(CODE "
            if(\"\${CMAKE_INSTALL_PREFIX}\" STREQUAL \"${cmu_default_install_prefix}\" AND NOT \"\${CMAKE_INSTALL_CONFIG_NAME}\" STREQUAL \"\")
                set(CMAKE_INSTALL_PREFIX \"${cmu_default_install_prefix}/\${CMAKE_INSTALL_CONFIG_NAME}\")
            endif()
        ")
    endif()
endif()

# Remembers every find_package() call so the generated Config can repeat the ones its targets need.
# Skipped when find_package is already overridden (e.g. by vcpkg): _find_package would recurse.
if(cmu_package AND NOT COMMAND _find_package)
    macro(find_package)
        string(REPLACE ";" " " _cmu_find_package_call "${ARGV}")
        set_property(GLOBAL APPEND PROPERTY CMU_FIND_PACKAGE_CALLS "${_cmu_find_package_call}")
        unset(_cmu_find_package_call)
        _find_package(${ARGV})
    endmacro()
endif()

# Generates <NAME>ConfigVersion.cmake and <NAME>Config.cmake so that find_package(<NAME>) works (see README.md).
function(cmu_add_package)
    cmake_parse_arguments(ARG
        "ARCH_INDEPENDENT"
        "NAME;VERSION;COMPATIBILITY;NAMESPACE;DESTINATION"
        "TARGETS;HEADERS;DEPENDENCIES"
        ${ARGN})

    if(DEFINED ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "cmu_add_package: unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    # An explicit call replaces the automatic package.
    set_property(GLOBAL PROPERTY CMU_PACKAGE_DONE TRUE)
    if(NOT DEFINED ARG_NAME)
        set(ARG_NAME "${PROJECT_NAME}")
    endif()
    if(NOT DEFINED ARG_VERSION)
        set(ARG_VERSION "${PROJECT_VERSION}")
    endif()
    if(ARG_VERSION STREQUAL "")
        message(FATAL_ERROR "cmu_add_package(${ARG_NAME}): VERSION is required when project() has no VERSION")
    endif()
    if(NOT DEFINED ARG_COMPATIBILITY)
        set(ARG_COMPATIBILITY SameMajorVersion)
    endif()
    if(NOT ARG_COMPATIBILITY MATCHES "^(AnyNewerVersion|SameMajorVersion|SameMinorVersion|ExactVersion)$")
        message(FATAL_ERROR "cmu_add_package(${ARG_NAME}): COMPATIBILITY must be one of "
            "AnyNewerVersion, SameMajorVersion, SameMinorVersion, ExactVersion (got '${ARG_COMPATIBILITY}')")
    endif()
    if(NOT DEFINED ARG_NAMESPACE)
        set(ARG_NAMESPACE "${ARG_NAME}::")
    endif()
    if(NOT DEFINED ARG_DESTINATION)
        set(ARG_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${ARG_NAME}")
    endif()

    set(CMU_PACKAGE_NAME "${ARG_NAME}")

    # Dependencies are find_package() argument strings, e.g. "Qt6 COMPONENTS Core".
    set(CMU_PACKAGE_DEPENDENCIES "")
    foreach(_dependency IN LISTS ARG_DEPENDENCIES)
        string(APPEND CMU_PACKAGE_DEPENDENCIES "find_dependency(${_dependency})\n")
    endforeach()

    set(CMU_PACKAGE_TARGETS "")
    if(DEFINED ARG_TARGETS)
        string(APPEND CMU_PACKAGE_TARGETS "include(\"\${CMAKE_CURRENT_LIST_DIR}/${ARG_NAME}Targets.cmake\")")

        install(TARGETS ${ARG_TARGETS}
            EXPORT ${ARG_NAME}Targets
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT ${_CMU_PACKAGE_COMPONENT}
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT ${_CMU_PACKAGE_COMPONENT}
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT ${_CMU_PACKAGE_COMPONENT}
            INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
        # Qt DLLs are not installed by install(TARGETS): deploy them next to each installed Qt executable.
        if(COMMAND _cmu_qt_install_deploy)
            foreach(_target IN LISTS ARG_TARGETS)
                _cmu_qt_install_deploy(${_target} ${_CMU_PACKAGE_COMPONENT})
            endforeach()
        endif()
        install(EXPORT ${ARG_NAME}Targets
            NAMESPACE ${ARG_NAMESPACE}
            DESTINATION ${ARG_DESTINATION}
            COMPONENT ${_CMU_PACKAGE_COMPONENT})

        # Headers default to cmu_public_headers_dir, only when it exists.
        if(NOT DEFINED ARG_HEADERS AND DEFINED cmu_public_headers_dir)
            get_filename_component(_dir "${cmu_public_headers_dir}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
            if(IS_DIRECTORY "${_dir}")
                set(ARG_HEADERS "${cmu_public_headers_dir}")
            endif()
        endif()
        foreach(_dir IN LISTS ARG_HEADERS)
            if(DEFINED cmu_headers_extension AND NOT "${cmu_headers_extension}" STREQUAL "")
                set(_patterns)
                foreach(_extension IN LISTS cmu_headers_extension)
                    list(APPEND _patterns PATTERN "*.${_extension}")
                endforeach()
                install(DIRECTORY "${_dir}/" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
                    COMPONENT ${_CMU_PACKAGE_COMPONENT} FILES_MATCHING ${_patterns})
            else()
                install(DIRECTORY "${_dir}/" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
                    COMPONENT ${_CMU_PACKAGE_COMPONENT})
            endif()
        endforeach()
    endif()

    set(_version_option)
    if(ARG_ARCH_INDEPENDENT)
        set(_version_option ARCH_INDEPENDENT)
    endif()
    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}ConfigVersion.cmake"
        VERSION ${ARG_VERSION}
        COMPATIBILITY ${ARG_COMPATIBILITY}
        ${_version_option})
    configure_package_config_file(
        "${_CMU_PACKAGE_CONFIG_TEMPLATE}"
        "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}Config.cmake"
        INSTALL_DESTINATION ${ARG_DESTINATION})

    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}Config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}ConfigVersion.cmake"
        DESTINATION ${ARG_DESTINATION}
        COMPONENT ${_CMU_PACKAGE_COMPONENT})
endfunction()

# Packages every cmu_add_target target; runs at the end of the directory that included this file.
function(_cmu_package_finalize)
    get_property(_done GLOBAL PROPERTY CMU_PACKAGE_DONE)
    get_property(_targets GLOBAL PROPERTY CMU_PACKAGE_TARGETS)
    if(_done OR NOT _targets)
        return()
    endif()

    set(_version "${PROJECT_VERSION}")
    if(_version STREQUAL "")
        set(_version 0.0.0)
        message(STATUS "CMakeUtils: project() has no VERSION, the package is versioned 0.0.0")
    endif()

    get_property(_headers GLOBAL PROPERTY CMU_PACKAGE_HEADERS)
    set(_headers_option)
    if(_headers)
        list(REMOVE_DUPLICATES _headers)
        set(_headers_option HEADERS ${_headers})
    endif()

    # Keep the find_package() calls whose Pkg::Target names are linked by a packaged target.
    set(_linked)
    foreach(_target IN LISTS _targets)
        get_target_property(_link_libraries ${_target} LINK_LIBRARIES)
        get_target_property(_interface_libraries ${_target} INTERFACE_LINK_LIBRARIES)
        foreach(_library IN LISTS _link_libraries _interface_libraries)
            if(_library MATCHES "^([A-Za-z0-9_+.-]+)::")
                string(TOLOWER "${CMAKE_MATCH_1}" _package)
                list(APPEND _linked ${_package})
            endif()
        endforeach()
    endforeach()
    get_property(_calls GLOBAL PROPERTY CMU_FIND_PACKAGE_CALLS)
    set(_dependencies)
    foreach(_call IN LISTS _calls)
        string(REGEX MATCH "^[^ ]+" _package "${_call}")
        string(TOLOWER "${_package}" _package)
        list(FIND _linked "${_package}" _index)
        if(NOT _index EQUAL -1)
            list(APPEND _dependencies "${_call}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _dependencies)
    set(_dependencies_option)
    if(_dependencies)
        set(_dependencies_option DEPENDENCIES ${_dependencies})
    endif()

    cmu_add_package(NAME ${PROJECT_NAME} VERSION ${_version} TARGETS ${_targets}
        ${_headers_option} ${_dependencies_option})

    # ALL + dependencies: the package is staged right after the last target is built.
    add_custom_target(cmu_package ALL
        COMMAND ${CMAKE_COMMAND} --install "${CMAKE_BINARY_DIR}" --config $<CONFIG>
            --component ${_CMU_PACKAGE_COMPONENT} --prefix "${cmu_package_dir}"
        COMMENT "CMakeUtils: staging the ${PROJECT_NAME} package in ${cmu_package_dir}"
        VERBATIM)
    add_dependencies(cmu_package ${_targets})
endfunction()

if(cmu_package)
    if(CMAKE_VERSION VERSION_LESS 3.19)
        message(STATUS "CMakeUtils: the automatic package needs CMake 3.19 (cmu_add_package still works)")
    else()
        cmake_language(DEFER DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" CALL _cmu_package_finalize)
    endif()
endif()
