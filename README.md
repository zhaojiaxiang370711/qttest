# qxzn-hmi-qt

A Qt Quick port of the QXZN 15.6″ car-HMI shell (originally a Godot project at `../15-6inch-game-runtime-qxzn`). Dark HMI with a TopBar and all shell pages — home dashboard, course launcher, sparring/result, combat power, device tools, entertainment grid, and the fitness / AI-coach / boxing-knowledge sub pages — laid out pixel-level against the Godot `_draw()` code at 1920×1080.

This project exists to **dogfood [`qtcli`](../tools/qtcli)** — a real Qt project to drive its inspection commands and surface gaps.

## Build & run

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/opt/Qt/6.11.1/gcc_64
cmake --build build --parallel 6        # PD02 rule: never more than 6 jobs
./build/qxzn_hmi                        # fullscreen kiosk, UI scales to fit the screen
./build/qxzn_hmi --windowed             # windowed 1920x1080
./build/qxzn_hmi -platform offscreen --windowed --no-dds --quit-after-ms 800   # headless smoke
```

### Automatic height guide service

The device page calls the synchronous ROS2 service
`/face_guided_height/start`. The UI remains responsive while waiting and shows
the returned `started`, `no person`, or error result. A unique `request_id` is
generated for every request.

The complete service type is discovered from the live ROS graph. When the
interface package is not in the base ROS environment, the helper scans colcon
workspaces under the user's home for an overlay that provides it; an explicit
overlay can still be configured:

```bash
export QXZN_ROS_OVERLAY_SETUP=/path/to/vision_ws/install/setup.bash
export QXZN_FACE_HEIGHT_GUIDE_SERVICE_TYPE=your_interfaces/srv/FaceHeightGuideStart
```

`QXZN_ROS_SETUP`, `QXZN_FACE_HEIGHT_GUIDE_SERVICE`, and
`QXZN_FACE_HEIGHT_GUIDE_TIMEOUT_SEC` override the base setup, service name,
and timeout.

Until the vision service is available, run a real ROS2 request/response test
against the temporary interface package and mock server in this repository:

```bash
tests/ros2_mock/run_integration_test.sh
```

The mock returns `started` for normal request IDs and `no person` when the ID
contains `no-person`. It is built into a temporary prefix and is not installed
into the system ROS environment.

The build needs GStreamer 1.20+ development packages (`pkg-config` for `gstreamer-1.0` / `app-1.0` / `video-1.0` / `audio-1.0`), required at configure time for the course player. Qt Multimedia is **not** used.

DDS support is enabled by default and compiles against the stable C ABI header in the sibling `../dds-fastdds-core` checkout. For a standalone/offline build use `-DQXZN_HMI_DDS=OFF`; the same `DdsBridge` QML API remains available in `disabled` state. The HMI loads `libqxzn_pd02_dds_core.so` dynamically at runtime and never links Fast DDS directly.

The whole shell is laid out at the Godot panel15 design size of 1920×1080 and uniformly scaled to the actual window/screen size (aspect kept, centered). A 16:9 screen of any resolution (e.g. 3840×2160) is filled exactly; other aspects get dark letterbox bars.

## Pages and navigation

- Top nav: `首页 home` / `课程 learning` / `实战对练 result` / `娱乐模式 entertainment`; hidden: `device` (wifi icon), `combat` (learning card).
- Sub pages: `fitness` (entertainment card), `ai_coach` / `boxing_knowledge` (learning cards), `course_lesson` (video course player).
- The `vr_beats_kit` entertainment card calls the local game-process API. The
  backend stops the Qt course unit before launching Godot and restores Qt when
  VRBeatsKit exits.
- Device overlays: volume / display / system / pressure / face / pump_control / punch_control / hit_test / dev_tools / cloud_pairing.
- `Esc`: close overlay → leave sub page → back to home → quit.
- Three **pure-video courses** (`special_practice` 专项练习, `stance` 站姿, `right_straight` 右直拳) play end-to-end via GStreamer; the three interactive courses (`focus_mitt` / `bodycombat` / `lesmills_bodycombat`) and embedded games still raise a "互动训练待移植" callout.

## Architecture

- `qml/Main.qml` — background, TopBar at `Rect2(63,45,1794,87)`, page container at `Rect2(48,150,1824,882)`, page `Loader`, `CalloutHost`.
- QML singletons (module `QxznHmi`): `Theme` (Godot color/font/metric tokens, `px()`=×1.5 and `fontPx()`=×1.56 panel15 scaling), `AppState` (nav/subPage/overlay/callout routing), `ShellData` (all static seed data transcribed from `shell_data.gd` etc.).
- Components: `HmiCard`/`HmiInset` (neumorph 9-patch + border + highlight), `HmiIcon` (Lucide SVG baked per tone), `HmiButton`, `ClickFlash`, `CalloutHost`, `HmiBarChart`.
- C++ singletons/backends: `Config`, `AiAssistantClient`, `SessionModel`, `SegmentInput`, and `DdsBridge`. DDS hits feed the same `SessionModel::onSegment()` path as keyboard input; LED commands are explicit QML calls. The top-right AI entry opens a pre-training screening chat with quick replies, free text, live completion/summary, safety guidance, and routed recommendations. Local safety rules run first, then the C++ HTTPS client calls the cloud broker at `/api/v1/ai/training-assistant`; failures fall back to the local reply. Set `QXZN_CLOUD_API_BASE` and preferably `QXZN_DEVICE_SYNC_TOKEN_FILE` (a revocable device token, never a model-provider key). The remaining REST/device surfaces are still static seeds.
- Course video: `CourseCatalog` (six launchers + three video-course records + action markers), `CoursePlaybackController` (QML singleton `CoursePlayer`) driving a dedicated-thread GStreamer worker, and `CourseVideoSurface` (a `QQuickItem` that uploads decoded RGBA frames through a `QSGSimpleTextureNode`).

## Assets

`scripts/sync_godot_assets.sh` copies fonts/images from the Godot project (read-only; override with `GODOT_ROOT=...`), bakes 7 color variants per Lucide SVG (Qt software rendering cannot tint SVGs), extracts one frame of the sparring preview video via ffmpeg, and regenerates `resources/assets-manifest.cmake`. Re-run it after Godot-side asset changes.

## CLI flags

`--ws-url`, `--api-base`, `--game-id`, `--difficulty simple|hard`, `--max-fps`, `--windowed`, `--quit-after-ms`, plus `--nav <id>` (initial page; also accepts sub-page ids, incl. `course_lesson`), `--overlay <id>` (initial device overlay), `--course <id>` (video course id, validated against `CourseCatalog`; default `special_practice`), `--media-root <dir>` (course media root; env `QXZN_MEDIA_DIR`), and `--screenshot <png>`.

DDS flags: `--dds` / `--no-dds`, `--dds-core-lib`, `--dds-domain-id`, `--dds-multicast` / `--no-dds-multicast`, `--dds-initial-peers`, `--dds-participant`, `--dds-hit-event-topic`, and `--dds-led-command-topic`. Matching `PD02_DDS_*` environment variables are supported; CLI wins. Current deployment defaults are domain 37, multicast off, initial peer `127.0.0.1`, hit topic `pd02/hit/event`, and LED topic `pd02/led/command`.

Page screenshots (software rendering, headless):

```bash
QT_QUICK_BACKEND=software ./build/qxzn_hmi -platform offscreen --windowed \
    --no-dds --nav learning --screenshot /tmp/learning.png --quit-after-ms 1500
```

## Course video player

Three pure-video courses play through a custom GStreamer backend (not Qt Multimedia / its FFmpeg plugin):

- `special_practice` (专项练习) — default selection
- `stance` (基础系列：站姿教学)
- `right_straight` (基础系列：右直拳教学)

The pipeline is `playbin3 → queue → videoscale → videoconvert → capsfilter(RGBA, 1280×720) → appsink(sync, drop)`, with `autoaudiosink` for audio. `CoursePlaybackController` owns a dedicated worker thread; decoded RGBA frames are copied into a one-frame slot and uploaded by `CourseVideoSurface` via `QSGSimpleTextureNode` with aspect-contain geometry on a black stage. This is an honestly labeled **cpu-copy renderer** (`CoursePlayer.rendererMode == "cpu-copy"`), not a zero-copy / DMA-BUF / 4K path.

**Media stays external.** Course MP4s never enter qrc or git (a CMake assertion rejects any video under `QXZN_ASSET_FILES`). Resolve them at runtime:

```bash
QXZN_MEDIA_DIR=/path/to/media/library ./build/qxzn_hmi --windowed
# or:  ./build/qxzn_hmi --windowed --media-root /path/to/media/library
# expected layout: <root>/course/special_practice.mp4, stance_en.mp4, right_straight_en.mp4
```

Without a valid root the player shows a controlled "课程媒体文件不可用" overlay with retry/back (no crash).

**Decoder policy** (`QXZN_GST_DECODER=auto|software|mpp`, default `auto`): rank-based selection preferring `mpph264dec`/`mppvideodec` when present, otherwise `avdec_h264`. The active decoder and live `presentedFps` are surfaced in the player diagnostics strip. The current validation target `172.16.1.222` is x86_64, so it validates with `avdec_h264` software decode; the MPP path is staged for a future RK3588 and a later zero-copy renderer acceptance. For headless/CI runs force software decode and discard audio: `QXZN_GST_DECODER=software QXZN_MEDIA_AUDIO_SINK=fakesink`.

The player UI (`qml/CourseLessonPage.qml`) exposes back/title, current/total time, a seek track with action-marker ticks (tap + drag), previous/play-pause/next-marker transport, mute + volume, plus loading/buffering, missing-media/error, and end-of-stream overlays. It opens `AppState.courseId` on entry and stops on destruction so audio/video cannot run in the background. It references no DDS / SessionModel / REST / camera / motor / LED APIs.

## DDS hot path

Unlike the Godot HMI, which receives these events through the port-8000 WebSocket facade, the Qt HMI directly takes `pd02/hit/event` and publishes `pd02/led/command` through `dds-fastdds-core`. `ready` means the local DDS context was created; it does not prove a remote writer is matched. Receiving a hit never publishes an LED command automatically, avoiding duplicate runtime hit feedback.

For deployment, `libqxzn_pd02_dds_core.so` must match the target architecture and all dependencies reported by `ldd` must resolve (`libfastdds`/`libfastrtps`, `libfastcdr`, foonathan memory, etc.). They may be colocated using the core's `$ORIGIN` RPATH or provided by the PD02 Fast DDS environment.

## Segment input (keyboard)

| Segment | Key | | Segment | Key |
|---|---|---|---|---|
| head_left | Q | | chin | X |
| head_mid | W / E | | waist_left | A |
| head_right | R | | waist_mid | S / D |
| | | | waist_right | F |

Keyboard and DDS hits share the same validated seven-segment path and update Strikes / Calories / Frequency; Duration ticks each second.

## Test

```bash
(cd build && ctest --output-on-failure)        # unit tests + QML smoke; DDS smoke skips without a core path
PD02_DDS_CORE_LIB=/path/to/libqxzn_pd02_dds_core.so \
    ctest --test-dir build -R '^dds_smoke$' --output-on-failure
# Real-media course playback lifecycle (skips 77 if QXZN_MEDIA_DIR fixture missing):
QXZN_MEDIA_DIR=/path/to/media/library QXZN_GST_DECODER=software QXZN_MEDIA_AUDIO_SINK=fakesink \
    ctest --test-dir build -R '^course_playback$' --output-on-failure
qtcli --json --project . lint                  # qmllint, 0 diagnostics
qtcli --json --project . qml-audit --strict    # Qt 6 QML/CMake audit, 0 findings
```

Test suite: `tst_core` (config, catalog, media resolver, decoder policy, video-surface geometry, DDS bridge), `tst_course_video_surface` (renders a synthetic frame under software + default scene-graph backends), `tst_course_playback` (real-media lifecycle: first frame → `avdec_h264` → pause/seek/marker/volume/mute → EOS → replay → stop), plus `dds_smoke` and the QML smoke (home + `course_lesson` missing-media run).

## Documented deviations from the Godot original

- The Godot HMI uses a WebSocket facade for hit/LED traffic; the Qt HMI intentionally uses the native Fast DDS topics directly and keeps REST for later low-frequency UI APIs.
- Course videos are decoded and played through a custom GStreamer backend (cpu-copy RGBA → `QSGSimpleTextureNode`), not the Godot player. The three interactive (hardware-driven) courses are out of scope and report "互动训练待移植".
- i18n is dropped: Chinese strings are hardcoded (Godot used `shell_i18n.gd`).
- Lucide SVGs replace both Godot's hand-drawn `draw_symbol_icon` glyphs and emoji; colors are baked per tone at asset-sync time.
- Learning page combines the course carousel and the 5 entry cards on one page (Godot draws them in separate modes); carousel height is compressed from 786 to 552 px to fit.
- Device tool grid is 13 cards × 4 columns per spec (Godot: 12 × 3); card height compressed accordingly.
- Font metrics differ between Qt and Godot text engines; text baselines may deviate by ±2–3 px. Rects, colors, and font-size ladders follow Godot values exactly (1280-base ×1.5, font ×1.56).

## Training stats persistence (SQLite)

`StatsStore` (`src/stats_store.h/.cpp`, Qt SQL with the QSQLITE driver) persists training stats to a local SQLite database so they survive restarts:

- `daily_stats`: strikes per day (keyboard and DDS hits are both forwarded via `SessionModel`);
- `sessions`: one row per app run (start/end time, duration, strikes) — the row count is the total session count.

The database lives at `QStandardPaths::AppDataLocation` (`~/.local/share/qxzn/qxzn_hmi/stats.db`). The device page "训练统计" card shows today/lifetime numbers; stats are also exposed as the `StatsStore` QML singleton (`todayStrikes` / `totalStrikes` / `totalSessions`).

## Deploy to 1.222

```bash
scripts/deploy_1_222.sh          # build + bundle Qt/GStreamer runtime + rsync + desktop shortcut
scripts/deploy_1_222.sh --dry-run
```

The target only ships system Qt 6.4 (below the required 6.8), so the script bundles the local build with the Qt 6.11 runtime (lib/plugins/qml + an ldd dependency closure) into `/home/x/code/pd02/qxzn-hmi-qt/dist`, launches via the `run-qxzn-hmi.sh` wrapper, and writes a `qxzn-hmi.desktop` shortcut into `~/桌面`. The DDS core library (device page shows "离线模式") and course media are not deployed.

## License

MIT.
