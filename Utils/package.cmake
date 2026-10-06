include_guard(GLOBAL)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)

# CMAKE_CURRENT_LIST_DIR is the caller's inside a function: capture the template path at include time.
set(_CMU_PACKAGE_CONFIG_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/PackageConfig.cmake.in")
set(_CMU_COMPONENTS_CONFIG_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/PackageComponentsConfig.cmake.in")
set(_CMU_PACKAGE_COMPONENT cmu_package)

if(NOT DEFINED cmu_package)
    set(cmu_package ON CACHE BOOL "Build a ready-to-use package of the cmu_add_target targets after the build")
endif()
if(NOT DEFINED cmu_package_dir)
    set(cmu_package_dir "${CMAKE_BINARY_DIR}/package" CACHE PATH "Where the automatic package is staged")
endif()
if(NOT DEFINED cmu_install_mode)
    set(cmu_install_mode TARGET CACHE STRING "TARGET: <target>/<config> per target; PACKAGE: one prefix with Config files")
    set_property(CACHE cmu_install_mode PROPERTY STRINGS TARGET PACKAGE)
endif()
if(NOT cmu_install_mode MATCHES "^(TARGET|PACKAGE)$")
    message(FATAL_ERROR "CMakeUtils: cmu_install_mode must be TARGET or PACKAGE (got '${cmu_install_mode}')")
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
    # The configuration is only known when installing (multi-config generators). TARGET mode puts it after the target.
    if(cmu_install_mode STREQUAL "PACKAGE" AND DEFINED cmu_default_install_prefix
            AND CMAKE_INSTALL_PREFIX STREQUAL "${cmu_default_install_prefix}")
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

# Installs the headers of <directory> (filtered by cmu_headers_extension) in <destination>.
function(_cmu_install_headers directory destination)
    if(DEFINED cmu_headers_extension AND NOT "${cmu_headers_extension}" STREQUAL "")
        set(_patterns)
        foreach(_extension IN LISTS cmu_headers_extension)
            list(APPEND _patterns PATTERN "*.${_extension}")
        endforeach()
        install(DIRECTORY "${directory}/" DESTINATION "${destination}"
            COMPONENT ${_CMU_PACKAGE_COMPONENT} FILES_MATCHING ${_patterns})
    else()
        install(DIRECTORY "${directory}/" DESTINATION "${destination}"
            COMPONENT ${_CMU_PACKAGE_COMPONENT})
    endif()
endfunction()

# Sets <result> to the SHARED library targets of this project reached from <target>.
function(_cmu_shared_dependencies target result)
    set(_pending ${target})
    set(_visited)
    set(_shared)
    while(_pending)
        list(POP_FRONT _pending _current)
        if(_current IN_LIST _visited)
            continue()
        endif()
        list(APPEND _visited ${_current})
        if(TARGET ${_current})
            get_target_property(_imported ${_current} IMPORTED)
            if(NOT _imported)
                get_target_property(_type ${_current} TYPE)
                if(_type STREQUAL "SHARED_LIBRARY")
                    list(APPEND _shared ${_current})
                endif()
                get_target_property(_link_libraries ${_current} LINK_LIBRARIES)
                get_target_property(_interface_libraries ${_current} INTERFACE_LINK_LIBRARIES)
                foreach(_library IN LISTS _link_libraries _interface_libraries)
                    if(_library MATCHES "^\\$<LINK_ONLY:([^>]+)>$")
                        set(_library "${CMAKE_MATCH_1}")
                    endif()
                    if(_library AND NOT _library MATCHES "NOTFOUND$")
                        list(APPEND _pending "${_library}")
                    endif()
                endforeach()
            endif()
        endif()
    endwhile()
    set(${result} "${_shared}" PARENT_SCOPE)
endfunction()

# Sets <result> to the find_package() calls whose Pkg::Target names are linked by one of <targets>.
function(_cmu_deduce_dependencies targets result)
    set(_linked)
    foreach(_target IN LISTS targets)
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
    set(${result} "${_dependencies}" PARENT_SCOPE)
endfunction()

# Installs each target on its own in <prefix>/<target>/<config>/{bin,lib,include}, ready to use:
# an executable also gets the shared libraries of the project (and Qt) it needs.
# Every target is a component of the package <NAME> (find_package(<NAME> COMPONENTS <target>)):
#   <prefix>/<target>/cmake/   <target>Config.cmake and <target>Targets.cmake
#   <prefix>/                  <NAME>Config.cmake and <NAME>ConfigVersion.cmake
function(cmu_install_targets)
    cmake_parse_arguments(ARG "" "NAME;VERSION;COMPATIBILITY;NAMESPACE" "TARGETS" ${ARGN})
    if(DEFINED ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "cmu_install_targets: unknown arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    # An explicit call replaces the automatic install.
    set_property(GLOBAL PROPERTY CMU_PACKAGE_DONE TRUE)
    if(NOT DEFINED ARG_NAME)
        set(ARG_NAME "${PROJECT_NAME}")
    endif()
    if(NOT DEFINED ARG_VERSION)
        set(ARG_VERSION "${PROJECT_VERSION}")
    endif()
    if(ARG_VERSION STREQUAL "")
        set(ARG_VERSION 0.0.0)
    endif()
    if(NOT DEFINED ARG_COMPATIBILITY)
        set(ARG_COMPATIBILITY SameMajorVersion)
    endif()
    if(NOT ARG_COMPATIBILITY MATCHES "^(AnyNewerVersion|SameMajorVersion|SameMinorVersion|ExactVersion)$")
        message(FATAL_ERROR "cmu_install_targets(${ARG_NAME}): COMPATIBILITY must be one of "
            "AnyNewerVersion, SameMajorVersion, SameMinorVersion, ExactVersion (got '${ARG_COMPATIBILITY}')")
    endif()
    if(NOT DEFINED ARG_NAMESPACE)
        set(ARG_NAMESPACE "${ARG_NAME}::")
    endif()

    set(_component_cmake "cmake")
    foreach(_target IN LISTS ARG_TARGETS)
        set(_root "${_target}/$<CONFIG>")
        set(_headers)
        set(_cmake_dir "${_target}/${_component_cmake}")
        install(TARGETS ${_target}
            EXPORT ${_target}Targets
            RUNTIME DESTINATION ${_root}/${CMAKE_INSTALL_BINDIR} COMPONENT ${_CMU_PACKAGE_COMPONENT}
            LIBRARY DESTINATION ${_root}/${CMAKE_INSTALL_LIBDIR} COMPONENT ${_CMU_PACKAGE_COMPONENT}
            ARCHIVE DESTINATION ${_root}/${CMAKE_INSTALL_LIBDIR} COMPONENT ${_CMU_PACKAGE_COMPONENT})

        get_target_property(_type ${_target} TYPE)
        if(_type STREQUAL "EXECUTABLE")
            _cmu_shared_dependencies(${_target} _shared)
            foreach(_dependency IN LISTS _shared)
                install(FILES "$<TARGET_FILE:${_dependency}>"
                    DESTINATION ${_root}/${CMAKE_INSTALL_BINDIR} COMPONENT ${_CMU_PACKAGE_COMPONENT})
            endforeach()
            # The config name is read at install time: it is a runtime variable here, not a generator expression.
            if(COMMAND _cmu_qt_install_deploy)
                _cmu_qt_install_deploy(${_target} ${_CMU_PACKAGE_COMPONENT}
                    "${_target}/\${CMAKE_INSTALL_CONFIG_NAME}/${CMAKE_INSTALL_BINDIR}")
            endif()
        else()
            get_property(_headers GLOBAL PROPERTY CMU_HEADERS_${_target})
            if(_headers)
                _cmu_install_headers("${_headers}" "${_root}/${CMAKE_INSTALL_INCLUDEDIR}")
            endif()
            get_property(_generated GLOBAL PROPERTY CMU_GENERATED_HEADER_${_target})
            if(_generated)
                install(FILES "${_generated}" DESTINATION ${_root}/${CMAKE_INSTALL_INCLUDEDIR}
                    COMPONENT ${_CMU_PACKAGE_COMPONENT})
                set(_headers TRUE)
            endif()
        endif()
        install(EXPORT ${_target}Targets
            NAMESPACE ${ARG_NAMESPACE}
            DESTINATION ${_cmake_dir}
            COMPONENT ${_CMU_PACKAGE_COMPONENT})

        # Component Config: its own find_package() dependencies, then the components it links.
        set(CMU_PACKAGE_NAME "${_target}")
        set(CMU_PACKAGE_DEPENDENCIES "")
        _cmu_deduce_dependencies(${_target} _dependencies)
        foreach(_dependency IN LISTS _dependencies)
            string(APPEND CMU_PACKAGE_DEPENDENCIES "find_dependency(${_dependency})\n")
        endforeach()
        get_target_property(_link_libraries ${_target} LINK_LIBRARIES)
        get_target_property(_interface_libraries ${_target} INTERFACE_LINK_LIBRARIES)
        foreach(_library IN LISTS _link_libraries _interface_libraries)
            if(_library MATCHES "^\\$<LINK_ONLY:([^>]+)>$")
                set(_library "${CMAKE_MATCH_1}")
            endif()
            list(FIND ARG_TARGETS "${_library}" _index)
            if(NOT _index EQUAL -1 AND NOT _library STREQUAL _target)
                string(APPEND CMU_PACKAGE_DEPENDENCIES
                    "include(\"\${PACKAGE_PREFIX_DIR}/${_library}/${_component_cmake}/${_library}Config.cmake\")\n")
            endif()
        endforeach()
        set(CMU_PACKAGE_TARGETS "if(NOT TARGET ${ARG_NAMESPACE}${_target})\n")
        string(APPEND CMU_PACKAGE_TARGETS "    include(\"\${CMAKE_CURRENT_LIST_DIR}/${_target}Targets.cmake\")\n")
        if(_headers)
            # Headers are the same in every configuration: use the first installed one, whatever the consumer's config.
            string(APPEND CMU_PACKAGE_TARGETS
                "    file(GLOB _cmu_include_dirs \"\${PACKAGE_PREFIX_DIR}/${_target}/*/${CMAKE_INSTALL_INCLUDEDIR}\")\n"
                "    list(GET _cmu_include_dirs 0 _cmu_include_dir)\n"
                "    set_property(TARGET ${ARG_NAMESPACE}${_target} APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES \"\${_cmu_include_dir}\")\n")
        endif()
        string(APPEND CMU_PACKAGE_TARGETS "endif()")
        configure_package_config_file(
            "${_CMU_PACKAGE_CONFIG_TEMPLATE}"
            "${CMAKE_CURRENT_BINARY_DIR}/cmu/${_target}/${_target}Config.cmake"
            INSTALL_DESTINATION ${_cmake_dir})
        install(FILES "${CMAKE_CURRENT_BINARY_DIR}/cmu/${_target}/${_target}Config.cmake"
            DESTINATION ${_cmake_dir} COMPONENT ${_CMU_PACKAGE_COMPONENT})
    endforeach()

    # Global package: loads the requested components (all by default).
    set(_global_dir ".")
    set(CMU_PACKAGE_NAME "${ARG_NAME}")
    set(CMU_COMPONENTS "${ARG_TARGETS}")
    set(CMU_COMPONENT_CMAKE_DIR "${_component_cmake}")
    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/cmu/${ARG_NAME}ConfigVersion.cmake"
        VERSION ${ARG_VERSION}
        COMPATIBILITY ${ARG_COMPATIBILITY})
    configure_package_config_file(
        "${_CMU_COMPONENTS_CONFIG_TEMPLATE}"
        "${CMAKE_CURRENT_BINARY_DIR}/cmu/${ARG_NAME}Config.cmake"
        INSTALL_DESTINATION ${_global_dir})
    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/cmu/${ARG_NAME}Config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/cmu/${ARG_NAME}ConfigVersion.cmake"
        DESTINATION ${_global_dir}
        COMPONENT ${_CMU_PACKAGE_COMPONENT})
endfunction()

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
                _cmu_qt_install_deploy(${_target} ${_CMU_PACKAGE_COMPONENT} "${CMAKE_INSTALL_BINDIR}")
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
            _cmu_install_headers("${_dir}" "${CMAKE_INSTALL_INCLUDEDIR}")
        endforeach()
        foreach(_target IN LISTS ARG_TARGETS)
            get_property(_generated GLOBAL PROPERTY CMU_GENERATED_HEADER_${_target})
            if(_generated)
                install(FILES "${_generated}" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} COMPONENT ${_CMU_PACKAGE_COMPONENT})
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

# ALL + dependencies: the install is staged in cmu_package_dir right after the last target is built.
function(_cmu_stage_package)
    add_custom_target(cmu_package ALL
        COMMAND ${CMAKE_COMMAND} --install "${CMAKE_BINARY_DIR}" --config $<CONFIG>
            --component ${_CMU_PACKAGE_COMPONENT} --prefix "${cmu_package_dir}"
        COMMENT "CMakeUtils: staging ${PROJECT_NAME} in ${cmu_package_dir}"
        VERBATIM)
    add_dependencies(cmu_package ${ARGN})
endfunction()

# Installs every cmu_add_target target; runs at the end of the directory that included this file.
function(_cmu_package_finalize)
    get_property(_done GLOBAL PROPERTY CMU_PACKAGE_DONE)
    get_property(_targets GLOBAL PROPERTY CMU_PACKAGE_TARGETS)
    if(_done OR NOT _targets)
        return()
    endif()

    if(cmu_install_mode STREQUAL "TARGET")
        cmu_install_targets(TARGETS ${_targets})
        _cmu_stage_package(${_targets})
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

    _cmu_deduce_dependencies("${_targets}" _dependencies)
    set(_dependencies_option)
    if(_dependencies)
        set(_dependencies_option DEPENDENCIES ${_dependencies})
    endif()

    cmu_add_package(NAME ${PROJECT_NAME} VERSION ${_version} TARGETS ${_targets}
        ${_headers_option} ${_dependencies_option})
    _cmu_stage_package(${_targets})
endfunction()

if(cmu_package)
    if(CMAKE_VERSION VERSION_LESS 3.19)
        message(STATUS "CMakeUtils: the automatic package needs CMake 3.19 (cmu_add_package still works)")
    else()
        cmake_language(DEFER DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" CALL _cmu_package_finalize)
    endif()
endif()
