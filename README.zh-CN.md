# qxzn-hmi-qt

QXZN 15.6 英寸车载 HMI 界面的 Qt Quick 移植版（原 Godot 项目位于 `../15-6inch-game-runtime-qxzn`）。深色仪表盘布局，包含 TopBar 和由标准"分段"键盘输入驱动的实时健身数据面板。

本项目旨在**自用测试 [`qtcli`](../tools/qtcli)** ——以一个真实的 Qt 项目驱动其检查命令并暴露不足之处。

## 构建与运行

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/opt/Qt/6.11.1/gcc_64
cmake --build build
./build/qxzn_hmi                      # 全屏信息亭模式
./build/qxzn_hmi --windowed           # 窗口模式
./build/qxzn_hmi -platform offscreen --windowed --quit-after-ms 800   # 无头冒烟测试
```

## 分段输入（键盘）

| 分段 | 按键 | | 分段 | 按键 |
|---|---|---|---|---|
| head_left | Q | | chin | X |
| head_mid | W / E | | waist_left | A |
| head_right | R | | waist_mid | S / D |
| | | | waist_right | F |

命中会更新 次数 / 卡路里 / 频率；时长每秒递增。

## CLI 参数

`--ws-url`、`--api-base`、`--game-id`、`--difficulty simple|hard`、`--max-fps`、`--windowed`、`--quit-after-ms`。网络与硬件在本阶段为桩实现。

## 测试

```bash
(cd build && ctest --output-on-failure)   # C++ 单元测试
bash tests/smoke.sh                         # 无头冒烟测试
```

## 许可证

MIT。
