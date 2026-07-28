pragma Singleton
import QtQuick

// Static seed data ported 1:1 from the Godot shell (shell_data.gd, home_page.gd
// defaults, sparring_history_page.gd, device_page.gd). This singleton is the
// single replacement point when real data sources arrive.
// Card `color` is the Godot HMI_* hex; `tone` is the matching HmiIcon tone
// (cyan/green/yellow/red/orange/muted/white) for baked Lucide SVG variants.
QtObject {
    id: shellData

    // -- nav (shell_data.gd nav_items) --
    readonly property var navItems: [
        { "id": "home",          "label": "首页",     "title": "训练总览",         "subtitle": "快速开始、今日数据、设备状态和社交小组件", "color": "#00F0FF", "tone": "cyan"   },
        { "id": "learning",      "label": "课程",     "title": "拳击基础学习中心", "subtitle": "课程旧版功能入口迁移。",                 "color": "#00FF78", "tone": "green"  },
        { "id": "result",        "label": "实战对练", "title": "实战对练",         "subtitle": "实战对练表现总览、训练数据与历史趋势",     "color": "#00F0FF", "tone": "cyan"   },
        { "id": "entertainment", "label": "娱乐模式", "title": "娱乐模式中心",     "subtitle": "互动游戏、音乐训练与创作工具入口。",       "color": "#FF003C", "tone": "red"    }
    ]

    // -- page cards (shell_data.gd page_cards, full copy) --
    readonly property var combatModes: [
        { "id": "speed",    "title": "全速击打 (Speed)",   "subtitle": "快速连续击打头部中间，限时 10 秒。",   "tag": "MODE", "color": "#00F0FF", "tone": "cyan"   },
        { "id": "reaction", "title": "神经反应 (Reaction)", "subtitle": "灯带亮绿后立刻击打，统计反应时间。", "tag": "MODE", "color": "#FFE600", "tone": "yellow" },
        { "id": "power",    "title": "绝对力量 (Power)",   "subtitle": "全力击打头部中间，记录最大力量值。",   "tag": "MODE", "color": "#FF003C", "tone": "red"    }
    ]

    readonly property var learningCards: [
        { "id": "combat",                  "title": "战力测试",       "subtitle": "拳速、神经反应和绝对力量三项能力测试",                 "tag": "MODE",              "color": "#FF003C", "tone": "red"    },
        { "id": "boxing_knowledge",        "title": "拳击知识",       "subtitle": "查看拳击基础知识、动作规范与训练建议。",               "tag": "/boxing-knowledge", "color": "#00F0FF", "tone": "cyan"   },
        { "id": "basic_actions",           "title": "基础动作学习",   "subtitle": "进入原学习页面，浏览动作讲解与分解演示。",             "tag": "/basic-actions",    "color": "#00FF78", "tone": "green"  },
        { "id": "ai_motion_correction_v2", "title": "AI 动作纠正 2.0", "subtitle": "接入 ROS2 骨骼点与规则引擎，分析护架和右直拳规范。", "tag": "/ai-correction-2",  "color": "#00F0FF", "tone": "cyan", "video_id": "ai_motion_correction_v2_main" },
        { "id": "ai_assistant",            "title": "AI 智能教练",    "subtitle": "AI 驱动的实时动作指导、姿态纠正与个性化训练建议。",    "tag": "/ai-assistant",     "color": "#FF003C", "tone": "red"    }
    ]

    readonly property var resultCards: [
        { "id": "ai_battle",         "title": "AI 对战",      "subtitle": "与内置 AI 进行模拟对战训练，支持多难度调节与动态反应。", "tag": "Godot",  "color": "#FF003C", "tone": "red"    },
        { "id": "tactical_sparring", "title": "实战模拟训练", "subtitle": "AI 自适应战术对练，配置难度、出拳频次和回合时间。",       "tag": "Godot",  "color": "#00F0FF", "tone": "cyan"   },
        { "id": "trend_review",      "title": "训练趋势回顾", "subtitle": "近阶段单次训练出拳量变化。",                             "tag": "CHART",  "color": "#00F0FF", "tone": "cyan"   },
        { "id": "train_again",       "title": "再次训练",     "subtitle": "返回训练模式与配置页面。",                               "tag": "ACTION", "color": "#00FF78", "tone": "green"  },
        { "id": "back_home",         "title": "返回首页",     "subtitle": "回到训练总览。",                                         "tag": "ACTION", "color": "#6B7B9C", "tone": "muted"  }
    ]

    readonly property var deviceCards: [
        { "id": "language_settings", "title": "语言设置",     "subtitle": "默认中文，可切换为英文界面。",       "tag": "中文",       "color": "#00F0FF", "tone": "cyan"   },
        { "id": "pump_start",        "title": "开始自动充气", "subtitle": "启动气泵自动充气流程。",             "tag": "ACTION",     "color": "#00F0FF", "tone": "cyan"   },
        { "id": "pump_stop",         "title": "停止充气",     "subtitle": "停止当前气泵动作。",                 "tag": "ACTION",     "color": "#FF003C", "tone": "red"    },
        { "id": "punch_control",     "title": "出拳控制",     "subtitle": "进入出拳控制页面。",                 "tag": "/punch",     "color": "#FFE600", "tone": "yellow" },
        { "id": "system_management", "title": "系统管理",     "subtitle": "打开系统管理面板。",                 "tag": "PANEL",      "color": "#FF003C", "tone": "red"    },
        { "id": "pump_control",      "title": "气泵控制",     "subtitle": "气泵自动/手动充气控制。",            "tag": "/pump",      "color": "#00F0FF", "tone": "cyan"   },
        { "id": "pressure",          "title": "压力监测",     "subtitle": "9 通道气压实时监测。",               "tag": "/pressure",  "color": "#00F0FF", "tone": "cyan"   },
        { "id": "face",              "title": "人脸跟踪",     "subtitle": "人脸追踪与高度参数调整。",           "tag": "/face",      "color": "#FFE600", "tone": "yellow" },
        { "id": "hit_test",          "title": "击打测试",     "subtitle": "击打传感器联调测试。",               "tag": "/punch-test", "color": "#FF003C", "tone": "red"   },
        { "id": "volume_settings",   "title": "音量设置",     "subtitle": "调节总音量与音频输出。",             "tag": "PANEL",      "color": "#00FF78", "tone": "green"  },
        { "id": "sound_test",        "title": "声音测试",     "subtitle": "播放测试音确认输出链路。",           "tag": "ACTION",     "color": "#00FF78", "tone": "green"  },
        { "id": "display_settings",  "title": "显示设置",     "subtitle": "屏幕亮度和显示参数。",               "tag": "PANEL",      "color": "#00F0FF", "tone": "cyan"   },
        { "id": "dev_tools",         "title": "开发工具",     "subtitle": "调试与硬件联调入口。",               "tag": "/dev-tools", "color": "#FF003C", "tone": "red"    }
    ]

    readonly property var entertainmentCards: [
        { "id": "visual_config",      "title": "游戏参数配置",   "subtitle": "配置轨道、动作图标和全局视觉默认映射。",                   "tag": "/visual",       "color": "#FFE600", "tone": "yellow" },
        { "id": "choreographer",      "title": "动作编排播放器", "subtitle": "进入独立播放页，预览并执行动作编排序列。",                 "tag": "/player",       "color": "#00FF78", "tone": "green"  },
        { "id": "music_settings",     "title": "音乐设置",       "subtitle": "调节总音量、背景音乐与音效，配置音频输出参数。",           "tag": "/music",        "color": "#00F0FF", "tone": "cyan"   },
        { "id": "music_boxing",       "title": "音乐拳击",       "subtitle": "跟随音乐节拍进行拳击训练，支持多种曲风和难度等级。",       "tag": "/music-boxing", "color": "#00FF78", "tone": "green"  },
        { "id": "vr_beats_kit",       "title": "VR 节奏拳击",    "subtitle": "进入独立 3D 节奏拳击场景，跟随音乐完成击打、闪避与防守训练。", "tag": "Godot",       "color": "#FF003C", "tone": "red"    },
        { "id": "sparring_game_tab",  "title": "街机节奏打击",   "subtitle": "网页 Game 页复刻，选择曲目后进入 8 点圆环节奏打击。",       "tag": "Godot",        "color": "#00F0FF", "tone": "cyan"   },
        { "id": "music_lights",       "title": "音乐拳击编辑器", "subtitle": "上传音乐自动生成光效脚本，实时驱动 LED 阵列。",           "tag": "本地",          "color": "#FFE600", "tone": "yellow" },
        { "id": "fitness_games",      "title": "健身小游戏",     "subtitle": "进入 Godot 体感互动小游戏集合，包含星际弹跳。",           "tag": "Godot",        "color": "#FF003C", "tone": "red"    },
        { "id": "rhythm",             "title": "音乐律动",       "subtitle": "跟随音乐节奏进行拳击训练，支持难度选择。",                 "tag": "/rhythm",       "color": "#00F0FF", "tone": "cyan"   },
        { "id": "tracking_challenge", "title": "追踪挑战",       "subtitle": "启动 Godot 版追踪挑战，进行顺序记忆与节奏击打训练。",     "tag": "Godot",        "color": "#00F0FF", "tone": "cyan"   },
        { "id": "agility_challenge",  "title": "敏捷大挑战",     "subtitle": "启动 Godot 版敏捷大挑战，进行头部/腰部双通道体感反应训练。", "tag": "Godot",       "color": "#FFE600", "tone": "yellow" },
        { "id": "fruit_slice",        "title": "切水果挑战",     "subtitle": "启动 Godot 版第一人称切水果，按 QWER / ASDF 对应轨道快速挥刀。", "tag": "Godot",     "color": "#FF003C", "tone": "red"    },
        { "id": "piano_tiles",        "title": "节奏方块",       "subtitle": "启动 Godot 版三轨道下落式节奏游戏，点击方块跟随音乐节拍。", "tag": "Godot",        "color": "#FF003C", "tone": "red"    },
        { "id": "robot_rhythm",       "title": "机器人节奏拳击", "subtitle": "独立复制版页面，供图片素材替换与交互逻辑改造使用。",       "tag": "/robot",        "color": "#00F0FF", "tone": "cyan"   }
    ]

    // -- home summary seeds (home_page.gd _node_view_data defaults) --
    readonly property var homeSummary: ({
        "battleLevel": "专业级",
        "power": 92,          "powerLabel": "力量",
        "speed": 88,          "speedLabel": "速度",
        "endurance": 85,      "enduranceLabel": "耐力",
        "impact": "1000 kgf", "impactLabel": "总冲击力",
        "duration": "74 分钟", "durationLabel": "时长",
        "calories": "4200 千卡", "caloriesLabel": "今日消耗",
        "strikes": "12450",   "strikesLabel": "出拳数",
        "frequency": "142",   "frequencyLabel": "拳频",
        "bookingTitle": "冠军备战",
        "bookingMeta": "Alex 教练 · 专注训练",
        "bookingStatus": "已预约",
        "bookingBadge": "大师课",
        "bookingDuration": "45 分钟",
        "bookingCalories": "650 千卡",
        "bookingDifficulty": "高难 ★★★★★",
        "heroTitle": "拳击 HIIT 格斗课程",
        "heroMeta": "Alex 教练 · 大师系列",
        "heroDuration": "40 分钟",
        "heroCalories": "550 千卡"
    })

    // -- device connectivity seeds (device_page.gd status blocks) --
    // Godot defaults: CAN defaults to online, ROS2 offline until health check,
    // WebSocket shows client count. volume/brightness are static seeds for the
    // port (Godot reads volume from the local API; brightness has no Godot twin).
    readonly property var deviceStatus: ({
        "ros2Online": false,
        "canOnline": true,
        "websocketClients": 0,
        "volume": 1.0,
        "muted": false,
        "brightness": 0.8
    })

    // -- sparring / training-data seeds --
    // Godot shows an empty state (all zeros) until the API answers; the static
    // port ships representative seeds so the data tab renders offline.
    readonly property var sparringSummary: ({
        "metricCards": [
            { "title": "连续打卡", "value": "6 天",     "color": "#00FF78", "tone": "green"  },
            { "title": "累计训练", "value": "42 次",    "color": "#00F0FF", "tone": "cyan"   },
            { "title": "今日出拳", "value": "860 次",   "color": "#FFE600", "tone": "yellow" },
            { "title": "历史总计", "value": "12450 次", "color": "#FF003C", "tone": "red"    }
        ],
        "todayKcal": 334,
        "todayMinutes": 28,
        "todayHits": 860,
        "todayText": "334 千卡 / 28 分钟",
        "todaySub": "860 次出拳 · 28 分钟",
        "trendValues": [520, 760, 430, 890, 640, 980, 860],
        "trendDates": ["07-15", "07-16", "07-17", "07-18", "07-19", "07-20", "07-21"],
        "recentRecords": [
            { "date": "07-21 19:42", "difficulty": "专业模式", "course": "实战模拟训练", "hits": 860, "maxStreak": 64, "maxPower": 412, "source": "Godot 运行端" },
            { "date": "07-20 20:15", "difficulty": "入门",     "course": "正式训练记录", "hits": 540, "maxStreak": 38, "maxPower": 305, "source": "训练来源" },
            { "date": "07-19 18:57", "difficulty": "冠军",     "course": "AI 对战",     "hits": 980, "maxStreak": 71, "maxPower": 468, "source": "Godot 运行端" }
        ]
    })

    // -- game card covers: card id -> qrc path ("" when the card has no cover) --
    readonly property var _coverFiles: ({
        "agility_challenge": "agility_challenge",
        "ai_battle": "ai_battle",
        "choreographer": "choreographer",
        "combat": "combat",
        "fitness_games": "fitness_games",
        "fruit_slice": "fruit_slice",
        "interstellar_bounce": "interstellar_bounce",
        "music_boxing": "music_boxing",
        "music_lights": "music_lights",
        "music_settings": "music_settings",
        "performance_jam": "performance_jam",
        "piano_tiles": "piano_tiles",
        "rhythm": "rhythm",
        "robot_rhythm": "robot_rhythm",
        "tracking_challenge": "tracking_challenge",
        "visual_config": "visual_config"
    })

    function coverFor(cardId) {
        const file = _coverFiles[cardId];
        if (file === undefined)
            return "";
        return "qrc:/resources/images/game_cards/" + file + ".png";
    }
}
