#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
package_dir="${root_dir}/tests/ros2_mock/qxzn_hmi_test_interfaces"
work_dir="$(mktemp -d /tmp/qxzn-hmi-face-height-ros2.XXXXXX)"
ros_setup="${QXZN_ROS_SETUP:-}"

if [[ -z "${ros_setup}" ]]; then
    for candidate in /opt/ros/*/setup.bash; do
        [[ -r "${candidate}" ]] && ros_setup="${candidate}"
    done
fi
if [[ -z "${ros_setup}" || ! -r "${ros_setup}" ]]; then
    echo "ROS2 setup.bash not found" >&2
    exit 3
fi

set +u
# shellcheck disable=SC1090
source "${ros_setup}"
set -u

colcon --log-base "${work_dir}/log" build \
    --base-paths "${package_dir}" \
    --build-base "${work_dir}/build" \
    --install-base "${work_dir}/install" \
    --cmake-args \
        -DBUILD_TESTING=OFF \
        -DPython3_EXECUTABLE=/usr/bin/python3 \
        -DPYTHON_EXECUTABLE=/usr/bin/python3

set +u
# shellcheck disable=SC1091
source "${work_dir}/install/setup.bash"
set -u

ros2 run qxzn_hmi_test_interfaces face_height_guide_mock \
    >"${work_dir}/mock-service.log" 2>&1 &
server_pid=$!
stop_server() {
    if kill -0 "${server_pid}" 2>/dev/null; then
        kill -TERM "${server_pid}" 2>/dev/null || true
        wait "${server_pid}" 2>/dev/null || true
    fi
}
trap stop_server EXIT

ready=0
for _attempt in {1..50}; do
    if ros2 service type /face_height_guide/start 2>/dev/null | grep -q '/srv/FaceHeightGuideStart'; then
        ready=1
        break
    fi
    sleep 0.1
done
if [[ "${ready}" -ne 1 ]]; then
    echo "mock service did not become ready" >&2
    cat "${work_dir}/mock-service.log" >&2
    exit 5
fi

QXZN_FACE_HEIGHT_GUIDE_LIVE_TEST=1 \
QXZN_FACE_HEIGHT_GUIDE_HELPER="${root_dir}/scripts/runtime/call_face_height_guide.sh" \
QXZN_ROS_SETUP="${ros_setup}" \
QXZN_ROS_OVERLAY_SETUP="${work_dir}/install/setup.bash" \
QXZN_FACE_HEIGHT_GUIDE_SERVICE_TYPE="qxzn_hmi_test_interfaces/srv/FaceHeightGuideStart" \
    "${root_dir}/build/tst_face_height_guide_ros2_integration"

echo "mock integration artifacts: ${work_dir}"
