cmake_minimum_required(VERSION 2.8.3)
project(ze_matplotlib)

find_package(catkin_simple REQUIRED)
catkin_simple()

include(ze_setup)

# The matplotlib-cpp headers are linked against
find_package(PythonLibs)
include_directories(${PYTHON_INCLUDE_DIRS})

#############
# LIBRARIES #
#############
set(HEADERS
    include/ze/matplotlib/matplotlibcpp.hpp
  )

set(SOURCES
    src/matplotlibcpp.cpp
  )

cs_add_library(${PROJECT_NAME} ${SOURCES} ${HEADERS})
target_link_libraries(${PROJECT_NAME} ${PYTHON_LIBRARY})

###############
# EXECUTABLES #
###############

cs_add_executable(mpl_example_node src/mpl_example_node.cpp)
target_link_libraries(mpl_example_node ${PROJECT_NAME})

##########
# EXPORT #
##########
cs_install()
cs_export()
