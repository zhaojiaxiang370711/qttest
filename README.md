# qxzn-hmi-qt

A Qt Quick port of the QXZN 15.6″ car-HMI shell (originally a Godot project at `../15-6inch-game-runtime-qxzn`). Dark dashboard with a TopBar and a live fitness dashboard driven by standard "segment" keyboard input.

This project exists to **dogfood [`qtcli`](../tools/qtcli)** — a real Qt project to drive its inspection commands and surface gaps.

## Build & run

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/opt/Qt/6.11.1/gcc_64
cmake --build build
./build/qxzn_hmi                      # fullscreen kiosk
./build/qxzn_hmi --windowed           # windowed
./build/qxzn_hmi -platform offscreen --windowed --quit-after-ms 800   # headless smoke
```

## Segment input (keyboard)

| Segment | Key | | Segment | Key |
|---|---|---|---|---|
| head_left | Q | | chin | X |
| head_mid | W / E | | waist_left | A |
| head_right | R | | waist_mid | S / D |
| | | | waist_right | F |

Hits update Strikes / Calories / Frequency; Duration ticks each second.

## CLI flags

`--ws-url`, `--api-base`, `--game-id`, `--difficulty simple|hard`, `--max-fps`, `--windowed`, `--quit-after-ms`. Networking/hardware are stubbed in this slice.

## Test

```bash
(cd build && ctest --output-on-failure)   # C++ unit tests
bash tests/smoke.sh                         # offscreen smoke
```

## License

MIT.
