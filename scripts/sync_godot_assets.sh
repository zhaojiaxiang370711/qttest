#!/usr/bin/env bash
# Sync shell UI assets from the Godot runtime project (read-only source) into
# qxzn-hmi-qt/resources/, generate Lucide icon color variants (Qt software
# rendering cannot recolor SVGs at runtime, so we bake one file per tone), and
# regenerate resources/assets-manifest.cmake for qt_add_resources.
#
# Runnable from any directory:
#   /home/x/code/pd02/qxzn-hmi-qt/scripts/sync_godot_assets.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GODOT_ROOT="${GODOT_ROOT:-/home/x/code/pd02/15-6inch-game-runtime-qxzn}"
RES="${QT_ROOT}/resources"

if [[ ! -d "${GODOT_ROOT}/assets" ]]; then
    echo "error: Godot project not found at ${GODOT_ROOT}" >&2
    echo "hint: set GODOT_ROOT=/path/to/15-6inch-game-runtime-qxzn" >&2
    exit 1
fi

copy() { # copy <src-relative-to-godot> <dst-relative-to-resources>
    local src="${GODOT_ROOT}/$1" dst="${RES}/$2"
    if [[ ! -f "${src}" ]]; then
        echo "warning: missing source ${src}" >&2
        return 0
    fi
    mkdir -p "$(dirname "${dst}")"
    cp -f "${src}" "${dst}"
}

echo "== fonts =="
copy assets/fonts/alimama_agile/AlimamaAgileVF-Thin.ttf fonts/AlimamaAgileVF-Thin.ttf

echo "== images =="
copy assets/ui/neumorph/hmi_raised_shadow.png            images/neumorph/hmi_raised_shadow.png
copy assets/ui/neumorph/hmi_inset_shadow.png             images/neumorph/hmi_inset_shadow.png
copy assets/ui/backgrounds/design_shell_background.png   images/backgrounds/design_shell_background.png
copy assets/ui/backgrounds/shell_menu_background.png     images/backgrounds/shell_menu_background.png
copy assets/ui/home/home_hero_course.png                 images/home/home_hero_course.png
copy assets/ui/home/home_course_booking.png              images/home/home_course_booking.png
for kind in info success warning danger; do
    copy "assets/ui/callouts/callout_${kind}.png" "images/callouts/callout_${kind}.png"
done
for f in "${GODOT_ROOT}"/assets/ui/status_icons/*.png; do
    [[ -e "${f}" ]] || continue
    copy "assets/ui/status_icons/$(basename "${f}")" "images/status_icons/$(basename "${f}")"
done
for f in "${GODOT_ROOT}"/assets/ui/game_cards/*.png; do
    [[ -e "${f}" ]] || continue
    copy "assets/ui/game_cards/$(basename "${f}")" "images/game_cards/$(basename "${f}")"
done
copy assets/ui/sparring_practice/background_1.png images/sparring_practice/background_1.png
copy assets/ui/sparring_practice/boxer.png        images/sparring_practice/boxer.png

echo "== course covers =="
# Learning launcher course covers (referenced by modules/course/course_data.gd).
copy assets/sbk.png                                        images/course/sbk.png
copy assets/lmbjc.png                                      images/course/lmbjc.png
copy modules/course/assets/launcher_stance_cover.png       images/course/launcher_stance_cover.png
copy modules/course/assets/launcher_cross_cover.png        images/course/launcher_cross_cover.png
# Movements view technique thumbnails (referenced by modules/course/course_data.gd MOVE_TEXTURES).
copy modules/course/assets/move_0.jpg                      images/course/move_0.jpg
copy modules/course/assets/move_1.jpg                      images/course/move_1.jpg
copy modules/course/assets/move_2.jpg                      images/course/move_2.jpg
copy modules/course/assets/move_3.jpg                      images/course/move_3.jpg
copy modules/course/assets/move_4.jpg                      images/course/move_4.jpg

echo "== sparring preview frame =="
# Static port replaces the looping preview video with one extracted frame.
mkdir -p "${RES}/images"
if [[ -f "${GODOT_ROOT}/media/library/sparring/sparring_preview_source.mp4" ]]; then
    ffmpeg -y -loglevel error -ss 2 -i "${GODOT_ROOT}/media/library/sparring/sparring_preview_source.mp4" \
        -frames:v 1 -q:v 2 "${RES}/images/sparring_preview_frame.jpg"
else
    echo "warning: sparring_preview_source.mp4 not found, using background_1.png as preview frame" >&2
    cp -f "${GODOT_ROOT}/assets/ui/sparring_practice/background_1.png" "${RES}/images/sparring_preview_frame.jpg"
fi

echo "== lucide icon variants =="
# Godot tints the white Lucide strokes at draw time; Qt bakes one SVG per tone.
LUCIDE_DST="${RES}/icons/lucide"
rm -rf "${LUCIDE_DST}"
mkdir -p "${LUCIDE_DST}"
declare -A VARIANT_COLORS=(
    [white]="#F8FAFC"
    [muted]="#6B7B9C"
    [cyan]="#00F0FF"
    [green]="#00FF78"
    [yellow]="#FFE600"
    [red]="#FF003C"
    [orange]="#FF5E00"
)
VARIANT_ORDER=(white muted cyan green yellow red orange)
icon_count=0
for src in "${GODOT_ROOT}"/assets/ui/lucide/*.svg; do
    [[ -e "${src}" ]] || continue
    name="$(basename "${src}" .svg)"
    for variant in "${VARIANT_ORDER[@]}"; do
        sed "s/stroke=\"#ffffff\"/stroke=\"${VARIANT_COLORS[$variant]}\"/g" "${src}" \
            > "${LUCIDE_DST}/${name}_${variant}.svg"
    done
    icon_count=$((icon_count + 1))
done
echo "generated $((icon_count * ${#VARIANT_ORDER[@]})) icon variants from ${icon_count} icons"

echo "== manifest =="
MANIFEST="${RES}/assets-manifest.cmake"
{
    echo "# Generated by scripts/sync_godot_assets.sh -- do not edit by hand."
    echo "# Paths are relative to the project root and fed to qt_add_resources"
    echo "# with PREFIX \"/resources\" (qrc:/resources/<path under resources/>)."
    echo "set(QXZN_ASSET_FILES"
    (cd "${QT_ROOT}" && find resources/images resources/icons -type f | LC_ALL=C sort | sed 's/^/    /')
    echo ")"
} > "${MANIFEST}"
file_count=$(grep -c '^    resources/' "${MANIFEST}" || true)
echo "wrote ${MANIFEST} (${file_count} files)"
echo "done."
