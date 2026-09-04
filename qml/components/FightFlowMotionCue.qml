pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D
import QxznHmi

// Fight Flow 棍靶提示 3D 场景:复刻 lessons_test/motion-visualizer.js 的
// Three.js 场景(与 Godot 版 fight_flow_motion_cue.gd 同构)。
// View3D 透明背景 + MSAA;Node 层级 root→yaw→pitch→end;19 帧轨迹关键帧
// 插值驱动出拳循环;轨迹管用向心 Catmull-Rom 采样的球链近似(Quick3D
// 无内置 Torus/Tube 几何,球链在 222×186 显示尺寸下观感等价)。
// playing=false 时 FrameAnimation 停止,姿态自然冻结,零额外开销。
Item {
    id: cue

    property bool playing: false

    // ---- 与 motion-visualizer.js 一致的运动学/时间参数 ----
    readonly property real horizontalLink: 0.36
    readonly property real verticalLink: 1.8
    // Qt Quick 3D built-in primitives are 100 units wide/tall by default.
    // The Fight Flow kinematics use meter-like units, so every primitive mesh
    // scale must include this conversion while node positions stay unchanged.
    readonly property real primitiveUnit: 0.01
    readonly property real durationMs: 2042.0
    readonly property real keySwingMs: 1562.0
    readonly property color colorTarget: "#ff4d45"
    readonly property color colorNeutral: "#8b9690"
    readonly property color colorActiveArm: "#2c3230"
    readonly property color colorDarkMetal: "#19211f"

    readonly property var trajectoryFrames: [
        { t: 0, m03: 16.0, m04: -130.0, m05: -16.0, m06: 130.0 },
        { t: 120, m03: 16.0, m04: -130.0, m05: -16.0, m06: 128.55 },
        { t: 240, m03: 16.0, m04: -130.0, m05: -16.0, m06: 121.74 },
        { t: 360, m03: 16.0, m04: -130.0, m05: -15.86, m06: 111.3 },
        { t: 480, m03: 16.0, m04: -130.0, m05: -12.84, m06: 102.48 },
        { t: 600, m03: 16.0, m04: -130.0, m05: -4.4, m06: 99.0 },
        { t: 720, m03: 16.0, m04: -130.0, m05: 8.57, m06: 98.87 },
        { t: 841, m03: 16.0, m04: -130.0, m05: 23.13, m06: 100.23 },
        { t: 961, m03: 16.0, m04: -130.0, m05: 35.52, m06: 107.22 },
        { t: 1081, m03: 16.0, m04: -130.0, m05: 43.04, m06: 119.97 },
        { t: 1201, m03: 16.0, m04: -130.0, m05: 45.3, m06: 134.89 },
        { t: 1321, m03: 16.0, m04: -130.0, m05: 44.94, m06: 147.26 },
        { t: 1442, m03: 16.0, m04: -130.0, m05: 40.35, m06: 153.73 },
        { t: 1562, m03: 16.0, m04: -130.0, m05: 29.58, m06: 154.78 },
        { t: 1682, m03: 16.0, m04: -130.0, m05: 14.67, m06: 152.76 },
        { t: 1802, m03: 16.0, m04: -130.0, m05: -0.24, m06: 145.23 },
        { t: 1922, m03: 16.0, m04: -130.0, m05: -11.05, m06: 135.85 },
        { t: 2042, m03: 16.0, m04: -130.0, m05: -15.6, m06: 130.55 }
    ]

    property real timeMs: 0.0
    property var trajPoints: []

    Component.onCompleted: {
        trajPoints = buildTrajectoryPoints();
        applyFrame(interpolateFrame(0));
    }

    // 仅播放时推进;暂停/页面隐藏即冻结(对应 Godot 版 UPDATE_ONCE/DISABLED)
    FrameAnimation {
        running: cue.playing && cue.visible
        onTriggered: cue.advance(frameTime * 1000.0)
    }

    function advance(dtMs) {
        timeMs = (timeMs + dtMs) % durationMs;
        applyMotion(Date.now());
    }

    // 对应 motion-visualizer.js render():出拳姿态 + 预警呼吸/冲击波
    function applyMotion(now) {
        applyFrame(interpolateFrame(timeMs));
        const untilSwing = timeMs <= keySwingMs ? keySwingMs - timeMs
                                                : durationMs - timeMs + keySwingMs;
        const urgency = Math.max(0, Math.min(1, 1 - untilSwing / 900));
        const pulseSpeed = 0.009 + (0.021 - 0.009) * urgency;
        const pulse = 0.5 + 0.5 * Math.sin(now * pulseSpeed);
        const strength = 0.26 + urgency * 0.62 + pulse * (0.16 + urgency * 0.2);
        const shockwavePhase = (now * (0.0012 + urgency * 0.0019)) % 1;
        warnBandMaterial0.opacity = Math.min(0.96, strength * 0.9);
        warnBandMaterial1.opacity = Math.min(0.98, strength * (0.94 + pulse * 0.06));
        endWarnMaterial.opacity = Math.min(0.9, strength * 0.88);
        trajMaterial.opacity = 0.2 + urgency * 0.16 + pulse * 0.07;
        warningBand0.scale = Qt.vector3d(0.39, 0.42, 0.38).times(
                    primitiveUnit * (1 + strength * 0.16));
        warningBand1.scale = Qt.vector3d(0.42, 0.46, 0.41).times(
                    primitiveUnit * (1 + strength * 0.22));
        endWarning.scale = Qt.vector3d(0.8, 0.8, 0.8).times(
                    primitiveUnit * (1 + strength * 0.32));
        endShockwave.scale = Qt.vector3d(0.92, 0.92, 0.92).times(
                    primitiveUnit * (1.05 + shockwavePhase * (0.9 + urgency * 0.55)));
        shockwaveMaterial.opacity = (1 - shockwavePhase) * (0.12 + urgency * 0.38);
        // Three.js 与 Quick3D 光强单位不同,按观感折算,以截图验证为准
        warningLight.brightness = 0.6 + strength * 3.0;
    }

    // 对应 applyFrame():arm03 固定姿态,arm05 活动臂
    function applyFrame(angles) {
        arm03Yaw.eulerRotation.y = angles.m03;
        arm03Pitch.eulerRotation.x = -angles.m04;
        arm05Yaw.eulerRotation.y = angles.m05;
        arm05Pitch.eulerRotation.x = angles.m06;
    }

    // 对应 interpolateFrame():相邻关键帧线性插值
    function interpolateFrame(t) {
        if (t <= 0)
            return trajectoryFrames[0];
        if (t >= durationMs)
            return trajectoryFrames[trajectoryFrames.length - 1];
        let low = 0, high = trajectoryFrames.length - 1;
        while (low + 1 < high) {
            const middle = (low + high) >> 1;
            if (trajectoryFrames[middle].t <= t)
                low = middle;
            else
                high = middle;
        }
        const before = trajectoryFrames[low], after = trajectoryFrames[high];
        const ratio = (t - before.t) / (after.t - before.t);
        return {
            m03: before.m03 + (after.m03 - before.m03) * ratio,
            m04: before.m04 + (after.m04 - before.m04) * ratio,
            m05: before.m05 + (after.m05 - before.m05) * ratio,
            m06: before.m06 + (after.m06 - before.m06) * ratio
        };
    }

    // arm05 端部世界坐标(与 Godot 版 Transform3D 推导逐项对应)
    function arm05EndPoint(m05deg, m06deg) {
        const yaw = m05deg * Math.PI / 180;
        const pitch = m06deg * Math.PI / 180;
        const y1 = -verticalLink * Math.cos(pitch);
        const z1 = -verticalLink * Math.sin(pitch);
        const x1 = horizontalLink;
        const x2 = x1 * Math.cos(yaw) + z1 * Math.sin(yaw);
        const z2 = -x1 * Math.sin(yaw) + z1 * Math.cos(yaw);
        return Qt.vector3d(0.88 + x2, 1.28 + y1, z2);
    }

    // 向心 Catmull-Rom(three.js CatmullRomCurve3 "centripetal" 同款公式),
    // 端点外推处理非闭合曲线;采样成球链位置数组
    function buildTrajectoryPoints() {
        const keys = trajectoryFrames.map(function(f) { return arm05EndPoint(f.m05, f.m06); });
        const points = [];
        const n = keys.length;
        const samplesPerSegment = 3;
        for (let seg = 0; seg < n - 1; ++seg) {
            const p0 = seg > 0 ? keys[seg - 1] : keys[0].times(2).minus(keys[1]);
            const p1 = keys[seg];
            const p2 = keys[seg + 1];
            const p3 = seg + 2 < n ? keys[seg + 2] : keys[n - 1].times(2).minus(keys[n - 2]);
            // 向心参数化:dt = |p|^0.5(three.js 对平方距离取 0.25 次幂)
            const dt0 = Math.pow(Math.max(1e-8, squaredDistance(p0, p1)), 0.25);
            const dt1 = Math.pow(Math.max(1e-8, squaredDistance(p1, p2)), 0.25);
            const dt2 = Math.pow(Math.max(1e-8, squaredDistance(p2, p3)), 0.25);
            for (let s = 0; s < samplesPerSegment; ++s) {
                const t = s / samplesPerSegment;
                points.push(catmullRomPoint(p0, p1, p2, p3, dt0, dt1, dt2, t));
            }
        }
        points.push(keys[n - 1]);
        return points;
    }

    function squaredDistance(a, b) {
        const dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z;
        return dx * dx + dy * dy + dz * dz;
    }

    // three.js CubicPoly.initNonuniformCatmullRom 的 Hermite 形式
    function catmullRomPoint(p0, p1, p2, p3, dt0, dt1, dt2, t) {
        function tangent(c0, c1, c2, c3) {
            let t1 = (c1 - c0) / dt0 - (c2 - c0) / (dt0 + dt1) + (c2 - c1) / dt1;
            let t2 = (c2 - c1) / dt1 - (c3 - c1) / (dt1 + dt2) + (c3 - c2) / dt2;
            return [t1 * dt1, t2 * dt1];
        }
        function axis(c0, c1, c2, c3) {
            const tangents = tangent(c0, c1, c2, c3);
            const cA = c1, cB = tangents[0];
            const cC = -3 * c1 + 3 * c2 - 2 * tangents[0] - tangents[1];
            const cD = 2 * c1 - 2 * c2 + tangents[0] + tangents[1];
            return ((cD * t + cC) * t + cB) * t + cA;
        }
        return Qt.vector3d(axis(p0.x, p1.x, p2.x, p3.x),
                           axis(p0.y, p1.y, p2.y, p3.y),
                           axis(p0.z, p1.z, p2.z, p3.z));
    }

    // ---- 共享材质(金属度参照 Godot 版经验值,比 Three.js 原版低:
    //      Quick3D 无环境探针时高金属度同样偏暗)----
    PrincipledMaterial {
        id: darkMetalMaterial
        baseColor: cue.colorDarkMetal
        metalness: 0.4
        roughness: 0.3
    }
    PrincipledMaterial {
        id: carrierMaterial
        baseColor: "#313b37"
        metalness: 0.32
        roughness: 0.32
    }
    PrincipledMaterial {
        id: neutralArmMaterial
        baseColor: cue.colorNeutral
        metalness: 0.3
        roughness: 0.34
        emissiveFactor: Qt.vector3d(0.063, 0.082, 0.078)
    }
    PrincipledMaterial {
        id: activeArmMaterial
        baseColor: cue.colorActiveArm
        metalness: 0.3
        roughness: 0.34
        emissiveFactor: Qt.vector3d(0.067, 0.082, 0.078)
    }
    PrincipledMaterial {
        id: platformMaterial
        baseColor: "#121816"
        metalness: 0.28
        roughness: 0.52
    }
    PrincipledMaterial {
        id: torsoMaterial
        baseColor: "#202825"
        metalness: 0.3
        roughness: 0.35
    }
    PrincipledMaterial {
        id: centerPanelMaterial
        baseColor: "#252d2a"
        metalness: 0.0
        roughness: 0.35
        emissiveFactor: Qt.vector3d(0.051, 0.067, 0.063)
    }
    PrincipledMaterial {
        id: headMaterial
        baseColor: "#343d39"
        metalness: 0.3
        roughness: 0.32
    }
    PrincipledMaterial {
        id: gridMaterial
        baseColor: "#2e3633"
        metalness: 0.0
        roughness: 0.9
        opacity: 0.32
        alphaMode: PrincipledMaterial.Blend
        lighting: PrincipledMaterial.NoLighting
    }
    // 预警/辉光材质:无光照 + 透明;Screen 混合近似 THREE.AdditiveBlending,
    // depthDrawMode Never 对应 depthWrite=false
    PrincipledMaterial {
        id: warnBandMaterial0
        baseColor: cue.colorTarget
        lighting: PrincipledMaterial.NoLighting
        opacity: 0.36
        alphaMode: PrincipledMaterial.Blend
        depthDrawMode: PrincipledMaterial.NeverDepthDraw
        cullMode: PrincipledMaterial.NoCulling
    }
    PrincipledMaterial {
        id: warnBandMaterial1
        baseColor: cue.colorTarget
        lighting: PrincipledMaterial.NoLighting
        opacity: 0.36
        alphaMode: PrincipledMaterial.Blend
        depthDrawMode: PrincipledMaterial.NeverDepthDraw
        cullMode: PrincipledMaterial.NoCulling
    }
    PrincipledMaterial {
        id: endWarnMaterial
        baseColor: cue.colorTarget
        lighting: PrincipledMaterial.NoLighting
        opacity: 0.34
        alphaMode: PrincipledMaterial.Blend
        blendMode: PrincipledMaterial.Screen
        depthDrawMode: PrincipledMaterial.NeverDepthDraw
        cullMode: PrincipledMaterial.NoCulling
    }
    PrincipledMaterial {
        id: shockwaveMaterial
        baseColor: cue.colorTarget
        lighting: PrincipledMaterial.NoLighting
        opacity: 0.18
        alphaMode: PrincipledMaterial.Blend
        blendMode: PrincipledMaterial.Screen
        depthDrawMode: PrincipledMaterial.NeverDepthDraw
        cullMode: PrincipledMaterial.NoCulling
    }
    PrincipledMaterial {
        id: trajMaterial
        baseColor: cue.colorTarget
        lighting: PrincipledMaterial.NoLighting
        opacity: 0.28
        alphaMode: PrincipledMaterial.Blend
        blendMode: PrincipledMaterial.Screen
        depthDrawMode: PrincipledMaterial.NeverDepthDraw
        cullMode: PrincipledMaterial.NoCulling
    }
    PrincipledMaterial {
        id: axisRingMaterial
        baseColor: cue.colorNeutral
        lighting: PrincipledMaterial.NoLighting
        opacity: 0.3
        alphaMode: PrincipledMaterial.Blend
        depthDrawMode: PrincipledMaterial.NeverDepthDraw
    }

    // ================= 3D 场景 =================
    View3D {
        id: view3d
        anchors.fill: parent
        camera: sceneCamera

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        // 相机眼位 (0,2.95,-7.1) 看向 (0,0.45,0):嵌套单轴旋转避免
        // eulerRotation 多轴顺序歧义(yaw 180° + pitch -19.3°)
        Node {
            position: Qt.vector3d(0, 2.95, -7.1)
            eulerRotation.y: 180
            Node {
                eulerRotation.x: -19.3
                PerspectiveCamera {
                    id: sceneCamera
                    fieldOfView: 34
                    clipNear: 0.1
                    clipFar: 30
                }
            }
        }

        // 主光:Three.js 位置 (4,7,-5) 指向原点 → yaw 141.3° + pitch -47.5°
        Node {
            eulerRotation.y: 141.3
            DirectionalLight {
                eulerRotation.x: -47.5
                brightness: 1.7
                castsShadow: false
            }
        }
        // 补光:(-4,2,3) → yaw -53.1° + pitch -21.8°
        Node {
            eulerRotation.y: -53.1
            DirectionalLight {
                eulerRotation.x: -21.8
                color: "#aab5af"
                brightness: 0.6
                castsShadow: false
            }
        }
        // 相机方向弱填充,补偿无 HemisphereLight 的环境项
        Node {
            DirectionalLight {
                eulerRotation.x: -19.3
                brightness: 0.35
                castsShadow: false
            }
        }

        // 平台 / 躯干 / 胸前板 / 头部(primitiveUnit 把内置 100-unit 几何换算到场景单位)
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(0, -0.68, 0)
            scale: Qt.vector3d(4.3, 0.24, 4.3).times(cue.primitiveUnit)
            materials: [platformMaterial]
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 0.18, 0)
            scale: Qt.vector3d(1.55, 2.05, 0.82).times(cue.primitiveUnit)
            materials: [torsoMaterial]
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 0.28, -0.45)
            scale: Qt.vector3d(0.82, 1.12, 0.08).times(cue.primitiveUnit)
            materials: [centerPanelMaterial]
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 1.55, 0)
            scale: Qt.vector3d(0.72, 0.5, 0.62).times(cue.primitiveUnit)
            materials: [headMaterial]
        }

        // 地面网格:8×8 范围 0.5 间隔细条(GridHelper 近似)
        Repeater3D {
            model: 34
            delegate: Model {
                required property int index
                readonly property real offset: -4.0 + 0.5 * (index % 17)
                readonly property bool alongX: index < 17
                source: "#Cube"
                position: alongX ? Qt.vector3d(0, -0.8, offset) : Qt.vector3d(offset, -0.8, 0)
                scale: (alongX ? Qt.vector3d(8, 0.004, 0.012)
                               : Qt.vector3d(0.012, 0.004, 8)).times(cue.primitiveUnit)
                materials: [gridMaterial]
            }
        }

        // arm05 端部轨迹球链(近似 Three.js TubeGeometry 双层辉光)
        Repeater3D {
            model: cue.trajPoints
            delegate: Model {
                required property var modelData
                source: "#Sphere"
                position: modelData
                scale: Qt.vector3d(0.13, 0.13, 0.13).times(cue.primitiveUnit)
                materials: [trajMaterial]
            }
        }

        // ---- 左臂 arm03(中立)----
        Node {
            position: Qt.vector3d(-0.88, 1.28, 0)
            Node {
                id: arm03Yaw
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(0.56, 0.34, 0.56).times(cue.primitiveUnit)
                    materials: [darkMetalMaterial]
                }
                Model {
                    source: "#Cube"
                    position: Qt.vector3d(-0.18, 0, 0)
                    scale: Qt.vector3d(0.36, 0.18, 0.22).times(cue.primitiveUnit)
                    materials: [carrierMaterial]
                }
                // 轴向环:Quick3D 无内置 Torus,用薄圆盘近似(装饰件)
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(0.78, 0.02, 0.78).times(cue.primitiveUnit)
                    materials: [axisRingMaterial]
                }
                Node {
                    id: arm03Pitch
                    position: Qt.vector3d(-0.36, 0, 0)
                    Model {
                        source: "#Cylinder"
                        scale: Qt.vector3d(0.44, 0.5, 0.44).times(cue.primitiveUnit)
                        eulerRotation.z: 90
                        materials: [neutralArmMaterial]
                    }
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, -0.9, 0)
                        scale: Qt.vector3d(0.24, 1.8, 0.22).times(cue.primitiveUnit)
                        materials: [neutralArmMaterial]
                    }
                    Model {
                        source: "#Sphere"
                        position: Qt.vector3d(0, -1.8, 0)
                        scale: Qt.vector3d(0.56, 0.56, 0.56).times(cue.primitiveUnit)
                        materials: [neutralArmMaterial]
                    }
                }
            }
        }

        // ---- 右臂 arm05(活动,带红色预警)----
        Node {
            position: Qt.vector3d(0.88, 1.28, 0)
            Node {
                id: arm05Yaw
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(0.56, 0.34, 0.56).times(cue.primitiveUnit)
                    materials: [darkMetalMaterial]
                }
                Model {
                    source: "#Cube"
                    position: Qt.vector3d(0.18, 0, 0)
                    scale: Qt.vector3d(0.36, 0.18, 0.22).times(cue.primitiveUnit)
                    materials: [carrierMaterial]
                }
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(0.78, 0.02, 0.78).times(cue.primitiveUnit)
                    materials: [axisRingMaterial]
                }
                Node {
                    id: arm05Pitch
                    position: Qt.vector3d(0.36, 0, 0)
                    Model {
                        source: "#Cylinder"
                        scale: Qt.vector3d(0.44, 0.5, 0.44).times(cue.primitiveUnit)
                        eulerRotation.z: 90
                        materials: [activeArmMaterial]
                    }
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, -0.9, 0)
                        scale: Qt.vector3d(0.24, 1.8, 0.22).times(cue.primitiveUnit)
                        materials: [activeArmMaterial]
                    }
                    // 中后段预警包围盒(透明度/缩放每帧驱动)
                    Model {
                        id: warningBand0
                        source: "#Cube"
                        position: Qt.vector3d(0, -0.78, 0)
                        scale: Qt.vector3d(0.39, 0.42, 0.38).times(cue.primitiveUnit)
                        materials: [warnBandMaterial0]
                    }
                    Model {
                        id: warningBand1
                        source: "#Cube"
                        position: Qt.vector3d(0, -1.34, 0)
                        scale: Qt.vector3d(0.42, 0.46, 0.41).times(cue.primitiveUnit)
                        materials: [warnBandMaterial1]
                    }
                    Node {
                        position: Qt.vector3d(0, -1.8, 0)
                        Model {
                            source: "#Sphere"
                            scale: Qt.vector3d(0.56, 0.56, 0.56).times(cue.primitiveUnit)
                            materials: [activeArmMaterial]
                        }
                        Model {
                            id: endWarning
                            source: "#Sphere"
                            scale: Qt.vector3d(0.8, 0.8, 0.8).times(cue.primitiveUnit)
                            materials: [endWarnMaterial]
                        }
                        Model {
                            id: endShockwave
                            source: "#Sphere"
                            scale: Qt.vector3d(0.92, 0.92, 0.92).times(cue.primitiveUnit)
                            materials: [shockwaveMaterial]
                        }
                        PointLight {
                            id: warningLight
                            color: cue.colorTarget
                            brightness: 0.6
                            constantFade: 1.0
                            linearFade: 0.0
                            quadraticFade: 2.0
                            castsShadow: false
                        }
                    }
                }
            }
        }
    }
}
