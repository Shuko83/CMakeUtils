# Copyright (C) 2026 Fabien Di Grande
# SPDX-License-Identifier: MPL-2.0

# Shared library: the generated MySharedLib_export.h defines MYSHAREDLIB_EXPORT (export here, import for the users).
cmu_add_shared_library(
    NAME MySharedLib
)
