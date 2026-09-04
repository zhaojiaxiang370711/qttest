#!/usr/bin/env bash
set -Eeuo pipefail

# qxzn-hmi-qt -> 172.16.1.222 部署脚本
#
# 目标机是 Ubuntu 24.04（glibc 2.39），系统只有 Qt 6.4，不满足本项目
# qt_standard_project_setup(REQUIRES 6.8) 的要求；而本机部分库（含 libQt6Gui、
# libglib、libgnutls）引用了 GLIBC_2.43 符号（2026-08-04 实测），因此采用
# "二进制 + 打包完整运行时（含 glibc 与 ld-linux）"的方式部署，不在目标机上编译。
#
# 布局（目标机 $TARGET_DIR）：
#   qxzn_hmi          主程序
#   run-qxzn-hmi.sh   启动包装（设置 LD_LIBRARY_PATH/插件/QML 路径）
#   lib/              ldd 依赖闭包（Qt6、GStreamer、ICU、libstdc++ 等）
#   plugins/          Qt 插件（platforms/sqldrivers/imageformats 等）
#   qml/              Qt QML 模块（QtQuick/QtQuick.Controls/QtQuick.Effects 等）
#
# 部署后在目标机写桌面快捷方式（~/桌面/qxzn-hmi.desktop）并标记为信任。
#
# 用法：
#   scripts/deploy_1_222.sh [--dry-run] [--skip-build]
# 环境变量可覆盖：PD02_HMI_HOST / PD02_HMI_USER / PD02_HMI_PASSWORD /
#                PD02_HMI_TARGET_DIR / PD02_HMI_QT_DIR

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
STAGE_DIR="${ROOT_DIR}/dist-1.222"
QT_DIR="${PD02_HMI_QT_DIR:-/opt/Qt/6.11.1/gcc_64}"

TARGET_HOST="${PD02_HMI_HOST:-172.16.1.222}"
TARGET_USER="${PD02_HMI_USER:-x}"
TARGET_PASS="${PD02_HMI_PASSWORD:-1}"
TARGET_DIR="${PD02_HMI_TARGET_DIR:-/home/x/code/pd02/qxzn-hmi-qt/dist}"

DRY_RUN=0
SKIP_BUILD=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --skip-build) SKIP_BUILD=1 ;;
        *) echo "未知参数: $arg" >&2; exit 2 ;;
    esac
done

SSH=(sshpass -p "${TARGET_PASS}" ssh -o StrictHostKeyChecking=no)
RSYNC_SSH="sshpass -p ${TARGET_PASS} ssh -o StrictHostKeyChecking=no"

run() {
    echo "+ $*"
    if [[ ${DRY_RUN} -eq 0 ]]; then "$@"; fi
}

# --- 1. 本地构建（PD02 规则：并发不超过 6）---
if [[ ${SKIP_BUILD} -eq 0 ]]; then
    run cmake --build "${BUILD_DIR}" --parallel 6
fi
[[ -x "${BUILD_DIR}/qxzn_hmi" ]] || { echo "缺少 ${BUILD_DIR}/qxzn_hmi" >&2; exit 1; }

if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "[dry-run] 将打包 ${BUILD_DIR}/qxzn_hmi + ${QT_DIR} 运行时，同步到 ${TARGET_USER}@${TARGET_HOST}:${TARGET_DIR} 并写桌面快捷方式"
    exit 0
fi

# --- 2. 组装 staging 目录 ---
echo "== 组装 ${STAGE_DIR} =="
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}/lib" "${STAGE_DIR}/plugins" "${STAGE_DIR}/qml"
cp "${BUILD_DIR}/qxzn_hmi" "${STAGE_DIR}/"
cp "${ROOT_DIR}/scripts/runtime/call_face_height_guide.sh" "${STAGE_DIR}/"
chmod +x "${STAGE_DIR}/call_face_height_guide.sh"
cp -a "${QT_DIR}/plugins/." "${STAGE_DIR}/plugins/"
cp -a "${QT_DIR}/qml/." "${STAGE_DIR}/qml/"

# 依赖闭包：对 staging 里所有 ELF 反复跑 ldd，直到没有新依赖。
# 注意：本机部分库（含 libQt6Gui、libglib、libgnutls）引用 GLIBC_2.43 符号，
# 高于目标机的 2.39，因此 glibc 家族与动态加载器也一并打包，
# 启动时由 run-qxzn-hmi.sh 显式调用随包 ld-linux（2026-08-04 实测需要）。
# 仅排除 linux-vdso（内核虚拟库，无实体文件）。
DENY_RE='^(linux-vdso)'
echo "== 收集依赖闭包 =="
changed=1
while [[ ${changed} -eq 1 ]]; do
    changed=0
    while IFS= read -r f; do
        while read -r dep; do
            [[ -n "${dep}" && -e "${dep}" ]] || continue
            base="$(basename "${dep}")"
            [[ "${base}" =~ ${DENY_RE} ]] && continue
            # 本机系统目录另有一套 Qt 6.10：ldd 无 RPATH 时可能把系统旧版
            # Qt 扫进来（二进制要求 Qt_6.11 版本符号），libQt6* 一律改从
            # ${QT_DIR} 取（2026-08-04 实测踩中）
            if [[ "${base}" == libQt6* && -e "${QT_DIR}/lib/${base}" ]]; then
                dep="${QT_DIR}/lib/${base}"
            fi
            if [[ ! -e "${STAGE_DIR}/lib/${base}" ]]; then
                cp -L "${dep}" "${STAGE_DIR}/lib/${base}"
                echo "  + lib/${base}"
                changed=1
            fi
        done < <(ldd "${f}" 2>/dev/null | awk '/=> \//{print $3} /^[[:space:]]*\//{print $1}')
    done < <(find "${STAGE_DIR}" -type f -exec file {} + | grep 'ELF ' | cut -d: -f1)
done

# --- 3. 启动包装脚本 ---
cat > "${STAGE_DIR}/run-qxzn-hmi.sh" <<'WRAPPER'
#!/usr/bin/env bash
# qxzn_hmi 启动包装：使用随包携带的完整运行时（含 glibc 与动态加载器）。
# 随包 lib/ 里有引用 GLIBC_2.43 的库，高于目标机系统的 2.39，
# 所以必须显式用随包 ld-linux 启动，并只用随包库解析依赖。
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 经随包 ld-linux 启动时 /proc/self/exe 指向加载器，Qt 的
# applicationDirPath() 会解析到 lib/ 而找不到随包根目录下的高度引导
# helper，因此这里显式导出其路径（FaceHeightGuideClient 优先读该变量）。
export QXZN_FACE_HEIGHT_GUIDE_HELPER="${DIR}/call_face_height_guide.sh"
export QT_PLUGIN_PATH="${DIR}/plugins"
export QML2_IMPORT_PATH="${DIR}/qml"
# The model-provider key never reaches the device. Qt reads only this
# revocable device credential; keep the file mode at 0600.
device_token_file="${QXZN_DEVICE_SYNC_TOKEN_FILE:-${HOME}/.config/qxzn/device-sync-token}"
if [[ -r "${device_token_file}" ]]; then
    export QXZN_DEVICE_SYNC_TOKEN_FILE="${device_token_file}"
fi
export QXZN_CLOUD_API_BASE="${QXZN_CLOUD_API_BASE:-https://cloud.qxrobot.com}"
# 课程媒体根目录（存在才导出，缺失时播放器显示受控遮罩而不崩溃）
if [[ -d /home/x/code/pd02/media ]]; then
    export QXZN_MEDIA_DIR="${QXZN_MEDIA_DIR:-/home/x/code/pd02/media}"
fi
exec "${DIR}/lib/ld-linux-x86-64.so.2" --library-path "${DIR}/lib" "${DIR}/qxzn_hmi" "$@"
WRAPPER
chmod +x "${STAGE_DIR}/run-qxzn-hmi.sh"

# --- 4. 同步到目标机 ---
echo "== 同步到 ${TARGET_USER}@${TARGET_HOST}:${TARGET_DIR} =="
"${SSH[@]}" "${TARGET_USER}@${TARGET_HOST}" "mkdir -p '${TARGET_DIR}'"
rsync -a --delete -e "${RSYNC_SSH}" "${STAGE_DIR}/" "${TARGET_USER}@${TARGET_HOST}:${TARGET_DIR}/"

# --- 5. 安装开机主应用与 VRBeatsKit 交接链 ---
echo "== 安装 Qt HMI -> VRBeatsKit 开机交接链 =="
"${SSH[@]}" "${TARGET_USER}@${TARGET_HOST}" \
    "mkdir -p '/home/x/code/pd02/qxzn-hmi-qt/scripts/runtime' \
        '/home/x/code/pd02/qxzn-hmi-qt/systemd' \
        '/home/x/code/pd02/scripts'"
rsync -a -e "${RSYNC_SSH}" \
    "${ROOT_DIR}/scripts/runtime/launch_qxzn_hmi_external_display.sh" \
    "${TARGET_USER}@${TARGET_HOST}:/home/x/code/pd02/qxzn-hmi-qt/scripts/runtime/"
rsync -a -e "${RSYNC_SSH}" \
    "${ROOT_DIR}/systemd/pd02-course-runtime.service" \
    "${TARGET_USER}@${TARGET_HOST}:/home/x/code/pd02/qxzn-hmi-qt/systemd/"
rsync -a -e "${RSYNC_SSH}" \
    "${ROOT_DIR}/../scripts/start-vrbeatskit.sh" \
    "${ROOT_DIR}/../scripts/install_vrbeatskit_autostart.sh" \
    "${TARGET_USER}@${TARGET_HOST}:/home/x/code/pd02/scripts/"
"${SSH[@]}" "${TARGET_USER}@${TARGET_HOST}" bash -s <<'REMOTE'
set -euo pipefail
chmod 0755 \
    /home/x/code/pd02/qxzn-hmi-qt/scripts/runtime/launch_qxzn_hmi_external_display.sh \
    /home/x/code/pd02/scripts/start-vrbeatskit.sh \
    /home/x/code/pd02/scripts/install_vrbeatskit_autostart.sh
install -m 0644 \
    /home/x/code/pd02/qxzn-hmi-qt/systemd/pd02-course-runtime.service \
    "$HOME/.config/systemd/user/pd02-course-runtime.service"
systemctl --user daemon-reload
systemctl --user enable pd02-course-runtime.service
cd /home/x/code/pd02
PD02_DESKTOP_USER=x ./scripts/install_vrbeatskit_autostart.sh
REMOTE

# --- 6. 桌面快捷方式（GNOME 需要可执行位 + trusted 元数据才允许双击启动）---
echo "== 写桌面快捷方式 =="
"${SSH[@]}" "${TARGET_USER}@${TARGET_HOST}" TARGET_DIR="${TARGET_DIR}" bash -s <<'REMOTE'
set -e
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/qxzn-hmi.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=QXZN HMI
Comment=QXZN 15.6-inch HMI (Qt Quick)
Exec=${TARGET_DIR}/run-qxzn-hmi.sh
Terminal=false
Categories=Utility;
DESKTOP
chmod +x "$DESKTOP_DIR/qxzn-hmi.desktop"
# gio 需要用户会话的 D-Bus 地址才能写 gvfs 元数据
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/1000/bus}"
gio set "$DESKTOP_DIR/qxzn-hmi.desktop" metadata::trusted true || true
echo "快捷方式: $DESKTOP_DIR/qxzn-hmi.desktop"
REMOTE

echo "== 完成 =="
echo "目标机验证："
echo "  ssh ${TARGET_USER}@${TARGET_HOST}"
echo "  ${TARGET_DIR}/run-qxzn-hmi.sh -platform offscreen --windowed --no-dds --quit-after-ms 1500 --screenshot /tmp/hmi.png"
echo "  DISPLAY=:0 ${TARGET_DIR}/run-qxzn-hmi.sh --windowed   # 真实窗口"
