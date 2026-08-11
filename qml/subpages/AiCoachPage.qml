pragma ComponentBehavior: Bound
import QtQuick
import QxznHmi

// AI 智能教练子页。
// Godot 源：scripts/pages/ai_coach_page.gd + scripts/ai_coach_model.gd。
// 对话为 ai_coach_model.gd 的静态回放：点快捷回复 chip 追加下一段脚本问答，
// 阶段 body_status -> injury_check -> goal -> intensity -> recommendations。
// 头部 Rect2(56,134,1168,60)，消息区 (56,206,1168,386)，快捷回复条 (56,600,1168,74)，
// 推荐浮层 sheet 1000x440 居中 —— 均 1280 基准。
// 页面局部坐标 = Godot 屏幕坐标 - (48,150)。
Item {
    id: page

    // ---- 对话模型状态（ai_coach_model.gd）----
    property string stage: "body_status"
    property var intake: ({})
    property var messages: [
        { "role": "assistant", "text": "你好，我是小星教练。我们先做 30 秒训练前筛查，再给你推荐合适的拳击或健身入口。今天身体状态怎么样？" }
    ]
    property bool showRecommendations: false
    property var recommendationCards: []

    // 推荐卡数据（ai_coach_model.gd build_recommendations 的 5 张候选卡）
    readonly property var allRecommendationCards: [
        { "id": "basics",      "title": "基础拳击学习",   "description": "从拳架、步伐和基础出拳开始，适合热身、动作修正和低风险练习。",   "path": "/basic-actions",    "intensity": "低强度",   "duration": "8-12 分钟",  "suitableFor": "入门、恢复、动作质量", "note": "动作慢一点也没关系", "tone": "calm"    },
        { "id": "combat",      "title": "战斗力评估",     "description": "进入速度、反应或力量测试，用短时间数据了解今天的竞技状态。",     "path": "/combat",           "intensity": "中高强度", "duration": "10-15 分钟", "suitableFor": "状态正常、想挑战",   "note": "疼痛或疲劳时跳过",   "tone": "energy"  },
        { "id": "musicBoxing", "title": "音乐拳击",       "description": "跟随节奏完成拳击训练，强度更容易控制，也适合燃脂和反应练习。",   "path": "/music-boxing",     "intensity": "中等强度", "duration": "10-20 分钟", "suitableFor": "燃脂、节奏、反应",   "note": "选择舒适节奏",       "tone": "focus"   },
        { "id": "fitness",     "title": "健身游戏",       "description": "用轻竞技小游戏提升专注、协调和心肺参与感。",                     "path": "/fitness-games",    "intensity": "中等强度", "duration": "8-15 分钟",  "suitableFor": "燃脂、趣味训练",     "note": "注意动作幅度",       "tone": "energy"  },
        { "id": "knowledge",   "title": "拳击知识与恢复", "description": "查看动作要点、训练方法和恢复建议，适合不舒服或需要先学习的时段。", "path": "/boxing-knowledge", "intensity": "恢复建议", "duration": "3-8 分钟",   "suitableFor": "疲劳、疼痛、学习",   "note": "不替代医疗建议",     "tone": "warning" }
    ]

    function stageLabel(s) {
        if (s === "greeting") return "准备筛查";
        if (s === "body_status") return "确认状态";
        if (s === "injury_check") return "确认伤病";
        if (s === "goal") return "选择目标";
        if (s === "intensity") return "选择强度";
        if (s === "recommendations") return "推荐训练";
        return "";
    }

    function bodyStatusLabel(s) {
        if (s === "normal") return "状态正常";
        if (s === "tired") return "有点疲劳";
        if (s === "pain") return "存在不适";
        return "";
    }

    function injuryLabel(s) {
        if (s === "none") return "无伤病";
        if (s === "shoulder_elbow_wrist") return "肩肘腕不适";
        if (s === "knee_ankle") return "膝踝不适";
        if (s === "back") return "腰背不适";
        if (s === "other") return "其它不适";
        return "";
    }

    function goalLabel(s) {
        if (s === "warmup") return "热身恢复";
        if (s === "fat_loss") return "燃脂训练";
        if (s === "reaction") return "反应速度";
        if (s === "power") return "力量爆发";
        if (s === "boxing_basics") return "基础拳击";
        return "";
    }

    function intensityLabel(s) {
        if (s === "light") return "轻量";
        if (s === "medium") return "中等";
        if (s === "high") return "高强度";
        return "";
    }

    function isPainOrTired(src) {
        if (src.bodyStatus === "tired" || src.bodyStatus === "pain")
            return true;
        var injury = src.injuryArea !== undefined ? src.injuryArea : "";
        return injury !== "" && injury !== "none";
    }

    function findMissingStage(src) {
        if (src.bodyStatus === undefined) return "body_status";
        if (src.injuryArea === undefined) return "injury_check";
        if (src.goal === undefined) return "goal";
        if (src.intensity === undefined) return "intensity";
        return "recommendations";
    }

    function missingPrompt(target) {
        if (target === "body_status") return "还差一步：先告诉我今天身体状态怎么样。";
        if (target === "injury_check") return "还需要确认有没有伤病或疼痛，这会影响训练强度。";
        if (target === "goal") return "身体状态记录好了，接下来选择今天的训练目标。";
        if (target === "intensity") return "最后选一下训练强度，我就能给你推荐入口。";
        return "筛查已完成，可以查看推荐入口。";
    }

    function describeIntake(src) {
        return bodyStatusLabel(src.bodyStatus) + "、" + injuryLabel(src.injuryArea)
                + "、目标 " + goalLabel(src.goal) + "、" + intensityLabel(src.intensity);
    }

    // ai_coach_model.gd quick_replies_for_stage
    function quickReplies() {
        if (stage === "body_status")
            return [
                { "label": "状态正常", "payload": { "bodyStatus": "normal" } },
                { "label": "有点疲劳", "payload": { "bodyStatus": "tired" } },
                { "label": "肩肘腕疼", "payload": { "bodyStatus": "pain", "injuryArea": "shoulder_elbow_wrist" } },
                { "label": "膝踝疼",   "payload": { "bodyStatus": "pain", "injuryArea": "knee_ankle" } },
                { "label": "腰背不适", "payload": { "bodyStatus": "pain", "injuryArea": "back" } }
            ];
        if (stage === "injury_check")
            return [
                { "label": "无伤病", "payload": { "injuryArea": "none" } },
                { "label": "肩肘腕", "payload": { "bodyStatus": "pain", "injuryArea": "shoulder_elbow_wrist" } },
                { "label": "膝踝",   "payload": { "bodyStatus": "pain", "injuryArea": "knee_ankle" } },
                { "label": "腰背",   "payload": { "bodyStatus": "pain", "injuryArea": "back" } }
            ];
        if (stage === "goal")
            return [
                { "label": "热身恢复", "payload": { "goal": "warmup" } },
                { "label": "燃脂",     "payload": { "goal": "fat_loss" } },
                { "label": "反应",     "payload": { "goal": "reaction" } },
                { "label": "力量",     "payload": { "goal": "power" } },
                { "label": "基础拳击", "payload": { "goal": "boxing_basics" } }
            ];
        if (stage === "intensity") {
            var replies = [
                { "label": "轻量",     "payload": { "intensity": "light" } },
                { "label": "中等强度", "payload": { "intensity": "medium" } }
            ];
            if (!isPainOrTired(intake))
                replies.push({ "label": "高强度", "payload": { "intensity": "high" } });
            return replies;
        }
        return [
            { "label": "查看推荐", "intent": "recommend" },
            { "label": "重新评估", "intent": "reset" }
        ];
    }

    function resetChat(introText) {
        stage = "body_status";
        intake = ({});
        messages = [{ "role": "assistant", "text": introText }];
        showRecommendations = false;
        recommendationCards = [];
    }

    function appendMessage(role, text) {
        messages = messages.concat([{ "role": role, "text": text }]);
        Qt.callLater(scrollMessagesToBottom);
    }

    function scrollMessagesToBottom() {
        msgView.contentY = Math.max(0, msgView.contentHeight - msgView.height);
    }

    // ai_coach_model.gd process_reply
    function processReply(reply) {
        var intent = reply.intent !== undefined ? reply.intent : "";
        if (intent === "reset") {
            resetChat("好的，我们重新评估一次。今天身体状态怎么样？");
            return;
        }
        if (intent === "recommend") {
            var missingNow = findMissingStage(intake);
            if (missingNow === "recommendations") {
                stage = "recommendations";
                recommendationCards = buildRecommendations(intake);
                showRecommendations = true;
            } else {
                stage = missingNow;
                appendMessage("assistant", missingPrompt(missingNow));
            }
            return;
        }
        appendMessage("user", reply.label !== undefined ? reply.label : "");
        var next = ({});
        for (var k in intake)
            next[k] = intake[k];
        var payload = reply.payload !== undefined ? reply.payload : ({});
        for (var p in payload)
            next[p] = payload[p];
        intake = next;
        var missingStage = findMissingStage(next);
        if (missingStage === "body_status") {
            stage = "body_status";
            appendMessage("assistant", "我先确认一下身体状态：今天整体感觉正常、疲劳，还是已经有某个部位不舒服？");
        } else if (missingStage === "injury_check") {
            var tiredNote = next.bodyStatus === "tired" ? "今天我们会把强度控制得更稳一点" : "身体状态已记录";
            stage = "injury_check";
            appendMessage("assistant", "收到，" + tiredNote + "。现在确认一下：有没有肩、肘、腕、膝、踝、腰背这些部位的疼痛或旧伤？");
        } else if (missingStage === "goal") {
            var caution = isPainOrTired(next) ? "我会避开高强度击打建议。" : "接下来按目标匹配训练入口。";
            stage = "goal";
            appendMessage("assistant", "好的，伤病状态已记录。" + caution + " 今天主要想练哪一类？");
        } else if (missingStage === "intensity") {
            stage = "intensity";
            appendMessage("assistant", "目标是" + goalLabel(next.goal) + "。最后确认强度：今天想轻量活动、中等训练，还是挑战高强度？");
        } else {
            stage = "recommendations";
            appendMessage("assistant", "筛查完成：" + describeIntake(next) + "。我给你准备了几个入口，点击卡片就能进入现有训练页面。");
            recommendationCards = buildRecommendations(next);
            showRecommendations = true;
        }
    }

    // ai_coach_model.gd build_recommendations
    function cardById(cards, cardId) {
        for (var i = 0; i < cards.length; i++)
            if (cards[i].id === cardId)
                return cards[i];
        return cards[0];
    }

    function buildRecommendations(src) {
        var cards = allRecommendationCards;
        if (isPainOrTired(src))
            return [cardById(cards, "knowledge"), cardById(cards, "basics"), cardById(cards, "musicBoxing")];
        var byGoal = ({
            "warmup":        ["basics", "musicBoxing", "knowledge"],
            "fat_loss":      ["musicBoxing", "fitness", "basics"],
            "reaction":      ["combat", "musicBoxing", "basics"],
            "power":         ["combat", "basics", "musicBoxing"],
            "boxing_basics": ["basics", "musicBoxing", "knowledge"]
        });
        var goal = src.goal !== undefined ? src.goal : "boxing_basics";
        var ids = byGoal[goal] !== undefined ? byGoal[goal] : ["basics", "musicBoxing", "fitness"];
        var selected = [];
        for (var i = 0; i < ids.length; i++) {
            var c = cardById(cards, ids[i]);
            if (selected.indexOf(c) < 0)
                selected.push(c);
        }
        if (src.intensity === "light") {
            var filtered = [];
            for (var j = 0; j < selected.length; j++)
                if (selected[j].id !== "combat")
                    filtered.push(selected[j]);
            var knowledge = cardById(cards, "knowledge");
            if (filtered.indexOf(knowledge) < 0)
                filtered.push(knowledge);
            return filtered.slice(0, 3);
        }
        return selected.slice(0, 3);
    }

    // ai_coach_page.gd _recommendation_action；已移植页直接跳转，其余提示未移植
    function recommendationAction(card) {
        showRecommendations = false;
        var path = card.path !== undefined ? card.path : "";
        if (path === "/combat") {
            AppState.selectNav("combat");
            return;
        }
        if (path === "/fitness-games") {
            AppState.openSubPage("fitness");
            return;
        }
        if (path === "/boxing-knowledge") {
            AppState.openSubPage("boxing_knowledge");
            return;
        }
        AppState.showCallout("info", "未移植", card.title + "将在后续阶段移植");
    }

    // 推荐卡 tone -> 颜色（ai_coach_page.gd _draw_recommendation_card）
    function toneColor(tone) {
        if (tone === "calm") return Theme.success;
        if (tone === "energy") return Theme.warn;
        if (tone === "warning") return Theme.danger;
        return Theme.primary;
    }

    function toneRgba(tone, a) {
        if (tone === "calm") return Qt.rgba(0, 1, 0.471, a);
        if (tone === "energy") return Qt.rgba(1, 0.902, 0, a);
        if (tone === "warning") return Qt.rgba(1, 0, 0.235, a);
        return Qt.rgba(0, 0.941, 1, a);
    }

    // ---- 聊天气泡（_draw_messages）----
    // 常量 @1280：气泡最大宽 680，pad 20/12，头像 36，头像间距 12，消息间距 14，font 16
    component ChatBubble: Item {
        id: bubble
        required property var msg
        readonly property bool isAssistant: msg.role === "assistant"
        height: bubbleBody.height

        TextMetrics {
            id: metrics
            text: bubble.msg.text
            font.pixelSize: Theme.fontPx(16)
            font.family: Theme.bodyFamily
        }

        // AI 头像：圆心 (消息区 x + 22, 气泡顶 + 18)@1280，r 18，cyan alpha 0.22 + 描边
        Rectangle {
            visible: bubble.isAssistant
            x: Theme.px(22) - Theme.px(18)
            y: 0
            width: Theme.px(36)
            height: Theme.px(36)
            radius: Theme.px(18)
            color: Qt.rgba(0, 0.941, 1, 0.22)
            border.color: Theme.primary
            border.width: 2    // Godot 弧线宽 1.6@1280
            Text {
                anchors.centerIn: parent
                text: "AI"
                color: Theme.primary
                font.pixelSize: Theme.fontPx(12)
            }
        }

        Rectangle {
            id: bubbleBody
            x: bubble.isAssistant ? Theme.px(52) : bubble.width - width - Theme.px(52)
            y: 0
            // Godot bubble_w = min(680, 文本宽 + 20*2 + 12)@1280
            width: Math.min(Theme.px(680), Math.ceil(metrics.advanceWidth) + Theme.px(20) * 2 + Theme.px(12))
            height: contentText.paintedHeight + Theme.px(12) * 2
            radius: Theme.px(16)
            color: bubble.isAssistant ? Qt.rgba(0.067, 0.067, 0.067, 0.72) : Qt.rgba(0, 0.941, 1, 0.18)
            border.color: bubble.isAssistant ? Qt.rgba(0, 0.941, 1, 0.12) : Qt.rgba(0, 0.941, 1, 0.28)
            border.width: 2    // Godot 1.0@1280

            Text {
                id: contentText
                x: Theme.px(20)
                y: Theme.px(12)
                width: bubbleBody.width - Theme.px(20) * 2
                text: bubble.msg.text
                color: Theme.text
                font.pixelSize: Theme.fontPx(16)
                wrapMode: Text.Wrap
                lineHeight: Theme.px(22)    // Godot 行高 22@1280
                lineHeightMode: Text.FixedHeight
            }
        }

        // 用户头像：圆心 (气泡右 + 12 + 18 + 4, 气泡顶 + 18)@1280，muted alpha 0.18
        Rectangle {
            visible: !bubble.isAssistant
            x: bubbleBody.x + bubbleBody.width + Theme.px(12) + Theme.px(4)
            y: 0
            width: Theme.px(36)
            height: Theme.px(36)
            radius: Theme.px(18)
            color: Qt.rgba(0.420, 0.482, 0.612, 0.18)
            Text {
                anchors.centerIn: parent
                text: "你"
                color: Theme.muted
                font.pixelSize: Theme.fontPx(12)
            }
        }
    }

    // ---- 推荐卡（_draw_recommendation_card）----
    component RecommendCard: Item {
        id: recCard
        required property var cardData
        readonly property string tone: cardData.tone !== undefined ? cardData.tone : "focus"

        HmiCard {
            anchors.fill: parent
            radius: Theme.px(20)
            fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.68)
        }
        // 顶部 tone 线：(20,2)->(w-20,2) alpha 0.14 @1280
        Rectangle {
            x: Theme.px(20)
            y: Theme.px(2)
            width: recCard.width - Theme.px(20) * 2
            height: 1
            color: page.toneRgba(recCard.tone, 0.14)
        }
        // "强度 · 时长"：baseline 相对 (18,18)@1280，font 12
        Text {
            x: Theme.px(18)
            y: Theme.px(18) - Math.round(Theme.fontPx(12) * 0.78)
            width: recCard.width - Theme.px(36)
            text: (recCard.cardData.intensity !== undefined ? recCard.cardData.intensity : "")
                  + "  ·  " + (recCard.cardData.duration !== undefined ? recCard.cardData.duration : "")
            color: page.toneColor(recCard.tone)
            font.pixelSize: Theme.fontPx(12)
            elide: Text.ElideRight
        }
        // 标题：baseline 相对 (18,42)@1280，font 18
        Text {
            x: Theme.px(18)
            y: Theme.px(42) - Math.round(Theme.fontPx(18) * 0.78)
            width: recCard.width - Theme.px(36)
            text: recCard.cardData.title !== undefined ? recCard.cardData.title : ""
            color: Theme.text
            font.pixelSize: Theme.fontPx(18)
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontPx(13)
        }
        // 描述：相对 (18,70) 高 80@1280，font 13，最多 4 行
        Text {
            x: Theme.px(18)
            y: Theme.px(70)
            width: recCard.width - Theme.px(36)
            height: Theme.px(80)
            text: recCard.cardData.description !== undefined ? recCard.cardData.description : ""
            color: Theme.muted
            font.pixelSize: Theme.fontPx(13)
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }
        // 分隔线 y=154@1280
        Rectangle {
            x: Theme.px(18)
            y: Theme.px(154)
            width: recCard.width - Theme.px(18) * 2
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }
        // 适合：baseline 166@1280，font 11
        Text {
            x: Theme.px(18)
            y: Theme.px(166) - Math.round(Theme.fontPx(11) * 0.78)
            width: recCard.width - Theme.px(36)
            text: "适合：" + (recCard.cardData.suitableFor !== undefined ? recCard.cardData.suitableFor : "")
            color: Theme.muted
            font.pixelSize: Theme.fontPx(11)
            elide: Text.ElideRight
        }
        // 注意：baseline 184@1280，font 11，mutedSoft
        Text {
            x: Theme.px(18)
            y: Theme.px(184) - Math.round(Theme.fontPx(11) * 0.78)
            width: recCard.width - Theme.px(36)
            text: "注意：" + (recCard.cardData.note !== undefined ? recCard.cardData.note : "")
            color: Theme.mutedSoft
            font.pixelSize: Theme.fontPx(11)
            elide: Text.ElideRight
        }
        // 进入按钮：(w-96, h-44, 78, 32)@1280，radius 16，tone alpha 0.14
        Rectangle {
            x: recCard.width - Theme.px(96)
            y: recCard.height - Theme.px(44)
            width: Theme.px(78)
            height: Theme.px(32)
            radius: Theme.px(16)
            color: page.toneRgba(recCard.tone, 0.14)
            Text {
                anchors.centerIn: parent
                text: "进入"
                color: Theme.text
                font.pixelSize: Theme.fontPx(13)
            }
        }

        ClickFlash {
            id: recFlash
            radius: Theme.px(20)
            flashColor: page.toneColor(recCard.tone)
        }
        TapHandler {
            onTapped: {
                recFlash.flash();
                page.recommendationAction(recCard.cardData);
            }
        }
    }

    // ---- 头部：Rect2(56,134,1168,60)@1280 -> 局部 (36,51,1752,90) ----
    HmiCard {
        id: header
        x: Theme.px(56) - 48
        y: Theme.px(134) - 150
        width: Theme.px(1168)
        height: Theme.px(60)
        radius: Theme.px(24)
        fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.68)

        // 返回键：相对头部 (12,12,100,36)@1280，radius 16
        Rectangle {
            id: backButton
            x: Theme.px(12)
            y: Theme.px(12)
            width: Theme.px(100)
            height: Theme.px(36)
            radius: Theme.px(16)
            color: Qt.rgba(0, 0.941, 1, 0.12)
            border.color: Qt.rgba(0, 0.941, 1, 0.40)
            border.width: 2    // Godot 1.0@1280

            // "<" 折线：(20,18)->(32,11)、(20,18)->(32,25)@1280，线宽 2.2
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = "#F8FAFC";
                    ctx.lineWidth = 3.3;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.moveTo(30, 27);
                    ctx.lineTo(48, 16.5);
                    ctx.moveTo(30, 27);
                    ctx.lineTo(48, 37.5);
                    ctx.stroke();
                }
            }
            // "返回"：相对 (42,22)@1280 baseline，font 14
            Text {
                x: Theme.px(42)
                y: Theme.px(22) - Math.round(Theme.fontPx(14) * 0.78)
                text: "返回"
                color: Theme.text
                font.pixelSize: Theme.fontPx(14)
            }
            ClickFlash {
                id: backFlash
                radius: backButton.radius
                flashColor: Theme.cyan
            }
            TapHandler {
                onTapped: {
                    backFlash.flash();
                    AppState.back();
                }
            }
        }

        // 标题：相对头部 (128,18)@1280 baseline，font 22
        Text {
            x: Theme.px(128)
            y: Theme.px(18) - Math.round(Theme.fontPx(22) * 0.78)
            text: "AI 智能教练"
            color: Theme.text
            font.pixelSize: Theme.fontPx(22)
        }

        // 阶段 pill：相对头部 (w-150, 16, 130, 28)@1280，radius 14，primary alpha 0.14
        Rectangle {
            x: header.width - Theme.px(150)
            y: Theme.px(16)
            width: Theme.px(130)
            height: Theme.px(28)
            radius: Theme.px(14)
            color: Qt.rgba(0, 0.941, 1, 0.14)
            Text {
                anchors.centerIn: parent
                text: page.stageLabel(page.stage)
                color: Theme.primary
                font.pixelSize: Theme.fontPx(12)
            }
        }
    }

    // ---- 消息区：(56,206,1168,386)@1280 -> 局部 (36,159,1752,579) ----
    Flickable {
        id: msgView
        x: Theme.px(56) - 48
        y: Theme.px(206) - 150
        width: Theme.px(1168)
        height: Theme.px(386)
        contentWidth: width
        contentHeight: msgColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: msgColumn
            width: msgView.width
            spacing: Theme.px(14)    // MSG_GAP 14@1280
            Repeater {
                model: page.messages
                delegate: ChatBubble {
                    required property var modelData
                    msg: modelData
                    width: msgColumn.width
                }
            }
        }
    }

    // ---- 快捷回复条：(56,600,1168,74)@1280 -> 局部 (36,750,1752,111)，glass radius 18 ----
    HmiCard {
        id: replyBar
        x: Theme.px(56) - 48
        y: Theme.px(600) - 150
        width: Theme.px(1168)
        height: Theme.px(74)
        radius: Theme.px(18)
        fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.58)

        Row {
            id: chipRow
            // Godot：总宽超不出时居中，否则留 pad 20@1280
            x: Math.max(Theme.px(20), (replyBar.width - width) / 2)
            y: (replyBar.height - Theme.px(42)) / 2
            spacing: Theme.px(14)

            Repeater {
                model: page.quickReplies()
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property string intent: modelData.intent !== undefined ? modelData.intent : ""
                    readonly property string chipTone: intent === "reset" ? "muted" : (intent === "recommend" ? "success" : "primary")
                    // chip 宽 = 字数 * 14 + 36，高 42@1280
                    width: String(modelData.label).length * 21 + Theme.px(36)
                    height: Theme.px(42)
                    radius: height / 2
                    color: chip.chipTone === "muted" ? Qt.rgba(0.420, 0.482, 0.612, 0.16)
                         : chip.chipTone === "success" ? Qt.rgba(0, 1, 0.471, 0.16)
                         : Qt.rgba(0, 0.941, 1, 0.16)
                    border.color: chip.chipTone === "muted" ? Qt.rgba(0.420, 0.482, 0.612, 0.22)
                                : chip.chipTone === "success" ? Qt.rgba(0, 1, 0.471, 0.22)
                                : Qt.rgba(0, 0.941, 1, 0.22)
                    border.width: 2    // Godot 1.0@1280
                    Text {
                        anchors.centerIn: parent
                        text: chip.modelData.label
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(14)
                    }
                    ClickFlash {
                        id: chipFlash
                        radius: chip.radius
                        flashColor: chip.chipTone === "muted" ? Theme.muted
                                  : chip.chipTone === "success" ? Theme.success : Theme.primary
                    }
                    TapHandler {
                        onTapped: {
                            chipFlash.flash();
                            page.processReply(chip.modelData);
                        }
                    }
                }
            }
        }
    }

    // ---- 推荐浮层（_draw_recommendations_overlay）----
    // Godot 盖全屏；Qt 页面受页面容器裁剪，盖页面区。sheet 1000x440@1280 居中。
    Item {
        id: recommendOverlay
        anchors.fill: parent
        visible: page.showRecommendations

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.64)
        }
        TapHandler {}    // 阻断下层点击

        HmiCard {
            id: sheet
            x: (recommendOverlay.width - width) / 2
            y: (recommendOverlay.height - height) / 2
            width: Theme.px(1000)
            height: Theme.px(440)
            radius: Theme.px(28)
            fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.94)

            Text {
                x: Theme.px(32)
                y: Theme.px(28) - Math.round(Theme.fontPx(11) * 0.78)
                text: "RECOMMENDATIONS"
                color: Theme.muted
                font.pixelSize: Theme.fontPx(11)
            }
            Text {
                x: Theme.px(32)
                y: Theme.px(48) - Math.round(Theme.fontPx(24) * 0.78)
                text: "适合现在的训练入口"
                color: Theme.text
                font.pixelSize: Theme.fontPx(24)
            }

            // 关闭钮：(sheet.w-60, 16, 42, 42)@1280，danger alpha 0.08
            Rectangle {
                id: closeButton
                x: sheet.width - Theme.px(60)
                y: Theme.px(16)
                width: Theme.px(42)
                height: Theme.px(42)
                radius: Theme.px(21)
                color: Qt.rgba(1, 0, 0.235, 0.08)
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = "#6B7B9C";
                        ctx.lineWidth = 3.3;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.moveTo(21, 21);    // (14,14)@1280 x1.5
                        ctx.lineTo(42, 42);    // (28,28)@1280 x1.5
                        ctx.moveTo(42, 21);
                        ctx.lineTo(21, 42);
                        ctx.stroke();
                    }
                }
                ClickFlash {
                    id: closeFlash
                    radius: closeButton.radius
                }
                TapHandler {
                    onTapped: {
                        closeFlash.flash();
                        page.showRecommendations = false;
                    }
                }
            }

            // 推荐卡行：y 90@1280，卡高 300@1280，间距 16@1280，左右边距 28@1280
            Repeater {
                model: page.recommendationCards
                delegate: RecommendCard {
                    required property int index
                    required property var modelData
                    cardData: modelData
                    x: Theme.px(28) + index * (width + Theme.px(16))
                    y: Theme.px(90)
                    width: (sheet.width - Theme.px(28) * 2 - Theme.px(16) * 2) / 3
                    height: Theme.px(300)
                }
            }

            Text {
                x: Theme.px(32)
                y: sheet.height - Theme.px(28) - Math.round(Theme.fontPx(13) * 0.78)
                text: "点击卡片进入对应训练页面  ·  点击 ✕ 关闭"
                color: Theme.muted
                font.pixelSize: Theme.fontPx(13)
            }
        }
    }
}
