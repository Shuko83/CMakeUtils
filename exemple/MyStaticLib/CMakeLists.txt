# Static library: sources in src/, public headers in include/ (both found automatically).
cmu_add_static_library(
    NAME MyStaticLib
    COMPILE_DEFINITIONS PRIVATE MYSTATICLIB_VALUE=1
)
