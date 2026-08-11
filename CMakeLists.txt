# ============================================================
# 【教学导读】本文件是这个 Qt 6 Quick/QML 项目的 CMake 构建骨架
# 整体结构：查找 Qt → 核心静态库 qxzn_core → 可执行文件 qxzn_hmi
#   → QML 模块（qt_add_qml_module）→ qrc 资源 → CTest 测试
# 本文件演示的 Qt/CMake 概念：
#   1. CMAKE_AUTOMOC — 自动运行 moc，Qt 信号槽/属性能工作的构建前提
#   2. find_package(Qt6 ...) — 声明依赖的 Qt 模块
#   3. qt_add_qml_module — 把 QML 文件打包成可 import 的 QML 模块
#   4. qt_add_resources — 经典 qrc 资源，把文件编译进二进制
#   5. enable_testing/add_test — CTest 测试接线
# 配套阅读：src/main.cpp（程序入口）、qml/Main.qml（QML 入口界面）
# ============================================================
cmake_minimum_required(VERSION 3.21)
project(qxzn_hmi VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# CMAKE_AUTOMOC：构建时自动运行 moc（元对象编译器），把 Q_OBJECT/Q_PROPERTY/
# 信号槽等宏展开成真实 C++ 代码——Qt 构建的生命线
set(CMAKE_AUTOMOC ON)

# 声明本项目依赖的 Qt 模块；Quick/Qml 是 QML 应用的核心，Test 供单元测试使用
find_package(Qt6 6.11 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Qml Sql Test)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GSTREAMER REQUIRED IMPORTED_TARGET
    gstreamer-1.0>=1.20
    gstreamer-app-1.0>=1.20
    gstreamer-video-1.0>=1.20
    gstreamer-audio-1.0>=1.20
)

option(QXZN_HMI_DDS "Build DDS C ABI bridge support" ON)
set(QXZN_HMI_DDS_DEVELOPMENT_CORE_LIB
    "${CMAKE_CURRENT_SOURCE_DIR}/../dds-fastdds-core/build/libqxzn_pd02_dds_core.so"
    CACHE FILEPATH "Development libqxzn_pd02_dds_core.so candidate")
if(QXZN_HMI_DDS)
    find_path(QXZN_HMI_DDS_ABI_INCLUDE_DIR
        NAMES qxzn/pd02/dds/motor_bridge.h
        HINTS "${CMAKE_CURRENT_SOURCE_DIR}/../dds-fastdds-core/include"
    )
    if(NOT QXZN_HMI_DDS_ABI_INCLUDE_DIR)
        message(FATAL_ERROR
            "PD02 DDS ABI header not found. Set QXZN_HMI_DDS_ABI_INCLUDE_DIR "
            "or configure with -DQXZN_HMI_DDS=OFF.")
    endif()
endif()

# Qt 官方宏：应用 Qt 项目的标准惯例（自动开启 AUTOMOC/AUTORCC 等）
qt_standard_project_setup(REQUIRES 6.8)

# Delivered course frame size for the cpu-copy GStreamer renderer (appsink caps).
# Defaults to 1280x720; override via cache when validating other resolutions.
set(QXZN_HMI_GST_FRAME_WIDTH 1280 CACHE STRING "Course video delivered frame width (px)")
set(QXZN_HMI_GST_FRAME_HEIGHT 720 CACHE STRING "Course video delivered frame height (px)")

# core logic library (sources added in later tasks)
# 核心逻辑做成静态库：应用和测试程序链接同一份代码——"逻辑与入口分离"的常见做法
add_library(qxzn_core STATIC
    src/config.h
    src/config.cpp
    src/course_catalog.h
    src/course_catalog.cpp
    src/media_path_resolver.h
    src/media_path_resolver.cpp
    src/gst_decoder_policy.h
    src/gst_decoder_policy.cpp
    src/gst_playback_worker.h
    src/gst_playback_worker.cpp
    src/course_playback_controller.h
    src/course_playback_controller.cpp
    src/course_video_surface.h
    src/course_video_surface.cpp
    src/dds_bridge.h
    src/dds_bridge.cpp
    src/dds_bridge_api.h
    src/segment_input.cpp
    src/face_height_guide_client.h
    src/face_height_guide_client.cpp
    src/session_model.h
    src/session_model.cpp
    src/stats_store.h
    src/stats_store.cpp
)
target_include_directories(qxzn_core PUBLIC src)
target_compile_definitions(qxzn_core PRIVATE
    QXZN_HMI_GST_FRAME_WIDTH=${QXZN_HMI_GST_FRAME_WIDTH}
    QXZN_HMI_GST_FRAME_HEIGHT=${QXZN_HMI_GST_FRAME_HEIGHT}
)
# CMake 里 Qt 模块以 "Qt6::模块名" 的导入目标形式链接
target_link_libraries(qxzn_core PUBLIC Qt6::Core Qt6::Gui Qt6::Quick Qt6::Sql PRIVATE PkgConfig::GSTREAMER)
if(QXZN_HMI_DDS)
    target_include_directories(qxzn_core PUBLIC "${QXZN_HMI_DDS_ABI_INCLUDE_DIR}")
    target_compile_definitions(qxzn_core PUBLIC QXZN_HMI_DDS=1)
    target_compile_definitions(qxzn_core PRIVATE
        QXZN_HMI_DDS_DEVELOPMENT_CORE_LIB="${QXZN_HMI_DDS_DEVELOPMENT_CORE_LIB}"
    )
else()
    target_compile_definitions(qxzn_core PUBLIC QXZN_HMI_DDS=0)
endif()
qt_extract_metatypes(qxzn_core)

# application
# qt_add_executable：Qt 版 add_executable，自动处理平台差异（Windows 子系统入口、macOS bundle）
qt_add_executable(qxzn_hmi src/main.cpp)
# 把 project() 声明的版本号传给 C++ 代码，编译成宏 QXZN_HMI_VERSION
target_compile_definitions(qxzn_hmi PRIVATE QXZN_HMI_VERSION="${PROJECT_VERSION}")

target_link_libraries(qxzn_hmi PRIVATE qxzn_core Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::Qml)
# singleton markers must be set before qt_add_qml_module reads the file list
# 把这三个 QML 文件标记为单例：必须在 qt_add_qml_module 之前设置，
# 与 QML 文件里的 "pragma Singleton" 配对
set_source_files_properties(
    qml/singletons/Theme.qml
    qml/singletons/AppState.qml
    qml/singletons/ShellData.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)
# 把 QML 文件打包成名为 QxznHmi 的 QML 模块：QML 里 "import QxznHmi" 就来自这里的
# URI；构建时 qmlcachegen 会预编译 QML。SOURCES 收录的 qml_singletons.h 负责注册 C++ 类型
qt_add_qml_module(qxzn_hmi
    URI QxznHmi
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/singletons/Theme.qml
        qml/singletons/AppState.qml
        qml/singletons/ShellData.qml
        qml/components/TopBar.qml
        qml/components/NeumorphShadow.qml
        qml/components/HmiCard.qml
        qml/components/HmiInset.qml
        qml/components/HmiIcon.qml
        qml/components/HmiButton.qml
        qml/components/ClickFlash.qml
        qml/components/CalloutHost.qml
        qml/components/HmiBarChart.qml
        qml/pages/HomePage.qml
        qml/pages/LearningPage.qml
        qml/pages/ResultPage.qml
        qml/pages/CombatPowerPage.qml
        qml/pages/DevicePage.qml
        qml/panels/DeviceVolumePanel.qml
        qml/panels/DeviceDisplayPanel.qml
        qml/panels/DeviceSystemPanel.qml
        qml/panels/DevicePressurePanel.qml
        qml/panels/DeviceFacePanel.qml
        qml/panels/DevicePumpPanel.qml
        qml/panels/DevicePunchPanel.qml
        qml/panels/DeviceHitTestPanel.qml
        qml/panels/DeviceDevToolsPanel.qml
        qml/panels/DeviceCloudPanel.qml
        qml/pages/EntertainmentPage.qml
        qml/subpages/FitnessPage.qml
        qml/subpages/AiCoachPage.qml
        qml/subpages/BoxingKnowledgePage.qml
        qml/subpages/CourseLessonPage.qml
        qml/subpages/FocusMittPage.qml
        qml/subpages/SubgamePage.qml
    SOURCES
        src/qml_singletons.h
)

# fonts stay in the classic resource prefix so QFontDatabase paths stay stable
# 经典 qrc 资源：字体文件被编译进二进制，运行时以 ":/..." 路径访问
#（见 main.cpp 的 QFontDatabase::addApplicationFont 注册）
qt_add_resources(qxzn_hmi "appqml"
    PREFIX "/"
    FILES
        resources/fonts/AlimamaShuHeiTi-Bold.ttf
        resources/fonts/AlimamaAgileVF-Thin.ttf
)

# synced Godot assets: regenerated by scripts/sync_godot_assets.sh
# BASE strips the "resources/" prefix from aliases -> qrc:/resources/images/...
include(resources/assets-manifest.cmake)

# Course media must stay external (resolved at runtime via QXZN_MEDIA_DIR) and
# never enter the qrc / git. Fail configure if a synced asset is a video.
foreach(_asset ${QXZN_ASSET_FILES})
    string(TOLOWER "${_asset}" _asset_lower)
    if(_asset_lower MATCHES "\\.(mp4|mov|mkv|avi|webm|flv|m4v|ts|mpg|mpeg)$")
        message(FATAL_ERROR
            "Course video must stay external (QXZN_MEDIA_DIR), not in qrc: ${_asset}")
    endif()
endforeach()

qt_add_resources(qxzn_hmi "assets"
    PREFIX "/resources"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}/resources"
    FILES ${QXZN_ASSET_FILES}
)
set_target_properties(qxzn_hmi PROPERTIES WIN32_EXECUTABLE TRUE MACOSX_BUNDLE TRUE)

# CTest 测试接线：enable_testing 开启测试；每个测试程序用 qt_add_executable 构建、
# 用 add_test 注册，之后可用 ctest 统一运行
enable_testing()
qt_add_executable(tst_core tests/tst_core.cpp)
target_link_libraries(tst_core PRIVATE qxzn_core Qt6::Test)
add_test(NAME tst_core COMMAND tst_core)
qt_add_executable(tst_course_playback tests/tst_course_playback.cpp)
target_link_libraries(tst_course_playback PRIVATE qxzn_core Qt6::Test)
add_test(NAME course_playback COMMAND tst_course_playback)
set_tests_properties(course_playback PROPERTIES SKIP_RETURN_CODE 77 TIMEOUT 30)
qt_add_executable(tst_course_video_surface tests/tst_course_video_surface.cpp)
target_link_libraries(tst_course_video_surface PRIVATE qxzn_core Qt6::Test Qt6::Quick)
add_test(NAME course_video_surface COMMAND tst_course_video_surface)
set_tests_properties(course_video_surface PROPERTIES SKIP_RETURN_CODE 77 TIMEOUT 30)
qt_add_executable(tst_face_height_guide_client tests/tst_face_height_guide_client.cpp)
target_link_libraries(tst_face_height_guide_client PRIVATE qxzn_core Qt6::Test)
add_test(NAME face_height_guide_client COMMAND tst_face_height_guide_client)
set_tests_properties(face_height_guide_client PROPERTIES TIMEOUT 10)
qt_add_executable(tst_face_height_guide_ros2_integration
    tests/tst_face_height_guide_ros2_integration.cpp)
target_link_libraries(tst_face_height_guide_ros2_integration PRIVATE qxzn_core Qt6::Test)
add_test(NAME face_height_guide_ros2_integration COMMAND tst_face_height_guide_ros2_integration)
set_tests_properties(face_height_guide_ros2_integration PROPERTIES SKIP_RETURN_CODE 77 TIMEOUT 30)
if(QXZN_HMI_DDS)
    qt_add_executable(tst_dds_smoke tests/tst_dds_smoke.cpp)
    target_link_libraries(tst_dds_smoke PRIVATE qxzn_core Qt6::Test)
    add_test(NAME dds_smoke COMMAND tst_dds_smoke)
    set_tests_properties(dds_smoke PROPERTIES SKIP_RETURN_CODE 77 TIMEOUT 15)
endif()
add_test(NAME qml_smoke
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/smoke.sh" "$<TARGET_FILE:qxzn_hmi>"
)
set_tests_properties(qml_smoke PROPERTIES TIMEOUT 10)
