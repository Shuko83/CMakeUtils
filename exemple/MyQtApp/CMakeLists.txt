# Same as MyApp plus Qt Core; windeployqt runs after the build because the executable depends on Qt.
cmu_add_executable(
    NAME MyQtApp
    LINK_LIBRARIES PRIVATE MyStaticLib MySharedLib Qt6::Core
)
