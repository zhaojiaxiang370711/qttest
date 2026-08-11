#!/usr/bin/env bash

set -euo pipefail

request_id="${1:-}"
if [[ ! "${request_id}" =~ ^[A-Za-z0-9._:-]+$ ]]; then
    echo "invalid request_id" >&2
    exit 2
fi

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
# ROS setup files may read optional variables before defining them, so nounset
# must be suspended only while sourcing the generated environment.
set +u
# shellcheck disable=SC1090
source "${ros_setup}"
set -u

if [[ -n "${QXZN_ROS_OVERLAY_SETUP:-}" ]]; then
    if [[ ! -r "${QXZN_ROS_OVERLAY_SETUP}" ]]; then
        echo "ROS2 overlay setup not found: ${QXZN_ROS_OVERLAY_SETUP}" >&2
        exit 3
    fi
    # The overlay supplies FaceHeightGuideStart type support when it is not
    # installed in the base ROS distribution.
    set +u
    # shellcheck disable=SC1090
    source "${QXZN_ROS_OVERLAY_SETUP}"
    set -u
fi

service_name="${QXZN_FACE_HEIGHT_GUIDE_SERVICE:-/face_height_guide/start}"
service_type="${QXZN_FACE_HEIGHT_GUIDE_SERVICE_TYPE:-}"
if [[ -z "${service_type}" ]]; then
    service_type="$(timeout 4 ros2 service type "${service_name}" 2>/dev/null | awk '/\/srv\// {print; exit}' || true)"
fi
if [[ -z "${service_type}" || ! "${service_type}" =~ ^[A-Za-z][A-Za-z0-9_]*/srv/[A-Za-z][A-Za-z0-9_]*$ ]]; then
    echo "service type unavailable for ${service_name}; set QXZN_FACE_HEIGHT_GUIDE_SERVICE_TYPE" >&2
    exit 4
fi

timeout_sec="${QXZN_FACE_HEIGHT_GUIDE_TIMEOUT_SEC:-10}"
if [[ ! "${timeout_sec}" =~ ^[1-9][0-9]*$ ]]; then
    echo "invalid QXZN_FACE_HEIGHT_GUIDE_TIMEOUT_SEC" >&2
    exit 2
fi

exec timeout --foreground "${timeout_sec}" ros2 service call \
    "${service_name}" "${service_type}" "{request_id: '${request_id}'}"
