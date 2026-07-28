# qxzn-hmi-qt — DDS 直连通信层设计

- 日期：2026-07-22
- 状态：已实现并通过本地单元测试、QML 验证及真实 DDS round-trip；待目标机真机验证
- 阶段：D2a 通信层第一切片
- 关联：`docs/PORTING_HANDOFF.md`、`docs/superpowers/specs/2026-07-15-qxzn-hmi-shell-design.md`
- DDS 核心：`/home/x/code/pd02/dds-fastdds-core`
- 实时运行时：`/home/x/code/pd02/qxzn-realtime-runtime-rs`

## 1. 背景与已敲定决策

Godot HMI 当前通过 `pd02-app-web` 的 WebSocket/REST 门面访问运行时。Qt 移植不照搬该热路径，而是按 PD02 的模块通信约定，直接使用 Fast DDS：

1. Qt HMI 的击打输入和 LED 命令直接走 DDS；不通过 `ws://*:8000/ws`。
2. Qt 不直接使用 Fast DDS C++ API，不自行创建 Topic/DataReader/DataWriter；复用 `dds-fastdds-core` 的稳定 C ABI。
3. Qt 通过 `QLibrary` 动态加载 `libqxzn_pd02_dds_core.so`。库缺失或 DDS 初始化失败时，HMI 仍可离线启动，键盘 segment 输入继续可用。
4. REST 保留给没有 DDS Topic 的低频 UI/管理能力，包括设备操作、诊断、课程/战力会话、OTA、云绑定和系统操作。
5. 第一切片只交付 `pd02/hit/event` 订阅和 `pd02/led/command` 发布；压力、电机状态和 REST 页面接入留给后续切片。

这是对 Godot 实现的有意偏离，应写入 README 的已知偏差：Godot 使用 WS 门面；Qt HMI 的热路径使用 DDS。

## 2. 目标

第一切片完成后：

- 真实硬件击打可通过 `pd02/hit/event` 驱动现有 `SessionModel`，与键盘输入走同一业务入口。
- QML 可调用一个稳定接口向 `pd02/led/command` 发布单段或多段 LED 命令，并可发送全部熄灭命令。
- `DeviceHitTestPanel` 可显示真实或键盘输入的最近 segment 和累计击打数。
- TopBar 可显示 DDS 后端状态，但不把“本地 participant 创建成功”误称为“已连接远端发布者”。
- DDS 不可用时不影响页面浏览、截图测试、lint、qml-audit 或键盘回退。

## 3. 非目标

本切片不包含：

- WebSocket 客户端或 Godot `runtime_bridge.gd` 的 JSON 协议兼容层。
- `pd02/pressure/sample`、`pd02/motor/state`、`pd02/pressure/control` 的 UI 接入。
- 设备页约 20 个 REST 端点、战力/课程会话、MJPEG、媒体播放、OTA。
- DDS IDL 或 wire schema 变更。现有 `pd02_motor.idl` 已包含 `HitEvent`、`LedCommand`、`PressureSample` 和 `PressureControl`。
- Qt 直接链接 Fast DDS、复制 participant/discovery/QoS 逻辑，或在 QML 内处理 DDS。
- 以 DDS participant 创建成功推断远端运行时在线。现有 C ABI 没有暴露 publication/subscription match 状态。

## 4. 系统边界

```text
压力板 / CAN
    ↓
qxzn-realtime-runtime-rs
    ├─ publish  pd02/hit/event
    └─ take     pd02/led/command → LED 板
                    ↑
Qt DdsBridge ───────┘
    ├─ hitReceived(...) → SessionModel.onSegment(...)
    ├─ 状态属性 → TopBar
    └─ Q_INVOKABLE LED API ← 游戏页 / 击打测试页

Qt RestClient（后续切片）
    ↔ http://localhost:8000/api/v1/*
    ↔ 设备操作、诊断、课程/战力会话、OTA、云服务
```

DDS 是低延迟数据面；REST 是低频控制和管理面。两者不互相代理。

## 5. DDS Core 契约

Qt 只依赖 `dds-fastdds-core/include/qxzn/pd02/dds/motor_bridge.h` 的 C ABI：

- `qxzn_pd02_dds_create` / `qxzn_pd02_dds_destroy`
- `qxzn_pd02_dds_take_hit_event`
- `qxzn_pd02_dds_publish_led_command`

现有 core 已为所有 Topic 创建 reader/writer，并实现上述函数。Qt 不依赖 generated Fast DDS 类型，也不链接 Fast DDS SDK。

### 5.1 发现配置

当前部署脚本的权威默认值为：

- domain：`37`
- multicast：关闭
- initial peers：`127.0.0.1`
- participant name：`pd02-qt-hmi`
- source：`pd02-qt-hmi`
- hit topic：`pd02/hit/event`
- LED topic：`pd02/led/command`

`motor_bridge.h` 也支持 `server://HOST:PORT` Discovery Server 配置，但当前部署没有使用它；本切片不把 `127.0.0.1:11811` 设为默认值。

### 5.2 QoS

Topic QoS、队列深度、可靠性和 stale-data 行为继续由 `dds-fastdds-core` 集中定义。Qt HMI 不覆盖 QoS，避免与 Rust 运行时产生第二套配置。

## 6. Qt 组件设计

### 6.1 `DdsBridge`

新增 `QObject` 后端并注册为 `QxznHmi.DdsBridge` QML singleton。它只负责传输适配，不持有游戏、页面或会话业务规则。

只读属性：

- `enabled: bool`：配置是否允许 DDS。
- `state: string`：`disabled`、`loading`、`ready`、`receiving`、`error`；收到有效 hit 后进入 `receiving` 2 秒，随后回到 `ready`。
- `ready: bool`：动态库已加载、符号已解析、DDS context 已创建。
- `lastError: string`：最近一次加载、初始化、take 或 publish 错误。
- `lastHitSegment: string`：最近一次有效 DDS segment。
- `lastHitAtMs: qint64`：最近一次有效 DDS 击打的本地接收时间。

信号：

```cpp
void hitReceived(
    const QString &segment,
    const QString &level,
    double confidence,
    const QString &sensor,
    int canId,
    int sensorIndex,
    qint64 detectedAtMs);
```

QML 方法：

```cpp
Q_INVOKABLE bool flashSegments(
    const QStringList &segments,
    const QColor &color,
    int durationMs);

Q_INVOKABLE bool sendLedCommand(
    const QStringList &segments,
    const QColor &color,
    int durationMs,
    const QString &sessionId,
    const QString &beatId,
    const QString &reason);

Q_INVOKABLE bool turnOffAllLeds(
    const QString &sessionId,
    const QString &reason);
```

返回 `false` 表示命令未发布；详细原因写入 `lastError`。QML 不接触 C 结构体。

### 6.2 生命周期

1. QML singleton 工厂只构造 `DdsBridge`，不在工厂内启动外部通信。
2. `main.cpp` 在 QML engine 加载成功并取得 `Config`/`DdsBridge`/`SessionModel` singleton 后调用 `DdsBridge::start(config)`。
3. `start` 使用 `QLibrary` 加载 core、解析所需符号并创建 context。
4. 成功后启动 10 ms `QTimer`；每 tick 使用 `timeout_ms=0` 非阻塞调用 `take_hit_event`，并一次最多 drain 64 条样本，避免单帧无界工作。
5. `main.cpp` 以 C++ signal/slot 将 `DdsBridge::hitReceived` 的 segment 接到 `SessionModel::onSegment`，因此页面未加载时也不会丢失业务更新。
6. 退出时停止 timer，再 destroy context，最后卸载动态库。

第一版不创建工作线程：core 的 `timeout_ms=0` take 是非阻塞调用，10 ms 轮询可保持实现小且可测试。若真机测得 UI frame jitter，再把相同接口的轮询实现移入 worker thread，不改变 QML API。

### 6.3 Segment 校验

DDS `HitEvent.segment` 按协议应为标准逻辑 segment。Qt 仍只接受以下七个值：

- `head_left`
- `head_mid`
- `head_right`
- `chin`
- `waist_left`
- `waist_mid`
- `waist_right`

空值或未知值不发送 `hitReceived`，仅限频记录 warning。键盘映射保持原样，与 DDS 最终都调用 `SessionModel::onSegment`。

### 6.4 LED 命令构造

- `DdsBridge` 不会在收到 hit 时自动发布 LED，避免与实时运行时自身的 hit-led 反馈重复；只响应游戏或页面的显式调用。
- IDL 每个 `LedCommand` 只有一个 `segment`，因此多段请求按输入顺序发布多条样本。
- `command_type=LED_COMMAND_SET`，`mode=1`，`param=0`。
- RGB 从 `QColor` 转成 0–255，并限制到合法范围。
- `durationMs` 限制为 `0..5000`；第一切片常用值为 80 ms（熄灯过渡）和 180 ms（击打闪烁）。
- `source=pd02-qt-hmi`；空 `sessionId` 自动生成进程级 HMI session id。
- `sequence_id` 单调递增，`timestamp_us` 使用 Unix epoch 微秒。
- `turnOffAllLeds` 发布 `LED_COMMAND_ALL_OFF`，segment 为空。
- 发布任一段失败时方法返回 `false` 并停止发布剩余段，避免向调用方报告虚假成功。

## 7. 配置

扩展 `Config`，配置优先级为 CLI > 环境变量 > 默认值：

| 用途 | CLI | 环境变量 | 默认值 |
|---|---|---|---|
| DDS 开关 | `--dds` / `--no-dds` | `PD02_DDS_ENABLE` | 启用 |
| core 路径 | `--dds-core-lib PATH` | `PD02_DDS_CORE_LIB` | 应用同目录的 `libqxzn_pd02_dds_core.so`；开发环境再尝试 PD02 core build 路径 |
| domain | `--dds-domain-id N` | `PD02_DDS_DOMAIN_ID` | `37` |
| multicast | `--dds-multicast` / `--no-dds-multicast` | `PD02_DDS_MULTICAST` | 关闭 |
| peers | `--dds-initial-peers VALUE` | `PD02_DDS_INITIAL_PEERS` | `127.0.0.1` |
| participant | `--dds-participant NAME` | `PD02_DDS_PARTICIPANT_NAME` | `pd02-qt-hmi` |
| hit topic | `--dds-hit-event-topic NAME` | `PD02_DDS_HIT_EVENT_TOPIC` | `pd02/hit/event` |
| LED topic | `--dds-led-command-topic NAME` | `PD02_DDS_LED_COMMAND_TOPIC` | `pd02/led/command` |

继续保留现有 `--ws-url`/`Config.wsUrl`，以免破坏 CLI 兼容性，但 DDS-direct 第一切片不读取它。`--api-base` 继续作为后续 `RestClient` 的入口。

## 8. 构建与仓库边界

- `DdsBridge` 加入 `qxzn_core`；只需要现有 `Qt6::Core`/`Qt6::Gui`，第一切片不新增 `Qt6::Network` 或 `Qt6::WebSockets`。
- CMake 通过 cache path 查找 `qxzn/pd02/dds/motor_bridge.h`，默认提示位于相邻 `../dds-fastdds-core/include`。
- 提供 `QXZN_HMI_DDS=OFF` 构建选项，使 qxzn-hmi-qt 独立仓在没有 PD02 sibling checkout 时仍能编译；该模式保留相同 QML singleton/API，但固定为 `disabled`。
- DDS-enabled 构建找不到 ABI header 时配置阶段明确失败，不静默退化。
- 动态库不在链接阶段加入 qxzn_hmi，因此运行时缺库不会阻止程序启动。
- 部署时优先把目标架构的 `.so` 放到 qxzn_hmi 可执行文件同目录；也可用 `PD02_DDS_CORE_LIB` 指定绝对路径。仅复制 core 本身不够：必须用 `ldd` 确认匹配架构的 Fast DDS/Fast CDR/foonathan 等非系统依赖均可解析，可利用 core 的 `$ORIGIN` RPATH 同目录打包或加载 PD02 Fast DDS 环境。

## 9. QML/UI 接入

### 9.1 `DeviceHitTestPanel`

第一切片把静态内容替换为：

- 大数字绑定 `SessionModel.strikes`。
- 显示最近 segment（`SessionModel.lastSegment`）。
- 状态 chip 显示 `DdsBridge.state`；键盘输入仍计数，即便 DDS 为 disabled/error。
- “开始游戏/结束游戏”仍保持未移植 callout；本切片不伪造后端 hit-game session API。
- 不因打开或关闭面板而开始/停止 DDS；bridge 是应用级输入源。

### 9.2 TopBar

现有 64×64 静态网络区域保持原几何，图标色与小圆点显示 DDS 状态：`ready/receiving` 正常色、`loading` 警告色、`disabled` 弱化色、`error` 危险色；error 点击通过现有 callout 显示 `lastError`。详细“DDS 已就绪/接收中/离线模式”文案显示在 DevicePage 和 DeviceHitTestPanel，不使用“已连接”，因为本切片没有远端 match 状态。

## 10. 错误处理与恢复

- `--no-dds` 或 DDS-disabled 构建：状态为 `disabled`，所有发布调用返回 `false`，不输出重复错误。
- 动态库缺失、符号缺失或 create 失败：状态为 `error`；记录可操作错误，并每 2 秒重试，最长退避到 10 秒。
- `take_hit_event` 返回错误：停止轮询、销毁 context、进入重试；不会在 UI tick 上持续刷日志。
- `publish_led_command` 失败：本次调用返回 `false`；连续 3 次失败异步触发 context 重建，任一成功发布会重置计数。
- 非法 segment：丢弃，不更新 `SessionModel`。
- HMI 在所有错误状态下保持可操作；键盘回退不依赖 DDS。

## 11. 测试策略

### 11.1 `tst_core`

新增单元测试：

- DDS CLI/环境配置优先级与默认值。
- disabled 构建/`--no-dds` 下 bridge 可构造、可启动、不会崩溃。
- 缺失 `.so` 时进入 `error`，错误信息非空，应用不退出。
- raw `HitEvent` 到 Qt signal 参数的转换与七 segment 白名单。
- LED raw 构造：RGB、duration clamp、command type、source/session/reason、ALL_OFF。
- 多段发布遇到中途失败时返回 `false`，且不继续发布后续段。

传输函数表允许测试注入 fake function pointers；测试不启动真实 Fast DDS participant。

### 11.2 DDS 集成测试

当 `PD02_DDS_CORE_LIB` 指向可用核心时，增加可选 `dds_smoke`：

1. 创建测试 publisher context。
2. 向独立测试 topic 发布一条 `HitEvent`。
3. 等待 `DdsBridge.hitReceived` 并核对 segment/metadata。
4. 由 `DdsBridge.sendLedCommand` 发布，再由测试 context take 并核对 wire 字段。

测试使用独立 topic 名和 participant 名，不操作真实 LED。没有 core 库时明确 skip，不将 skip 报为通过实机验证。

### 11.3 项目基线

每次改动保持以下命令全绿：

```bash
cmake --build build --parallel 6
ctest --test-dir build --output-on-failure
qtcli --json --project . lint
qtcli --json --project . qml-audit --strict
```

并使用 `--windowed --nav device --overlay hit_test --screenshot ...` 目检击打测试面板。

## 12. 验收标准

第一切片完成需同时满足：

1. `dds-fastdds-core` 重建及其 `ctest` 全绿，生成的 `.so` 包含 `qxzn_pd02_dds_take_hit_event`。
2. qxzn-hmi-qt 在 DDS disabled、库缺失、库可用三种状态下行为符合设计。
3. 键盘 Q/W/E/R/X/A/S/D/F 与 DDS hit 都经过同一 `SessionModel::onSegment` 路径。
4. DDS smoke 验证 hit 收取和 LED 发布的 wire 字段。
5. DeviceHitTestPanel 显示累计数与最近 segment；TopBar 状态语义准确。
6. 构建、ctest、lint、strict qml-audit 全绿。
7. README 与 `docs/PORTING_HANDOFF.md` 更新：记录 DDS-direct 偏差，并把当前发现配置修正为 domain 37 + multicast off + initial peer `127.0.0.1`。
8. 不修改 Godot 仓，不把 Fast DDS SDK 逻辑复制进 Qt，不提交媒体或生成构建产物。

## 13. 后续切片

按依赖顺序继续：

1. `pd02/pressure/sample` → DevicePressurePanel 的实时板卡值、stale 和 latency。
2. `pd02/motor/state` → 设备健康/课程 BodyCombat 状态。
3. `pd02/pressure/control` → 游戏 session 开始/结束。
4. `RestClient` → 设备低频操作、诊断、课程/战力 session、OTA。
5. 以 Piano Tiles 为游戏样板，消费统一 hit signal、发布 LED 命令，并保留键盘回退。
