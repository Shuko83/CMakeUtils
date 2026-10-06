#pragma once

#if defined(_WIN32)
#  ifdef MYSHAREDLIB_BUILD
#    define MYSHAREDLIB_EXPORT __declspec(dllexport)
#  else
#    define MYSHAREDLIB_EXPORT __declspec(dllimport)
#  endif
#else
#  define MYSHAREDLIB_EXPORT __attribute__((visibility("default")))
#endif

MYSHAREDLIB_EXPORT int mySharedValue();
