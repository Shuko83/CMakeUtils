# Executable using the two libraries; their public headers and definitions come with the link.
cmu_add_executable(
    NAME MyApp
    LINK_LIBRARIES PRIVATE MyStaticLib MySharedLib
)
