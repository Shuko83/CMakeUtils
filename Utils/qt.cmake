# Lets find_package(Qt6) work from the QTDIR environment variable (e.g. C:\Qt\6.11.2\msvc2022_64).
if(DEFINED ENV{QTDIR})
    file(TO_CMAKE_PATH "$ENV{QTDIR}" _cmu_qt_dir)
    list(FIND CMAKE_PREFIX_PATH "${_cmu_qt_dir}" _cmu_qt_index)
    if(IS_DIRECTORY "${_cmu_qt_dir}" AND _cmu_qt_index EQUAL -1)
        list(APPEND CMAKE_PREFIX_PATH "${_cmu_qt_dir}")
    endif()
    unset(_cmu_qt_dir)
    unset(_cmu_qt_index)
endif()

if(NOT DEFINED cmu_windeployqt)
    set(cmu_windeployqt ON CACHE BOOL "Run windeployqt after building an executable that depends on Qt (Windows)")
endif()

# Sets <result> to TRUE when <target> reaches a Qt::/Qt6:: target. Walks the whole link graph:
# Qt is usually reached through a library, not linked by the executable.
function(_cmu_qt_uses_qt target result)
    set(_pending ${target})
    set(_visited)
    set(_uses_qt FALSE)
    while(_pending AND NOT _uses_qt)
        list(POP_FRONT _pending _current)
        if(_current IN_LIST _visited)
            continue()
        endif()
        list(APPEND _visited ${_current})
        if(_current MATCHES "^Qt[0-9]*::")
            set(_uses_qt TRUE)
        elseif(TARGET ${_current})
            get_target_property(_imported ${_current} IMPORTED)
            if(NOT _imported)
                get_target_property(_link_libraries ${_current} LINK_LIBRARIES)
                get_target_property(_interface_libraries ${_current} INTERFACE_LINK_LIBRARIES)
                foreach(_library IN LISTS _link_libraries _interface_libraries)
                    # Static libraries expose their private dependencies as $<LINK_ONLY:...>.
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
    set(${result} ${_uses_qt} PARENT_SCOPE)
endfunction()

# Sets <result> to the windeployqt command (empty when not found).
function(_cmu_qt_windeployqt result)
    if(TARGET Qt6::windeployqt)
        set(${result} "$<TARGET_FILE:Qt6::windeployqt>" PARENT_SCOPE)
    else()
        find_program(_cmu_windeployqt NAMES windeployqt6 windeployqt)
        set(${result} "${_cmu_windeployqt}" PARENT_SCOPE)
    endif()
endfunction()

# Installs the executable, then deploys Qt next to the installed file (called by cmu_add_package after
# install(TARGETS), so that the rule runs once the executable is in place).
function(_cmu_qt_install_deploy target component)
    if(NOT WIN32 OR NOT cmu_windeployqt)
        return()
    endif()
    get_target_property(_type ${target} TYPE)
    if(NOT _type STREQUAL "EXECUTABLE")
        return()
    endif()
    _cmu_qt_uses_qt(${target} _uses_qt)
    if(NOT _uses_qt)
        return()
    endif()
    _cmu_qt_windeployqt(_windeployqt)
    if(NOT _windeployqt)
        return()
    endif()

    # Generator expressions in install(CODE) need CMP0087 (CMake 3.14).
    if(POLICY CMP0087)
        cmake_policy(SET CMP0087 NEW)
    endif()
    install(CODE "
        execute_process(COMMAND \"${_windeployqt}\"
            \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}/$<TARGET_FILE_NAME:${target}>\")
    " COMPONENT ${component})
endfunction()

# Deployed after the executable is built; deferred to the end of its directory (see cmu_add_target) so
# that its link dependencies exist.
function(_cmu_qt_deploy target)
    if(NOT WIN32 OR NOT cmu_windeployqt)
        return()
    endif()

    _cmu_qt_uses_qt(${target} _uses_qt)
    if(NOT _uses_qt)
        return()
    endif()

    _cmu_qt_windeployqt(_windeployqt)
    if(NOT _windeployqt)
        message(WARNING "CMakeUtils: windeployqt not found, ${target} is not deployed")
        return()
    endif()

    add_custom_command(TARGET ${target} POST_BUILD
        COMMAND "${_windeployqt}" "$<TARGET_FILE:${target}>"
        COMMENT "CMakeUtils: windeployqt for ${target}"
        VERBATIM)
endfunction()
