#!/usr/bin/env bash

set -euo pipefail

mode="${1:-start}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
pid_file="${runtime_dir}/pd02-qxzn-hmi.pid"
ready_file="${runtime_dir}/pd02-qxzn-hmi-ready"
state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/pd02"
log_file="${state_dir}/qxzn-hmi.log"
app_dir="${QXZN_HMI_DIST_DIR:-/home/x/code/pd02/qxzn-hmi-qt/dist}"
app_launcher="${app_dir}/run-qxzn-hmi.sh"
preferred_monitor="${QXZN_HMI_MONITOR:-HDMI-0}"

mkdir -p "${state_dir}"

notify_desktop() {
    timeout 2 notify-send "$@" >/dev/null 2>&1 || true
}

stop_existing() {
    rm -f -- "${ready_file}"
    if [[ -r "${pid_file}" ]]; then
        local pid
        pid="$(<"${pid_file}")"
        if [[ "${pid}" =~ ^[0-9]+$ ]] && kill -0 "${pid}" 2>/dev/null; then
            kill -TERM "${pid}" 2>/dev/null || true
            for _attempt in {1..30}; do
                kill -0 "${pid}" 2>/dev/null || break
                sleep 0.1
            done
            if kill -0 "${pid}" 2>/dev/null; then
                kill -KILL "${pid}" 2>/dev/null || true
            fi
        fi
        rm -f -- "${pid_file}"
    fi
    pkill -TERM -u "$(id -u)" -f "^${app_dir}/lib/ld-linux-x86-64.so.2 .*${app_dir}/qxzn_hmi( |$)" 2>/dev/null || true
}

case "${mode}" in
    stop)
        stop_existing
        exit 0
        ;;
    status)
        if [[ -r "${pid_file}" ]] && kill -0 "$(<"${pid_file}")" 2>/dev/null && [[ -r "${ready_file}" ]]; then
            printf 'ready pid=%s %s\n' "$(<"${pid_file}")" "$(<"${ready_file}")"
            exit 0
        fi
        echo 'stopped'
        exit 1
        ;;
    restart)
        stop_existing
        ;;
    start)
        ;;
    *)
        echo "Usage: $0 [start|restart|stop|status]" >&2
        exit 2
        ;;
esac

rm -f -- "${ready_file}"
if [[ ! -x "${app_launcher}" ]]; then
    notify_desktop 'QXZN HMI 启动失败' "缺少 ${app_launcher}"
    exit 1
fi

export XDG_RUNTIME_DIR="${runtime_dir}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${runtime_dir}/bus}"

desktop_pid="$(pgrep -u "$(id -u)" -x gnome-shell | awk 'NR == 1 {print; exit}')"
desktop_display=""
desktop_xauthority=""
if [[ -n "${desktop_pid}" && -r "/proc/${desktop_pid}/environ" ]]; then
    desktop_display="$(tr '\0' '\n' <"/proc/${desktop_pid}/environ" | sed -n 's/^DISPLAY=//p' | head -n 1)"
    desktop_xauthority="$(tr '\0' '\n' <"/proc/${desktop_pid}/environ" | sed -n 's/^XAUTHORITY=//p' | head -n 1)"
fi
export DISPLAY="${DISPLAY:-${desktop_display:-:0}}"

xauthority_path="${XAUTHORITY:-}"
if [[ -z "${xauthority_path}" && -n "${desktop_xauthority}" && -r "${desktop_xauthority}" ]]; then
    xauthority_path="${desktop_xauthority}"
fi
if [[ -z "${xauthority_path}" ]]; then
    xauthority_path="$(find "${runtime_dir}" -maxdepth 1 -type f -name '.mutter-Xwaylandauth.*' -printf '%T@\t%p\n' 2>/dev/null | sort -nr | awk -F '\t' 'NR == 1 {print $2}')"
fi
if [[ -z "${xauthority_path}" && -r "${runtime_dir}/gdm/Xauthority" ]]; then
    xauthority_path="${runtime_dir}/gdm/Xauthority"
fi
if [[ -z "${xauthority_path}" ]]; then
    notify_desktop 'QXZN HMI 启动失败' '未找到当前桌面显示授权文件。'
    exit 1
fi
export XAUTHORITY="${xauthority_path}"

if ! timeout 5 xrandr --query >/dev/null 2>&1; then
    notify_desktop 'QXZN HMI 启动失败' "无法连接桌面显示 ${DISPLAY}。"
    exit 1
fi

mapfile -t monitors < <(timeout 5 xrandr --query | awk '
    $2 == "connected" {
        geometry = ""
        for (i = 3; i <= NF; i++) {
            if ($i ~ /^[0-9]+x[0-9]+[+-][0-9]+[+-][0-9]+$/) {
                geometry = $i
                break
            }
        }
        if (geometry != "") print $1 "\t" geometry
    }
')

selected=""
for monitor in "${monitors[@]}"; do
    IFS=$'\t' read -r connector geometry <<<"${monitor}"
    if [[ "${connector}" == "${preferred_monitor}" ]]; then
        selected="${monitor}"
        break
    fi
done
if [[ -z "${selected}" ]]; then
    for monitor in "${monitors[@]}"; do
        IFS=$'\t' read -r connector _geometry <<<"${monitor}"
        if [[ "${connector}" == HDMI* ]]; then
            selected="${monitor}"
            break
        fi
    done
fi
selected="${selected:-${monitors[0]:-}}"
if [[ -z "${selected}" ]]; then
    notify_desktop 'QXZN HMI 启动失败' '未检测到可用显示器。'
    exit 1
fi

IFS=$'\t' read -r connector geometry <<<"${selected}"
if [[ ! "${geometry}" =~ ^([0-9]+)x([0-9]+)([+-][0-9]+)([+-][0-9]+)$ ]]; then
    notify_desktop 'QXZN HMI 启动失败' "无法解析显示器 ${connector}。"
    exit 1
fi
width="${BASH_REMATCH[1]}"
height="${BASH_REMATCH[2]}"
position_x="$((BASH_REMATCH[3]))"
position_y="$((BASH_REMATCH[4]))"

if command -v xinput >/dev/null 2>&1; then
    while IFS= read -r device; do
        [[ -n "${device}" ]] || continue
        # GNOME may leave the device visible while libinput's send-events mode
        # is disabled after display changes or USB reconnects. Reassert the
        # known-good native state before applying the monitor transform.
        timeout 5 xinput enable "${device}" >/dev/null 2>&1 || true
        timeout 5 xinput set-prop "${device}" \
            'libinput Send Events Mode Enabled' 0 0 >/dev/null 2>&1 || true
        timeout 5 xinput set-prop "${device}" \
            'libinput Calibration Matrix' \
            1.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0 >/dev/null 2>&1 || true
        timeout 5 xinput map-to-output "${device}" "${connector}" >/dev/null 2>&1 || true
    done < <(timeout 5 xinput list --name-only 2>/dev/null | awk '/^ILITEK ILITEK-TP($| )/')
fi

if [[ -r "${pid_file}" ]]; then
    existing_pid="$(<"${pid_file}")"
    if [[ "${existing_pid}" =~ ^[0-9]+$ ]] && kill -0 "${existing_pid}" 2>/dev/null; then
        exit 0
    fi
    rm -f -- "${pid_file}"
fi

nohup "${app_launcher}" --windowed >>"${log_file}" 2>&1 &
hmi_pid=$!
printf '%s\n' "${hmi_pid}" >"${pid_file}"

window_id=""
for _attempt in {1..150}; do
    if ! kill -0 "${hmi_pid}" 2>/dev/null; then
        rm -f -- "${pid_file}"
        notify_desktop 'QXZN HMI 启动失败' "进程已退出，请查看 ${log_file}。"
        exit 1
    fi
    window_id="$(timeout 2 xdotool search --onlyvisible --pid "${hmi_pid}" 2>/dev/null | tail -n 1 || true)"
    [[ -n "${window_id}" ]] && break
    sleep 0.1
done
if [[ -z "${window_id}" ]]; then
    stop_existing
    notify_desktop 'QXZN HMI 启动失败' "未检测到窗口，请查看 ${log_file}。"
    exit 1
fi

timeout 2 wmctrl -ir "${window_id}" -b remove,fullscreen >/dev/null 2>&1 || true
timeout 2 xdotool windowmove "${window_id}" "${position_x}" "${position_y}"
timeout 2 xdotool windowsize "${window_id}" "${width}" "${height}"
timeout 2 wmctrl -ir "${window_id}" -b add,fullscreen
sleep 1

window_line="$(timeout 2 wmctrl -l -G | awk -v numeric_id="${window_id}" '
    BEGIN { wanted = sprintf("0x%08x", numeric_id) }
    tolower($1) == tolower(wanted) { print; exit }
')"
read -r _id _desktop actual_x actual_y actual_width actual_height _title <<<"${window_line}"
if [[ ! "${actual_x}" =~ ^-?[0-9]+$ || ! "${actual_y}" =~ ^-?[0-9]+$ ||
      ! "${actual_width}" =~ ^[0-9]+$ || ! "${actual_height}" =~ ^[0-9]+$ ]] ||
   ((actual_x != position_x || actual_y != position_y || actual_width != width || actual_height != height)); then
    stop_existing
    notify_desktop 'QXZN HMI 启动失败' "窗口未正确放置到 ${connector}。"
    exit 1
fi

printf 'pid=%s connector=%s geometry=%sx%s+%s+%s ready_at=%s\n' \
    "${hmi_pid}" "${connector}" "${width}" "${height}" "${position_x}" "${position_y}" \
    "$(date --iso-8601=seconds)" >"${ready_file}"
notify_desktop 'QXZN HMI 已启动' "窗口已放置到 ${connector}，即将启动 VRBeatsKit。"
