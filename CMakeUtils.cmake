# Entry point: sets the default directories (cache entries, unless already defined) and loads every module.
if(NOT DEFINED cmu_public_headers_dir)
    set(cmu_public_headers_dir "include" CACHE STRING "Public headers directory used by cmu_add_target")
endif()
if(NOT DEFINED cmu_sources_dir)
    set(cmu_sources_dir "src" CACHE STRING "Sources directory used by cmu_add_target")
endif()

include(${CMAKE_CURRENT_LIST_DIR}/target.cmake)
