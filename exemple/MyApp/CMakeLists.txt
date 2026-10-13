# Copyright (C) 2026 Fabien Di Grande
# SPDX-License-Identifier: MPL-2.0

# Executable using the two libraries; their public headers and definitions come with the link.
cmu_add_executable(
    NAME MyApp
    LINK_LIBRARIES PRIVATE MyStaticLib MySharedLib
)
