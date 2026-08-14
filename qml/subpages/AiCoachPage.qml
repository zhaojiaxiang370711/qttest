pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QxznHmi

// AI 智能教练子页。
// Godot 源：scripts/pages/ai_coach_page.gd + scripts/ai_coach_model.gd。
// 对话保留本地筛查状态机作为安全兜底，并通过 C++ HTTPS 客户端请求云端
// AI 文案增强。服务不可用、未配置设备令牌或超时时继续显示本地建议。
// 头部与消息区沿用 1280 基准；底部区域合并快捷回复和自由文本输入。
// 推荐浮层 sheet 1000x440 居中 —— 均 1280 基准。
// 页面局部坐标 = Godot 屏幕坐标 - (48,150)。
Item {
    id: page

    // ---- 对话模型状态（ai_coach_model.gd）----
    property string stage: "body_status"
    property var intake: ({})
    property var messages: [
        { "role": "assistant", "text": "你好，我是小星教练。我们先做 30 秒训练前筛查，再给你推荐合适的拳击或健身入口。今天身体状态怎么样？", "timestamp": Date.now() }
    ]
    property bool showRecommendations: false
    property var recommendationCards: []
    property string textInput: ""
    property bool isAssistantThinking: false
    property string pendingRequestId: ""
    property string pendingLocalReply: ""
    property int requestGeneration: 0

    readonly property bool intakeComplete: findMissingStage(intake) === "recommendations"
    readonly property bool hasPainOrFatigue: isPainOrTired(intake)
    readonly property int completionPercent: {
        var completed = 0;
        if (intake.bodyStatus !== undefined) completed += 1;
        if (intake.injuryArea !== undefined) completed += 1;
        if (intake.goal !== undefined) completed += 1;
        if (intake.intensity !== undefined) completed += 1;
        return completed * 25;
    }

    // 推荐卡数据（ai_coach_model.gd build_recommendations 的 5 张候选卡）
    readonly property var allRecommendationCards: [
        { "id": "basics",      "title": "基础拳击学习",   "description": "从拳架、步伐和基础出拳开始，适合热身、动作修正和低风险练习。",   "path": "/basic-actions-learning", "intensity": "低强度",   "duration": "8-12 分钟",  "suitableFor": "入门、恢复、动作质量", "note": "动作慢一点也没关系", "tone": "calm"    },
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

    function summaryItems() {
        return [
            { "label": "身体状态", "value": intake.bodyStatus !== undefined ? bodyStatusLabel(intake.bodyStatus) : "待确认", "pending": intake.bodyStatus === undefined },
            { "label": "伤病疼痛", "value": intake.injuryArea !== undefined ? injuryLabel(intake.injuryArea) : "待确认", "pending": intake.injuryArea === undefined },
            { "label": "训练目标", "value": intake.goal !== undefined ? goalLabel(intake.goal) : "待确认", "pending": intake.goal === undefined },
            { "label": "训练强度", "value": intake.intensity !== undefined ? intensityLabel(intake.intensity) : "待确认", "pending": intake.intensity === undefined }
        ];
    }

    function safetyNote() {
        var injury = intake.injuryArea !== undefined ? intake.injuryArea : "";
        if (injury !== "" && injury !== "none")
            return "建议先避开疼痛部位和高强度击打，训练中一旦疼痛加重就立刻停止。";
        if (intake.bodyStatus === "tired")
            return "今天适合把强度降一档，优先热身、动作质量和节奏感。";
        return "训练前先完成热身，击打时保持呼吸稳定和动作控制。";
    }

    function formatMessageTime(timestamp) {
        return Qt.formatDateTime(new Date(timestamp), "HH:mm");
    }

    // ai_coach_model.gd quick_replies_for_stage
    function quickReplies() {
        if (stage === "body_status")
            return [
                { "label": "状态正常", "userText": "状态正常", "payload": { "bodyStatus": "normal" } },
                { "label": "有点疲劳", "userText": "今天有点疲劳", "payload": { "bodyStatus": "tired" } },
                { "label": "肩肘腕疼", "userText": "肩肘腕有点疼", "payload": { "bodyStatus": "pain", "injuryArea": "shoulder_elbow_wrist" } },
                { "label": "膝踝疼",   "userText": "膝盖或脚踝有点疼", "payload": { "bodyStatus": "pain", "injuryArea": "knee_ankle" } },
                { "label": "腰背不适", "userText": "腰背不太舒服", "payload": { "bodyStatus": "pain", "injuryArea": "back" } }
            ];
        if (stage === "injury_check")
            return [
                { "label": "无伤病", "userText": "没有伤病疼痛", "payload": { "injuryArea": "none" } },
                { "label": "肩肘腕", "userText": "肩肘腕不适", "payload": { "bodyStatus": "pain", "injuryArea": "shoulder_elbow_wrist" } },
                { "label": "膝踝",   "userText": "膝盖或脚踝不适", "payload": { "bodyStatus": "pain", "injuryArea": "knee_ankle" } },
                { "label": "腰背",   "userText": "腰背不适", "payload": { "bodyStatus": "pain", "injuryArea": "back" } }
            ];
        if (stage === "goal")
            return [
                { "label": "热身恢复", "userText": "我想热身恢复", "payload": { "goal": "warmup" } },
                { "label": "燃脂",     "userText": "我想燃脂训练", "payload": { "goal": "fat_loss" } },
                { "label": "反应",     "userText": "我想练反应速度", "payload": { "goal": "reaction" } },
                { "label": "力量",     "userText": "我想练力量爆发", "payload": { "goal": "power" } },
                { "label": "基础拳击", "userText": "我想练基础拳击", "payload": { "goal": "boxing_basics" } }
            ];
        if (stage === "intensity") {
            var replies = [
                { "label": "轻量",     "userText": "轻量强度", "payload": { "intensity": "light" } },
                { "label": "中等强度", "userText": "中等强度", "payload": { "intensity": "medium" } }
            ];
            if (!isPainOrTired(intake))
                replies.push({ "label": "高强度", "userText": "高强度挑战", "payload": { "intensity": "high" } });
            return replies;
        }
        return [
            { "label": "查看推荐", "intent": "recommend" },
            { "label": "重新评估", "intent": "reset" }
        ];
    }

    function resetChat(introText) {
        requestGeneration += 1;
        aiTimeoutTimer.stop();
        AiAssistantClient.cancelAll();
        stage = "body_status";
        intake = ({});
        messages = [{ "role": "assistant", "text": introText, "timestamp": Date.now() }];
        showRecommendations = false;
        recommendationCards = [];
        textInput = "";
        isAssistantThinking = false;
        pendingRequestId = "";
        pendingLocalReply = "";
        Qt.callLater(scrollMessagesToBottom);
    }

    function appendMessage(role, text) {
        messages = messages.concat([{ "role": role, "text": text, "timestamp": Date.now() }]);
        Qt.callLater(scrollMessagesToBottom);
    }

    function scrollMessagesToBottom() {
        msgView.contentY = Math.max(0, msgView.contentHeight - msgView.height);
    }

    function copyIntake(src) {
        var result = ({});
        for (var key in src)
            result[key] = src[key];
        return result;
    }

    function normalized(text) {
        return String(text).toLowerCase().replace(/\s+/g, "");
    }

    function inferIntakePatch(text) {
        var value = normalized(text);
        var patch = ({});
        if (/(正常|没事|還好|还好|可以|不错|很好|无不适)/.test(value)) patch.bodyStatus = "normal";
        if (/(累|疲劳|疲憊|疲惫|困|睡眠|没精神|乏|状态差)/.test(value)) patch.bodyStatus = "tired";
        if (/(肩|肘|腕|手腕|手臂|胳膊)/.test(value)) { patch.bodyStatus = "pain"; patch.injuryArea = "shoulder_elbow_wrist"; }
        if (/(膝|踝|脚踝|腿|小腿|大腿)/.test(value)) { patch.bodyStatus = "pain"; patch.injuryArea = "knee_ankle"; }
        if (/(腰|背|脊柱)/.test(value)) { patch.bodyStatus = "pain"; patch.injuryArea = "back"; }
        if (/(没有伤|无伤|没伤|没有疼|不疼|无疼痛|没有不适)/.test(value)) patch.injuryArea = "none";
        if (/(热身|恢复|放松|拉伸|活动开)/.test(value)) patch.goal = "warmup";
        if (/(燃脂|减脂|出汗|有氧|卡路里|瘦)/.test(value)) patch.goal = "fat_loss";
        if (/(反应|速度|敏捷|快一点|快速)/.test(value)) patch.goal = "reaction";
        if (/(力量|爆发|重拳|发力|power)/.test(value)) patch.goal = "power";
        if (/(基础|入门|动作|拳架|步伐|拳击基础)/.test(value)) patch.goal = "boxing_basics";
        if (/(轻|低强度|保守|简单|慢一点|恢复)/.test(value)) patch.intensity = "light";
        if (/(中等|适中|正常强度|普通)/.test(value)) patch.intensity = "medium";
        if (/(高强度|挑战|全力|强一点|hard|猛)/.test(value)) patch.intensity = "high";
        return patch;
    }

    function hasStopSignal(text) {
        return /(胸痛|胸闷|头晕|眩晕|呼吸困难|急性疼|剧烈疼|拉伤|扭伤)/.test(normalized(text));
    }

    function isResetIntent(text) {
        return /(重新评估|重来|重新开始|清空|reset)/.test(normalized(text));
    }

    function isRecommendationIntent(text) {
        return /(推荐|开始训练|我想练|训练入口|给我安排|进入训练)/.test(normalized(text));
    }

    function mergePatch(base, inferred, forced) {
        var result = copyIntake(base);
        var key;
        for (key in inferred) result[key] = inferred[key];
        for (key in forced) result[key] = forced[key];
        return result;
    }

    function localReplyFor(text, next) {
        if (hasStopSignal(text)) {
            if (next.bodyStatus === undefined) next.bodyStatus = "pain";
            if (next.injuryArea === undefined) next.injuryArea = "other";
            if (next.goal === undefined) next.goal = "warmup";
            next.intensity = "light";
            return { "stage": "recommendations", "show": true,
                "text": "听起来今天不适合做强刺激训练。我建议先休息、补水，并查看恢复和基础动作内容；如果有胸闷、头晕或急性疼痛，请停止训练并寻求专业帮助。" };
        }
        if (isRecommendationIntent(text) && findMissingStage(next) === "recommendations")
            return { "stage": "recommendations", "show": true,
                "text": "收到。按你现在的状态：" + describeIntake(next) + "。我已经把适合的训练入口整理好了，优先从安全、可持续的选项开始。" };

        var missing = findMissingStage(next);
        if (missing === "body_status")
            return { "stage": missing, "text": "我先确认一下身体状态：今天整体感觉正常、疲劳，还是已经有某个部位不舒服？" };
        if (missing === "injury_check")
            return { "stage": missing, "text": "收到，" + (next.bodyStatus === "tired" ? "今天我们会把强度控制得更稳一点" : "身体状态已记录") + "。现在确认一下：有没有肩、肘、腕、膝、踝、腰背这些部位的疼痛或旧伤？" };
        if (missing === "goal")
            return { "stage": missing, "text": "好的，伤病状态已记录。" + (isPainOrTired(next) ? "我会避开高强度击打建议。" : "接下来按目标匹配训练入口。") + " 今天主要想练哪一类？" };
        if (missing === "intensity")
            return { "stage": missing, "text": "目标是" + goalLabel(next.goal) + "。最后确认强度：今天想轻量活动、中等训练，还是挑战高强度？" };
        return { "stage": "recommendations", "show": true,
            "text": "筛查完成：" + describeIntake(next) + "。我给你准备了几个入口，点击卡片就能进入现有训练页面。" };
    }

    function finishAssistant(text, generation) {
        if (generation !== requestGeneration || !isAssistantThinking)
            return;
        aiTimeoutTimer.stop();
        pendingRequestId = "";
        isAssistantThinking = false;
        appendMessage("assistant", text && String(text).trim().length > 0 ? String(text).trim() : pendingLocalReply);
        pendingLocalReply = "";
        if (stage === "recommendations") {
            recommendationCards = buildRecommendations(intake);
            showRecommendations = true;
        }
    }

    function requestAiReply(userText, localText, next) {
        isAssistantThinking = true;
        pendingLocalReply = localText;
        requestGeneration += 1;
        var generation = requestGeneration;
        pendingRequestId = "qt-" + Date.now() + "-" + generation;
        aiTimeoutTimer.restart();
        AiAssistantClient.requestReply(pendingRequestId, userText, localText, next);
    }

    function processUserInput(text, forcedPatch) {
        var cleanText = String(text).trim();
        if (cleanText.length === 0 || isAssistantThinking)
            return;
        if (isResetIntent(cleanText)) {
            resetChat("没问题，我们重新来一遍。今天身体状态怎么样？");
            return;
        }
        appendMessage("user", cleanText);
        var forced = forcedPatch !== undefined ? forcedPatch : ({});
        var next = mergePatch(intake, inferIntakePatch(cleanText), forced);
        var local = localReplyFor(cleanText, next);
        intake = next;
        stage = local.stage;
        textInput = "";
        requestAiReply(cleanText, local.text, next);
    }

    function sendFreeText() {
        processUserInput(textInput, ({}));
    }

    function openRecommendations() {
        var missingNow = findMissingStage(intake);
        if (missingNow !== "recommendations") {
            stage = missingNow;
            appendMessage("assistant", missingPrompt(missingNow));
            return;
        }
        stage = "recommendations";
        recommendationCards = buildRecommendations(intake);
        showRecommendations = true;
    }

    // ai_coach_model.gd process_reply
    function processReply(reply) {
        var intent = reply.intent !== undefined ? reply.intent : "";
        if (intent === "reset") {
            resetChat("好的，我们重新评估一次。今天身体状态怎么样？");
            return;
        }
        if (intent === "recommend") {
            openRecommendations();
            return;
        }
        processUserInput(reply.userText !== undefined ? reply.userText
                                                     : (reply.label !== undefined ? reply.label : ""),
                         reply.payload !== undefined ? reply.payload : ({}));
    }

    // ai_coach_model.gd build_recommendations
    function cardById(cards, cardId) {
        for (var i = 0; i < cards.length; i++)
            if (cards[i].id === cardId)
                return cards[i];
        return cards[0];
    }

    function contextualCard(card, src) {
        var result = ({});
        for (var key in card)
            result[key] = card[key];
        if (result.id === "musicBoxing" && isPainOrTired(src))
            result.intensity = "低到中强度";
        return result;
    }

    function buildRecommendations(src) {
        var cards = allRecommendationCards;
        if (isPainOrTired(src))
            return [contextualCard(cardById(cards, "knowledge"), src),
                    contextualCard(cardById(cards, "basics"), src),
                    contextualCard(cardById(cards, "musicBoxing"), src)];
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
            var alreadySelected = false;
            for (var selectedIndex = 0; selectedIndex < selected.length; ++selectedIndex)
                if (selected[selectedIndex].id === c.id) alreadySelected = true;
            if (!alreadySelected)
                selected.push(contextualCard(c, src));
        }
        if (src.intensity === "light") {
            var filtered = [];
            for (var j = 0; j < selected.length; j++)
                if (selected[j].id !== "combat")
                    filtered.push(selected[j]);
            var knowledge = contextualCard(cardById(cards, "knowledge"), src);
            var hasKnowledge = false;
            for (var k = 0; k < filtered.length; ++k)
                if (filtered[k].id === "knowledge") hasKnowledge = true;
            if (!hasKnowledge)
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
        if (path === "/basic-actions-learning") {
            AppState.openCourse("stance");
            return;
        }
        if (path === "/fitness-games") {
            AppState.openSubPage("fitness");
            return;
        }
        if (path === "/music-boxing") {
            for (var i = 0; i < ShellData.entertainmentCards.length; ++i) {
                if (ShellData.entertainmentCards[i].id === "music_boxing") {
                    AppState.selectNav("entertainment");
                    AppState.openSubGame(ShellData.entertainmentCards[i]);
                    return;
                }
            }
        }
        if (path === "/boxing-knowledge") {
            AppState.openSubPage("boxing_knowledge");
            return;
        }
        AppState.showCallout("info", "入口待移植", card.title + "暂未接入 Qt 运行时");
    }

    Timer {
        id: aiTimeoutTimer
        interval: 32000
        repeat: false
        onTriggered: {
            AiAssistantClient.cancelAll();
            page.finishAssistant(page.pendingLocalReply, page.requestGeneration);
        }
    }

    Connections {
        target: AiAssistantClient
        function onReplyReady(requestId, text) {
            if (requestId === page.pendingRequestId)
                page.finishAssistant(text, page.requestGeneration);
        }
        function onRequestFailed(requestId, message) {
            if (requestId === page.pendingRequestId)
                page.finishAssistant(page.pendingLocalReply, page.requestGeneration);
        }
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
        readonly property int metaHeight: Theme.px(20)
        height: bubbleBody.y + bubbleBody.height

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
            y: bubble.metaHeight
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
            y: bubble.metaHeight
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
            y: bubble.metaHeight
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

        Text {
            x: bubbleBody.x
            y: 0
            width: bubbleBody.width
            height: bubble.metaHeight
            text: (bubble.isAssistant ? "小星教练" : "你") + "  ·  "
                  + page.formatMessageTime(bubble.msg.timestamp !== undefined
                                           ? bubble.msg.timestamp : Date.now())
            color: Theme.muted
            font.pixelSize: Theme.fontPx(10)
            horizontalAlignment: bubble.isAssistant ? Text.AlignLeft : Text.AlignRight
            verticalAlignment: Text.AlignVCenter
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
            text: "训练前智能助手"
            color: Theme.text
            font.pixelSize: Theme.fontPx(22)
        }

        Rectangle {
            id: resetButton
            x: header.width - Theme.px(278)
            y: Theme.px(14)
            width: Theme.px(112)
            height: Theme.px(32)
            radius: Theme.px(14)
            color: Qt.rgba(0.420, 0.482, 0.612, 0.14)
            border.width: 1
            border.color: Qt.rgba(0.420, 0.482, 0.612, 0.28)
            Text {
                anchors.centerIn: parent
                text: "重新评估"
                color: Theme.text
                font.pixelSize: Theme.fontPx(12)
            }
            TapHandler {
                onTapped: page.resetChat("好的，我们重新评估一次。今天身体状态怎么样？")
            }
        }

        // 阶段 pill：相对头部 (w-150, 16, 130, 28)@1280，radius 14，primary alpha 0.14
        Rectangle {
            x: header.width - Theme.px(150)
            y: Theme.px(16)
            width: Theme.px(130)
            height: Theme.px(28)
            radius: Theme.px(14)
            color: Qt.rgba(0, 0.941, 1, 0.14)
            Rectangle {
                x: Theme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(7)
                height: width
                radius: width / 2
                color: Theme.success
            }
            Text {
                anchors.fill: parent
                text: page.stageLabel(page.stage)
                color: Theme.primary
                font.pixelSize: Theme.fontPx(12)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // ---- 消息区：(56,206,1168,386)@1280 -> 局部 (36,159,1752,579) ----
    Flickable {
        id: msgView
        x: Theme.px(56) - 48
        y: Theme.px(206) - 150
        width: Theme.px(836)
        height: Theme.px(314)
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
            Text {
                visible: page.isAssistantThinking
                height: visible ? Theme.px(34) : 0
                text: "小星教练正在思考…"
                color: Theme.primary
                font.pixelSize: Theme.fontPx(13)
                leftPadding: Theme.px(52)
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Combined quick replies + free-text composer, ported from the Web page.
    HmiCard {
        id: replyBar
        x: Theme.px(56) - 48
        y: Theme.px(536) - 150
        width: Theme.px(836)
        height: Theme.px(126)
        radius: Theme.px(18)
        fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.58)

        Row {
            id: chipRow
            // Godot：总宽超不出时居中，否则留 pad 20@1280
            x: Math.max(Theme.px(20), (replyBar.width - width) / 2)
            y: Theme.px(10)
            spacing: Theme.px(14)

            Repeater {
                model: page.isAssistantThinking ? [] : page.quickReplies()
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

        Rectangle {
            id: composer
            x: Theme.px(20)
            y: Theme.px(66)
            width: replyBar.width - Theme.px(40)
            height: Theme.px(46)
            radius: Theme.px(18)
            color: Qt.rgba(0, 0, 0, 0.26)
            border.width: 1
            border.color: input.activeFocus ? Theme.primary : Theme.cardBorder

            TextInput {
                id: input
                x: Theme.px(18)
                y: 0
                width: composer.width - Theme.px(84)
                height: composer.height
                text: page.textInput
                onTextChanged: page.textInput = text
                color: Theme.text
                selectionColor: Theme.primary
                selectedTextColor: Theme.windowBackground
                font.pixelSize: Theme.fontPx(15)
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                enabled: !page.isAssistantThinking
                onAccepted: page.sendFreeText()

                Text {
                    anchors.fill: parent
                    visible: input.text.length === 0
                    text: "告诉我身体状态、训练目标，或输入“推荐训练”"
                    color: Theme.mutedSoft
                    font: input.font
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                id: sendButton
                x: composer.width - Theme.px(58)
                y: Theme.px(5)
                width: Theme.px(48)
                height: Theme.px(36)
                radius: Theme.px(16)
                color: input.text.trim().length > 0 && !page.isAssistantThinking
                       ? Qt.rgba(0, 0.941, 1, 0.20) : Qt.rgba(0.420, 0.482, 0.612, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: "发送"
                    color: input.text.trim().length > 0 && !page.isAssistantThinking ? Theme.primary : Theme.muted
                    font.pixelSize: Theme.fontPx(12)
                }
                TapHandler {
                    enabled: input.text.trim().length > 0 && !page.isAssistantThinking
                    onTapped: page.sendFreeText()
                }
            }
        }
    }

    // Web parity: live screening summary, completion progress, safety guidance
    // and an always-visible recommendation action.
    HmiCard {
        id: intakePanel
        x: Theme.px(908) - 48
        y: Theme.px(206) - 150
        width: Theme.px(316)
        height: Theme.px(464)
        radius: Theme.px(20)
        fillColor: Qt.rgba(0.067, 0.067, 0.067, 0.68)

        Text {
            x: Theme.px(20)
            y: Theme.px(16)
            text: "筛查摘要"
            color: Theme.text
            font.pixelSize: Theme.fontPx(15)
        }
        Text {
            x: intakePanel.width - Theme.px(74)
            y: Theme.px(13)
            width: Theme.px(54)
            text: page.completionPercent + "%"
            color: Theme.primary
            font.pixelSize: Theme.fontPx(18)
            horizontalAlignment: Text.AlignRight
        }

        Rectangle {
            x: Theme.px(20)
            y: Theme.px(50)
            width: intakePanel.width - Theme.px(40)
            height: Theme.px(8)
            radius: height / 2
            color: Qt.rgba(0.420, 0.482, 0.612, 0.20)
            Rectangle {
                width: parent.width * page.completionPercent / 100
                height: parent.height
                radius: height / 2
                color: page.hasPainOrFatigue ? Theme.warn : Theme.success
                Behavior on width { NumberAnimation { duration: 220 } }
            }
        }

        Column {
            x: Theme.px(20)
            y: Theme.px(70)
            width: intakePanel.width - Theme.px(40)
            spacing: Theme.px(8)

            Repeater {
                model: page.summaryItems()
                delegate: Rectangle {
                    id: summaryRow
                    required property var modelData
                    width: parent.width
                    height: Theme.px(48)
                    radius: Theme.px(12)
                    color: Qt.rgba(1, 1, 1, 0.035)
                    Text {
                        x: Theme.px(12)
                        y: Theme.px(7)
                        text: summaryRow.modelData.label
                        color: Theme.muted
                        font.pixelSize: Theme.fontPx(10)
                    }
                    Text {
                        x: Theme.px(12)
                        y: Theme.px(23)
                        width: summaryRow.width - Theme.px(24)
                        text: summaryRow.modelData.value
                        color: summaryRow.modelData.pending ? Theme.mutedSoft : Theme.text
                        font.pixelSize: Theme.fontPx(13)
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Rectangle {
            x: Theme.px(20)
            y: Theme.px(294)
            width: intakePanel.width - Theme.px(40)
            height: Theme.px(92)
            radius: Theme.px(14)
            color: page.hasPainOrFatigue
                   ? Qt.rgba(1, 0.902, 0, 0.08) : Qt.rgba(0, 0.941, 1, 0.07)
            border.width: 1
            border.color: page.hasPainOrFatigue
                          ? Qt.rgba(1, 0.902, 0, 0.35) : Qt.rgba(0, 0.941, 1, 0.25)
            Text {
                x: Theme.px(12)
                y: Theme.px(10)
                text: page.hasPainOrFatigue ? "保守训练提示" : "训练提示"
                color: page.hasPainOrFatigue ? Theme.warn : Theme.primary
                font.pixelSize: Theme.fontPx(12)
            }
            Text {
                x: Theme.px(12)
                y: Theme.px(31)
                width: parent.width - Theme.px(24)
                height: Theme.px(52)
                text: page.safetyNote()
                color: Theme.muted
                font.pixelSize: Theme.fontPx(11)
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: recommendationButton
            x: Theme.px(20)
            y: Theme.px(404)
            width: intakePanel.width - Theme.px(40)
            height: Theme.px(42)
            radius: Theme.px(16)
            color: page.intakeComplete
                   ? Qt.rgba(0, 1, 0.471, 0.18) : Qt.rgba(0.420, 0.482, 0.612, 0.12)
            border.width: 1
            border.color: page.intakeComplete
                          ? Qt.rgba(0, 1, 0.471, 0.40) : Qt.rgba(0.420, 0.482, 0.612, 0.18)
            Text {
                anchors.centerIn: parent
                text: "查看推荐入口"
                color: page.intakeComplete ? Theme.success : Theme.muted
                font.pixelSize: Theme.fontPx(14)
            }
            TapHandler {
                enabled: page.intakeComplete
                onTapped: page.openRecommendations()
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
