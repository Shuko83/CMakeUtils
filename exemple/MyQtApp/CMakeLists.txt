# Copyright (C) 2026 Fabien Di Grande
# SPDX-License-Identifier: MPL-2.0

# Same as MyApp plus Qt Core; windeployqt runs after the build because the executable depends on Qt.
cmu_add_executable(
    NAME MyQtApp
    VERSION 1.0.0
    LINK_LIBRARIES PRIVATE MyStaticLib MySharedLib Qt6::Core
)
