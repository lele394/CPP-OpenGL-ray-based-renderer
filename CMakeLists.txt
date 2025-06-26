cmake_minimum_required(VERSION 3.10)
project(ShaderDemo)

set(CMAKE_CXX_STANDARD 17)

# Use system GLFW
find_package(OpenGL REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_search_module(GLFW REQUIRED glfw3)

# Add GLAD (from source)
add_library(glad STATIC deps/glad/src/glad.c)
target_include_directories(glad PUBLIC deps/glad/include)

# Add executable
add_executable(ShaderDemo main.cpp)

# Include paths
target_include_directories(ShaderDemo PRIVATE
    ${GLFW_INCLUDE_DIRS}
    deps/glad/include
)

# Link everything
target_link_libraries(ShaderDemo PRIVATE
    glad
    ${GLFW_LIBRARIES}
    OpenGL::GL
)
