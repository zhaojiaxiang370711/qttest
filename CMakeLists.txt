cmake_minimum_required(VERSION 3.21)
project(qxzn_hmi VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.11 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Qml Test)

qt_standard_project_setup(REQUIRES 6.8)

# core logic library (sources added in later tasks)
add_library(qxzn_core STATIC
    src/config.h
    src/config.cpp
    src/segment_input.cpp
    src/session_model.h
    src/session_model.cpp
)
target_include_directories(qxzn_core PUBLIC src)
target_link_libraries(qxzn_core PUBLIC Qt6::Core)
qt_extract_metatypes(qxzn_core)

# application
qt_add_executable(qxzn_hmi src/main.cpp)
target_link_libraries(qxzn_hmi PRIVATE qxzn_core Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::Qml)
qt_add_qml_module(qxzn_hmi
    URI QxznHmi
    VERSION 1.0
    QML_FILES
        qml/TopBar.qml
        qml/MetricPill.qml
        qml/StatPanel.qml
        qml/Dashboard.qml
        qml/PlaceholderPage.qml
    SOURCES
        src/qml_singletons.h
)
qt_add_resources(qxzn_hmi "appqml"
    PREFIX "/"
    FILES
        qml/main.qml
        resources/fonts/AlimamaShuHeiTi-Bold.ttf
)
set_target_properties(qxzn_hmi PROPERTIES WIN32_EXECUTABLE TRUE MACOSX_BUNDLE TRUE)

enable_testing()
qt_add_executable(tst_core tests/tst_core.cpp)
target_link_libraries(tst_core PRIVATE qxzn_core Qt6::Test)
add_test(NAME tst_core COMMAND tst_core)
add_test(NAME qml_smoke
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/smoke.sh" "$<TARGET_FILE:qxzn_hmi>"
)
set_tests_properties(qml_smoke PROPERTIES TIMEOUT 10)
