include_guard(GLOBAL)

include(GenerateExportHeader)

set(_CMU_TEMPLATE_DIR "${CMAKE_CURRENT_LIST_DIR}/../Template")

# Creates a target; each keyword is forwarded to the matching target_*() command (see README.md).
macro(cmu_add_target)
    # TYPE takes a value, not a flag, so INTERFACE stays usable as a scope keyword in the lists.
    cmake_parse_arguments(_ADD_TARGET
        ""
        "NAME;TYPE;SHARED_EXTENSION;NAMESPACE;VERSION"
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

    # NAMESPACE is accepted with or without its trailing "::".
    if(DEFINED _ADD_TARGET_NAMESPACE AND NOT _ADD_TARGET_NAMESPACE STREQUAL "")
        string(REGEX REPLACE "(::)?$" "" _ADD_TARGET_NAMESPACE "${_ADD_TARGET_NAMESPACE}")
        if(_ADD_TARGET_TYPE STREQUAL "EXECUTABLE")
            add_executable(${_ADD_TARGET_NAMESPACE}::${_ADD_TARGET_NAME} ALIAS ${_ADD_TARGET_NAME})
        else()
            add_library(${_ADD_TARGET_NAMESPACE}::${_ADD_TARGET_NAME} ALIAS ${_ADD_TARGET_NAME})
        endif()
    endif()

    # The extension is accepted with or without its leading dot; SUFFIX needs the dot.
    if(DEFINED _ADD_TARGET_SHARED_EXTENSION)
        if(_ADD_TARGET_TYPE MATCHES "^(SHARED|MODULE)$")
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

    # Public <NAME>_export.h (<NAME>_EXPORT), generated in the build tree and installed with the public headers.
    set(_ADD_TARGET_AUTOGEN_FILES)
    if(NOT _ADD_TARGET_TYPE MATCHES "^(INTERFACE|EXECUTABLE)$")
        set(_ADD_TARGET_PUBLIC_DIR "${CMAKE_CURRENT_BINARY_DIR}/${_ADD_TARGET_NAME}_autogen/cmu/public")
        set(_ADD_TARGET_EXPORT_FILE "${_ADD_TARGET_PUBLIC_DIR}/${_ADD_TARGET_NAME}_export.h")
        generate_export_header(${_ADD_TARGET_NAME} EXPORT_FILE_NAME "${_ADD_TARGET_EXPORT_FILE}")
        # A static library must not import its own symbols: the macro stays empty with <NAME>_STATIC_DEFINE.
        if(NOT _ADD_TARGET_TYPE MATCHES "^(SHARED|MODULE)$")
            string(MAKE_C_IDENTIFIER "${_ADD_TARGET_NAME}" _ADD_TARGET_UPPER)
            string(TOUPPER "${_ADD_TARGET_UPPER}" _ADD_TARGET_UPPER)
            target_compile_definitions(${_ADD_TARGET_NAME} PUBLIC ${_ADD_TARGET_UPPER}_STATIC_DEFINE)
        endif()
        target_sources(${_ADD_TARGET_NAME} PRIVATE "${_ADD_TARGET_EXPORT_FILE}")
        list(APPEND _ADD_TARGET_AUTOGEN_FILES "${_ADD_TARGET_EXPORT_FILE}")
        target_include_directories(${_ADD_TARGET_NAME} PUBLIC "$<BUILD_INTERFACE:${_ADD_TARGET_PUBLIC_DIR}>")
        set_property(GLOBAL PROPERTY CMU_GENERATED_HEADER_${_ADD_TARGET_NAME} "${_ADD_TARGET_EXPORT_FILE}")
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

    # Info files <NAME>_info.h/.cpp, generated in <target>_autogen/cmu, next to Qt's generated files.
    if(NOT _ADD_TARGET_TYPE STREQUAL "INTERFACE")
        string(MAKE_C_IDENTIFIER "${_ADD_TARGET_NAME}" _ADD_TARGET_IDENT)

        if(DEFINED _ADD_TARGET_VERSION)
            set(_ADD_TARGET_INFO_VERSION "${_ADD_TARGET_VERSION}")
        elseif(PROJECT_VERSION)
            set(_ADD_TARGET_INFO_VERSION "${PROJECT_VERSION}")
        else()
            set(_ADD_TARGET_INFO_VERSION "0.0.0")
        endif()
        set(_ADD_TARGET_INFO_PRODUCT "${PROJECT_NAME}")
        set(_ADD_TARGET_INFO_ORGANIZATION "${cmu_organization}")
        set(_ADD_TARGET_INFO_DOMAIN "${cmu_organization_domain}")
        set(_ADD_TARGET_INFO_COPYRIGHT "${cmu_copyright}")

        # Qt version of the Qt package found by the caller (none when Qt is not used).
        if(DEFINED Qt6_VERSION)
            set(_ADD_TARGET_INFO_QT_VERSION "${Qt6_VERSION}")
        elseif(DEFINED Qt5_VERSION)
            set(_ADD_TARGET_INFO_QT_VERSION "${Qt5_VERSION}")
        else()
            set(_ADD_TARGET_INFO_QT_VERSION "none")
        endif()

        if(CMAKE_CXX_COMPILER_ID)
            set(_ADD_TARGET_INFO_COMPILER "${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
        else()
            set(_ADD_TARGET_INFO_COMPILER "${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
        endif()

        set(_ADD_TARGET_INFO_DIR "${CMAKE_CURRENT_BINARY_DIR}/${_ADD_TARGET_NAME}_autogen/cmu/include")
        configure_file("${_CMU_TEMPLATE_DIR}/target_info.h.in"
            "${_ADD_TARGET_INFO_DIR}/${_ADD_TARGET_NAME}_info.h" @ONLY)
        configure_file("${_CMU_TEMPLATE_DIR}/target_info.cpp.in"
            "${_ADD_TARGET_INFO_DIR}/${_ADD_TARGET_NAME}_info.cpp" @ONLY)
        target_sources(${_ADD_TARGET_NAME} PRIVATE
            "${_ADD_TARGET_INFO_DIR}/${_ADD_TARGET_NAME}_info.h"
            "${_ADD_TARGET_INFO_DIR}/${_ADD_TARGET_NAME}_info.cpp")
        list(APPEND _ADD_TARGET_AUTOGEN_FILES
            "${_ADD_TARGET_INFO_DIR}/${_ADD_TARGET_NAME}_info.h"
            "${_ADD_TARGET_INFO_DIR}/${_ADD_TARGET_NAME}_info.cpp")
        target_include_directories(${_ADD_TARGET_NAME} PRIVATE "${_ADD_TARGET_INFO_DIR}")

        # Windows version resource: shown in the Details tab of the file properties.
        if(WIN32 AND _ADD_TARGET_TYPE MATCHES "^(EXECUTABLE|SHARED|MODULE)$")
            # FILEVERSION needs four numbers: a missing or non numeric part is 0.
            set(_ADD_TARGET_INFO_VERSION_NUMBER "0,0,0,0")
            if("${_ADD_TARGET_INFO_VERSION}" MATCHES "^([0-9]+)(\\.([0-9]+))?(\\.([0-9]+))?")
                set(_ADD_TARGET_INFO_VERSION_NUMBER "${CMAKE_MATCH_1}")
                foreach(_ADD_TARGET_PART "${CMAKE_MATCH_3}" "${CMAKE_MATCH_5}")
                    if("${_ADD_TARGET_PART}" STREQUAL "")
                        set(_ADD_TARGET_PART 0)
                    endif()
                    string(APPEND _ADD_TARGET_INFO_VERSION_NUMBER ",${_ADD_TARGET_PART}")
                endforeach()
                string(APPEND _ADD_TARGET_INFO_VERSION_NUMBER ",0")
            endif()

            if(_ADD_TARGET_TYPE STREQUAL "EXECUTABLE")
                set(_ADD_TARGET_INFO_FILE_TYPE VFT_APP)
                set(_ADD_TARGET_INFO_FILENAME "${_ADD_TARGET_NAME}.exe")
            else()
                set(_ADD_TARGET_INFO_FILE_TYPE VFT_DLL)
                if(DEFINED _ADD_TARGET_SHARED_EXTENSION AND NOT _ADD_TARGET_SHARED_EXTENSION STREQUAL "")
                    set(_ADD_TARGET_INFO_FILENAME "${_ADD_TARGET_NAME}.${_ADD_TARGET_SHARED_EXTENSION}")
                else()
                    set(_ADD_TARGET_INFO_FILENAME "${_ADD_TARGET_NAME}.dll")
                endif()
            endif()

            configure_file("${_CMU_TEMPLATE_DIR}/target_info.rc.in"
                "${_ADD_TARGET_INFO_DIR}/${_ADD_TARGET_NAME}_info.rc" @ONLY)
            target_sources(${_ADD_TARGET_NAME} PRIVATE "${_ADD_TARGET_INFO_DIR}/${_ADD_TARGET_NAME}_info.rc")
            list(APPEND _ADD_TARGET_AUTOGEN_FILES "${_ADD_TARGET_INFO_DIR}/${_ADD_TARGET_NAME}_info.rc")
        endif()
    endif()

    # Visual Studio / Xcode folder holding the generated files: cmu for CMakeUtils, one subfolder per Qt generator.
    if(_ADD_TARGET_AUTOGEN_FILES)
        source_group("autogen\\cmu" FILES ${_ADD_TARGET_AUTOGEN_FILES})
    endif()
    if(NOT _ADD_TARGET_TYPE STREQUAL "INTERFACE")
        # The files only exist at generate time and are named per configuration: match them by name.
        source_group("autogen\\moc" REGULAR_EXPRESSION "_autogen/mocs_compilation[^/]*\\.cpp$")
        source_group("autogen\\rcc" REGULAR_EXPRESSION "_autogen/[^/]+/qrc_[^/]*\\.cpp$")
        source_group("autogen\\uic" REGULAR_EXPRESSION "_autogen/include[^/]*/(.*/)?ui_[^/]*\\.h$")
    endif()

    # Collected for the automatic package (package.cmake); an OBJECT library cannot be exported.
    if(NOT _ADD_TARGET_TYPE STREQUAL "OBJECT")
        set_property(GLOBAL APPEND PROPERTY CMU_PACKAGE_TARGETS ${_ADD_TARGET_NAME})
        if(DEFINED cmu_public_headers_dir)
            get_filename_component(_ADD_TARGET_DIR "${cmu_public_headers_dir}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
            if(IS_DIRECTORY "${_ADD_TARGET_DIR}")
                set_property(GLOBAL APPEND PROPERTY CMU_PACKAGE_HEADERS "${_ADD_TARGET_DIR}")
                set_property(GLOBAL PROPERTY CMU_HEADERS_${_ADD_TARGET_NAME} "${_ADD_TARGET_DIR}")
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
