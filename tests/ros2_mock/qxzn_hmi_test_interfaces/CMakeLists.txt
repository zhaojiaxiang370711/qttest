cmake_minimum_required(VERSION 3.10)
project(qxzn_hmi_test_interfaces)

find_package(ament_cmake REQUIRED)
find_package(rosidl_default_generators REQUIRED)

rosidl_generate_interfaces(${PROJECT_NAME}
    "srv/FaceHeightGuideStart.srv"
)

install(PROGRAMS
    scripts/face_height_guide_mock
    DESTINATION lib/${PROJECT_NAME}
)

ament_export_dependencies(rosidl_default_runtime)
ament_package()
