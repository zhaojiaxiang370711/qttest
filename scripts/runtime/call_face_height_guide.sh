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

service_name="${QXZN_FACE_HEIGHT_GUIDE_SERVICE:-/face_guided_height/start}"
service_type="${QXZN_FACE_HEIGHT_GUIDE_SERVICE_TYPE:-}"
cache_file="${XDG_CACHE_HOME:-${HOME}/.cache}/qxzn-hmi/face-height-guide.env"

type_loads() {
    [[ "${service_type}" =~ ^[A-Za-z][A-Za-z0-9_]*/srv/[A-Za-z][A-Za-z0-9_]*$ ]] || return 1
    timeout 8 ros2 interface show "${service_type}" >/dev/null 2>&1
}

# Fast path: a previous invocation already discovered the service type and the
# overlay that provides its type support. Reusing them avoids several slow
# ros2 CLI startups (each costs seconds of Python import time), which keeps
# the whole call well inside the Qt client's timeout.
if [[ -z "${service_type}" && -r "${cache_file}" ]]; then
    cached_service_name=""
    cached_service_type=""
    cached_overlay_setup=""
    # shellcheck disable=SC1090
    source "${cache_file}"
    if [[ "${cached_service_name}" == "${service_name}" ]]; then
        if [[ -n "${cached_overlay_setup}" && -r "${cached_overlay_setup}" ]]; then
            set +u
            # shellcheck disable=SC1090
            source "${cached_overlay_setup}"
            set -u
        fi
        service_type="${cached_service_type}"
        # The vision stack may have been rebuilt or moved since the cache was
        # written; only trust the cache when the type still loads.
        type_loads || service_type=""
    fi
fi

if [[ -z "${service_type}" ]]; then
    service_type="$(timeout 4 ros2 service type "${service_name}" 2>/dev/null | awk '/\/srv\// {print; exit}' || true)"
    if ! [[ "${service_type}" =~ ^[A-Za-z][A-Za-z0-9_]*/srv/[A-Za-z][A-Za-z0-9_]*$ ]]; then
        echo "service type unavailable for ${service_name}; set QXZN_FACE_HEIGHT_GUIDE_SERVICE_TYPE" >&2
        exit 4
    fi

    # ros2 service call needs the interface package's full type support, which
    # lives in the vision team's workspace overlay, not in the base ROS
    # install. When it is missing, scan the usual colcon workspace layout
    # under the user's home for an overlay that provides it. Each candidate is
    # validated in a subshell first so that a stale or half-removed workspace
    # cannot pollute this process; only the overlay that loads the type is
    # sourced for real. An explicit QXZN_ROS_OVERLAY_SETUP (sourced above)
    # always takes precedence.
    if ! type_loads; then
        for overlay_setup in "${HOME}"/*/install/setup.bash \
                             "${HOME}"/*/*/install/setup.bash \
                             "${HOME}"/*/*/*/install/setup.bash; do
            [[ -r "${overlay_setup}" ]] || continue
            if ( set +u; source "${overlay_setup}" >/dev/null 2>&1; set -u; type_loads ); then
                set +u
                # shellcheck disable=SC1090
                source "${overlay_setup}"
                set -u
                break
            fi
        done
    fi
    if ! type_loads; then
        echo "ROS2 interface ${service_type} not loadable; set QXZN_ROS_OVERLAY_SETUP" >&2
        exit 5
    fi

    mkdir -p "$(dirname "${cache_file}")"
    printf 'cached_service_name=%q\ncached_service_type=%q\ncached_overlay_setup=%q\n' \
        "${service_name}" "${service_type}" "${overlay_setup:-}" >"${cache_file}" 2>/dev/null || true
fi

# The vision service may hold the request for several seconds while waiting
# for a person to be detected, so keep this comfortably below the Qt client's
# 30 s timeout rather than failing right as the server would answer.
timeout_sec="${QXZN_FACE_HEIGHT_GUIDE_TIMEOUT_SEC:-20}"
if [[ ! "${timeout_sec}" =~ ^[1-9][0-9]*$ ]]; then
    echo "invalid QXZN_FACE_HEIGHT_GUIDE_TIMEOUT_SEC" >&2
    exit 2
fi

exec timeout --foreground "${timeout_sec}" ros2 service call \
    "${service_name}" "${service_type}" "{request_id: '${request_id}'}"
