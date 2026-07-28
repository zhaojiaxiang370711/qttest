# qxzn-hmi-qt

QXZN 15.6 英寸车载 HMI 外壳的 Qt Quick 移植版（Godot 参考工程位于 `../15-6inch-game-runtime-qxzn`）。现已包含首页、课程、实战结果、战力、设备、娱乐及三个子页面，并按 1920×1080 设计坐标等比适配屏幕。

本项目同时用于真实工程规模下的 [`qtcli`](../tools/qtcli) dogfood。

## 构建与运行

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/opt/Qt/6.11.1/gcc_64
cmake --build build --parallel 6        # PD02 规则：并发不得超过 6
./build/qxzn_hmi                        # 全屏 kiosk
./build/qxzn_hmi --windowed             # 1920×1080 窗口
./build/qxzn_hmi -platform offscreen --windowed --no-dds --quit-after-ms 800
```

DDS 支持默认开启，编译时只读取相邻 `../dds-fastdds-core` 的稳定 C ABI 头文件；独立/离线构建可加 `-DQXZN_HMI_DDS=OFF`。程序运行时通过 `QLibrary` 动态加载 `libqxzn_pd02_dds_core.so`，不会在链接阶段依赖 Fast DDS。

构建还需要 GStreamer 1.20+ 开发包（`pkg-config` 提供 `gstreamer-1.0` / `app-1.0` / `video-1.0` / `audio-1.0`），用于课程播放器；**不使用** Qt Multimedia。

## 课程播放器

三门纯视频课通过自定义 GStreamer 后端播放（不使用 Qt Multimedia / 其 FFmpeg 插件）：

- `special_practice`（专项练习）—— 默认选中
- `stance`（基础系列：站姿教学）
- `right_straight`（基础系列：右直拳教学）

管线为 `playbin3 → queue → videoscale → videoconvert → capsfilter(RGBA, 1280×720) → appsink(sync, drop)`，音频走 `autoaudiosink`。`CoursePlaybackController` 拥有独立工作线程；解码后的 RGBA 帧拷入单帧槽位，由 `CourseVideoSurface`（自定义 `QQuickItem`）经 `QSGSimpleTextureNode` 以保持比例 contain 渲染在黑色舞台。这是明确标注的 **cpu-copy 渲染器**（`CoursePlayer.rendererMode == "cpu-copy"`），并非零拷贝 / DMA-BUF / 4K 路径。

**媒体保持外部。** 课程 MP4 永不进入 qrc 或 git（CMake 在 `QXZN_ASSET_FILES` 中发现视频即报错终止）。运行时按目录解析：

```bash
QXZN_MEDIA_DIR=/path/to/media/library ./build/qxzn_hmi --windowed
# 或：./build/qxzn_hmi --windowed --media-root /path/to/media/library
# 期望目录：<root>/course/special_practice.mp4、stance_en.mp4、right_straight_en.mp4
```

无有效根目录时，播放器显示受控的“课程媒体文件不可用”遮罩并提供重试/返回（不崩溃）。

**解码策略**（`QXZN_GST_DECODER=auto|software|mpp`，默认 `auto`）：按 rank 选择，优先 `mpph264dec`/`mppvideodec`，否则 `avdec_h264`。实际解码器和实时 `presentedFps` 显示在播放器诊断条。当前验证目标 `172.16.1.222` 为 x86_64，以 `avdec_h264` 软解验证；MPP 路径为未来 RK3588 及后续零拷贝渲染器验收预留。无头/CI 运行强制软解并丢弃音频：`QXZN_GST_DECODER=software QXZN_MEDIA_AUDIO_SINK=fakesink`。

播放界面（`qml/CourseLessonPage.qml`）含返回/标题、当前/总时长、带动作标记刻度的进度条（点击+拖动）、上一个/播放暂停/下一个标记、静音与音量，以及加载/缓冲、缺媒体/错误、结束遮罩。进入时打开 `AppState.courseId`，销毁时停止，保证音视频不会在后台继续播放。不引用任何 DDS / SessionModel / REST / 摄像头 / 电机 / LED 接口。三门互动课（手靶/搏击操/莱美）暂不在本切片范围，点击提示“互动训练待移植”。

## DDS 热路径

Qt HMI 与 Godot 实现有意不同：

- 订阅 `pd02/hit/event` 获取击打事件；
- 发布 `pd02/led/command` 发送显式 LED 命令；
- 不通过端口 8000 的 WebSocket 门面处理热路径；
- REST 保留给后续设备操作、诊断、课程/战力会话和 OTA 等低频接口；
- 收到 hit **不会自动发送 LED**，避免和实时运行时自身的 hit-led 反馈重复。

当前发现默认值：domain 37、multicast 关闭、initial peer `127.0.0.1`。`ready` 仅表示本地动态库、符号和 DDS context 已就绪，不代表已匹配远端 writer。

部署时除了目标架构的 `libqxzn_pd02_dds_core.so`，还必须确保 `ldd` 列出的 Fast DDS/Fast CDR/foonathan 等依赖全部可解析；可利用 core 的 `$ORIGIN` RPATH 同目录打包，或加载 PD02 Fast DDS 环境。

## 分段输入

| 分段 | 按键 | | 分段 | 按键 |
|---|---|---|---|---|
| head_left | Q | | chin | X |
| head_mid | W / E | | waist_left | A |
| head_right | R | | waist_mid | S / D |
| | | | waist_right | F |

键盘与 DDS 击打经过同一个七分段校验和 `SessionModel::onSegment()` 路径，更新击打次数、卡路里和频率；时长每秒递增。

## CLI 参数

通用参数：`--ws-url`、`--api-base`、`--game-id`、`--difficulty simple|hard`、`--max-fps`、`--windowed`、`--nav`（初始页面，也接受子页面 id，含 `course_lesson`）、`--overlay`、`--course <id>`（视频课 id，经 `CourseCatalog` 校验，默认 `special_practice`）、`--media-root <dir>`（课程媒体根目录，环境变量 `QXZN_MEDIA_DIR`）、`--screenshot`、`--quit-after-ms`。

DDS 参数：`--dds` / `--no-dds`、`--dds-core-lib`、`--dds-domain-id`、`--dds-multicast` / `--no-dds-multicast`、`--dds-initial-peers`、`--dds-participant`、`--dds-hit-event-topic`、`--dds-led-command-topic`。同时支持对应的 `PD02_DDS_*` 环境变量，CLI 优先。

## 测试

```bash
cmake --build build --parallel 6
ctest --test-dir build --output-on-failure       # 无 core 路径时 dds_smoke 明确跳过
PD02_DDS_CORE_LIB=/path/to/libqxzn_pd02_dds_core.so \
    ctest --test-dir build -R '^dds_smoke$' --output-on-failure
# 真实媒体课程播放生命周期（缺 QXZN_MEDIA_DIR 测试件时返回 77 跳过）：
QXZN_MEDIA_DIR=/path/to/media/library QXZN_GST_DECODER=software QXZN_MEDIA_AUDIO_SINK=fakesink \
    ctest --test-dir build -R '^course_playback$' --output-on-failure
qtcli --json --project . lint
qtcli --json --project . qml-audit --strict
```

测试集：`tst_core`（配置、目录、媒体解析、解码策略、视频面几何、DDS bridge）、`tst_course_video_surface`（在 software 与默认两种场景图后端下渲染合成帧）、`tst_course_playback`（真实媒体生命周期：首帧 → `avdec_h264` → 暂停/拖动/标记/音量/静音 → 结束 → 重播 → 停止），以及 `dds_smoke` 和 QML smoke（首页 + `course_lesson` 缺媒体运行）。

## 许可证

MIT。
