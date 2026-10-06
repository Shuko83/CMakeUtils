# Shared library: MYSHAREDLIB_BUILD makes the header export the symbols (import for the users).
cmu_add_shared_library(
    NAME MySharedLib
    COMPILE_DEFINITIONS PRIVATE MYSHAREDLIB_BUILD
)
