#include "course_catalog.h"

namespace {

QVariantMap marker(qint64 timeMs, const QString &label) {
    return {
        {QStringLiteral("timeMs"), timeMs},
        {QStringLiteral("label"), label},
    };
}

QVariantMap launcher(const QString &id, const QString &title, const QString &cover,
                     const QString &kind, const QString &videoCourseId = QString()) {
    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("title"), title},
        {QStringLiteral("cover"), cover},
        {QStringLiteral("kind"), kind},
        {QStringLiteral("videoCourseId"), videoCourseId},
    };
}

// A boxing move / technique entry for the Movements view. Mirrors
// course_data.gd::moves(); cover points at the synced move_N.jpg asset.
QVariantMap move(const QString &title, const QString &chinese, const QString &difficulty,
                 const QString &timeToLearn, const QString &desc, const QString &cover,
                 const QVariantList &steps) {
    return {
        {QStringLiteral("title"), title},
        {QStringLiteral("chinese"), chinese},
        {QStringLiteral("difficulty"), difficulty},
        {QStringLiteral("timeToLearn"), timeToLearn},
        {QStringLiteral("desc"), desc},
        {QStringLiteral("cover"), cover},
        {QStringLiteral("steps"), steps},
    };
}

QVariantMap videoCourse(const QString &id, const QString &title, const QString &cover,
                        const QString &mediaKey, qint64 durationHintMs,
                        const QVariantList &markers = {}) {
    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("title"), title},
        {QStringLiteral("cover"), cover},
        {QStringLiteral("mediaKey"), mediaKey},
        {QStringLiteral("durationHintMs"), durationHintMs},
        {QStringLiteral("markers"), markers},
    };
}

QVariantList specialPracticeMarkers() {
    return {
        marker(10190, QStringLiteral("左直拳")),
        marker(14040, QStringLiteral("左直拳")),
        marker(17190, QStringLiteral("左直拳")),
        marker(22140, QStringLiteral("右直拳")),
        marker(25190, QStringLiteral("右直拳")),
        marker(29040, QStringLiteral("右直拳")),
        marker(35140, QStringLiteral("左右直拳")),
        marker(38190, QStringLiteral("左右直拳")),
        marker(41590, QStringLiteral("左右直拳")),
        marker(48190, QStringLiteral("一二侧闪")),
        marker(51540, QStringLiteral("一二侧闪")),
        marker(55090, QStringLiteral("一二侧闪")),
        marker(63040, QStringLiteral("一二侧闪击腹")),
        marker(66140, QStringLiteral("一二侧闪击腹")),
        marker(69540, QStringLiteral("一二侧闪击腹")),
        marker(75540, QStringLiteral("右摇闪")),
        marker(79090, QStringLiteral("右摇闪")),
        marker(82190, QStringLiteral("右摇闪")),
        marker(91120, QStringLiteral("一二摇闪")),
        marker(94490, QStringLiteral("一二摇闪")),
        marker(98030, QStringLiteral("一二摇闪")),
    };
}

} // namespace

CourseCatalog::CourseCatalog(QObject *parent)
    : QObject(parent) {
    const QString stanceCover = QStringLiteral(
        "qrc:/resources/images/course/launcher_stance_cover.png");
    const QString crossCover = QStringLiteral(
        "qrc:/resources/images/course/launcher_cross_cover.png");

    m_launchers = {
        launcher(QStringLiteral("focus_mitt"), QStringLiteral("手靶课"),
                 QStringLiteral("qrc:/resources/images/course/sbk.png"),
                 QStringLiteral("focus_mitt")),
        launcher(QStringLiteral("bodycombat"), QStringLiteral("搏击操"), stanceCover,
                 QStringLiteral("interactive")),
        launcher(QStringLiteral("lesmills_bodycombat"), QStringLiteral("莱美搏击操_1"),
                 QStringLiteral("qrc:/resources/images/course/lmbjc.png"),
                 QStringLiteral("interactive")),
        launcher(QStringLiteral("special_practice"), QStringLiteral("专项练习"), stanceCover,
                 QStringLiteral("video"), QStringLiteral("special_practice")),
        launcher(QStringLiteral("stance"), QStringLiteral("基础系列：站姿教学"), stanceCover,
                 QStringLiteral("video"), QStringLiteral("stance")),
        launcher(QStringLiteral("right_straight"), QStringLiteral("基础系列：右直拳教学"),
                 crossCover, QStringLiteral("video"), QStringLiteral("right_straight")),
        // Fight Flow 复刻 lessons_test Web 原型,独立播放器子页(fight_flow)。
        launcher(QStringLiteral("fight_flow"), QStringLiteral("搏击燃脂·进阶"),
                 QStringLiteral("qrc:/resources/images/course/launcher_fight_flow_cover.png"),
                 QStringLiteral("fight_flow"), QStringLiteral("fight_flow")),
    };

    m_courses = {
        videoCourse(QStringLiteral("special_practice"), QStringLiteral("专项练习"),
                    stanceCover, QStringLiteral("course/special_practice.mp4"), 103508,
                    specialPracticeMarkers()),
        videoCourse(QStringLiteral("stance"), QStringLiteral("基础系列：站姿教学"),
                    stanceCover, QStringLiteral("course/stance_en.mp4"), 22120),
        videoCourse(QStringLiteral("right_straight"),
                    QStringLiteral("基础系列：右直拳教学"), crossCover,
                    QStringLiteral("course/right_straight_en.mp4"), 25640),
        // Fight Flow 课程( lessons_test 原型 sisi_bodycombat_01.json ):
        // markers 为章节边界,章节名/击打目标等由 FightFlowPage 内嵌配置驱动。
        videoCourse(QStringLiteral("fight_flow"), QStringLiteral("搏击燃脂·进阶"),
                    QStringLiteral("qrc:/resources/images/course/launcher_fight_flow_cover.png"),
                    QStringLiteral("course/sisi_bodycombat_01.mp4"), 121154,
                    {
                        marker(44000, QStringLiteral("直拳冲刺")),
                        marker(80000, QStringLiteral("【重击】右勾拳x2 + 左摇闪 + 左摆拳")),
                    }),
    };

    // Boxing technique encyclopedia for the Movements view (course_data.gd::moves()).
    m_moves = {
        move(QStringLiteral("The Lead Jab"), QStringLiteral("Jab"), QStringLiteral("Basic"),
             QStringLiteral("5 Mins"),
             QStringLiteral("The gold standard of range finder and defensive warding. "
                            "Lightning fast, snapped straight from the shoulder grid."),
             QStringLiteral("qrc:/resources/images/course/move_0.jpg"),
             {
                 QStringLiteral("Extend your lead arm straight out in line with your nose."),
                 QStringLiteral("Rotate your lead shoulder up high to protect your jaw."),
                 QStringLiteral("Drive your heel slightly off the floor and snap back to guard."),
             }),
        move(QStringLiteral("The Rear Cross"), QStringLiteral("Cross"), QStringLiteral("Basic"),
             QStringLiteral("8 Mins"),
             QStringLiteral("The primary power drive. Fired straight down the pipe utilizing "
                            "the full torsional release of the hip."),
             QStringLiteral("qrc:/resources/images/course/move_1.jpg"),
             {
                 QStringLiteral("Pivot your back rear foot inward, releasing hip tension forward."),
                 QStringLiteral("Drive your back glove in a straight laser path to center target."),
                 QStringLiteral("Keep your lead hand tightly shielding your temple and cheek."),
             }),
        move(QStringLiteral("The Lead Hook"), QStringLiteral("Hook"), QStringLiteral("Intermediate"),
             QStringLiteral("12 Mins"),
             QStringLiteral("Explosive circular torque punch. Circles around opponent guard "
                            "lines to target temples or liver zones."),
             QStringLiteral("qrc:/resources/images/course/move_2.jpg"),
             {
                 QStringLiteral("Raise lead elbow up parallel to the floor in a 90 degree hook block."),
                 QStringLiteral("Rotate your hips, neck, and front foot outward like a hinged door."),
                 QStringLiteral("Lock your wrist brace rigidly as impact force transfers."),
             }),
        move(QStringLiteral("The Uppercut"), QStringLiteral("Uppercut"), QStringLiteral("Intermediate"),
             QStringLiteral("15 Mins"),
             QStringLiteral("Launches vertically from below. Targets chin gaps or sternum "
                            "centers in tight close-quarters sparring."),
             QStringLiteral("qrc:/resources/images/course/move_3.jpg"),
             {
                 QStringLiteral("Dip shoulders and bend knees slightly to sink center of weight."),
                 QStringLiteral("Thrust upward through your legs and core, driving fist high."),
                 QStringLiteral("Turn palm towards you on release without dropping arm beforehand."),
             }),
        move(QStringLiteral("The Roll & Bob"), QStringLiteral("Weave"), QStringLiteral("Advanced"),
             QStringLiteral("20 Mins"),
             QStringLiteral("Unleash slick kinetic dodge motions. Ducks smoothly under incoming "
                            "heavy swing loops while loading a counter punch."),
             QStringLiteral("qrc:/resources/images/course/move_4.jpg"),
             {
                 QStringLiteral("Shift weight to side slightly as soon as opponents arm extends."),
                 QStringLiteral("Roll head and shoulders in a deep U-shape loop to slip underneath."),
                 QStringLiteral("Reset posture quickly in secondary guard, ready to explode back."),
             }),
    };

    // Focus-mitt trainer units (course_data.gd::focus_mitt_units). Each unit is
    // a landscape video the user strikes along with; durationSec drives the
    // per-unit countdown and mediaKey resolves via QXZN_MEDIA_DIR/sbkcourse.
    auto focusUnit = [](const QString &id, const QString &name, double durationSec,
                        const QString &mediaKey, const QString &tip) {
        QVariantMap u;
        u.insert(QStringLiteral("id"), id);
        u.insert(QStringLiteral("name"), name);
        u.insert(QStringLiteral("durationSec"), durationSec);
        u.insert(QStringLiteral("durationMs"), qint64(durationSec * 1000.0));
        u.insert(QStringLiteral("mediaKey"), mediaKey);
        u.insert(QStringLiteral("tip"), tip);
        return u;
    };
    m_focusMittUnits = {
        focusUnit(QStringLiteral("twelve_punch_combo"), QStringLiteral("12 Punch Combo"), 144.787,
                  QStringLiteral("sbkcourse/01_12_punch_combo_v2.mp4"),
                  QStringLiteral("持续击打腹部左右两侧的靶位，用尽全力，加油！")),
        focusUnit(QStringLiteral("left_slip_32_right_roll_23"),
                  QStringLiteral("左侧闪 32 · 右摇闪 2 3"), 67.135,
                  QStringLiteral("sbkcourse/02_left_slip_32_right_roll_23.mp4"),
                  QStringLiteral("持续击打腹部左右两侧的靶位，用尽全力，加油！")),
        focusUnit(QStringLiteral("right_slip_41_left_roll_14"),
                  QStringLiteral("右侧闪 41 · 左摇闪 1 4"), 75.241,
                  QStringLiteral("sbkcourse/03_right_slip_41_left_roll_14.mp4"),
                  QStringLiteral("持续击打腹部左右两侧的靶位，用尽全力，加油！")),
    };
}

bool CourseCatalog::contains(const QString &id) const {
    return !course(id).isEmpty();
}

QVariantMap CourseCatalog::course(const QString &id) const {
    for (const QVariant &value : m_courses) {
        const QVariantMap candidate = value.toMap();
        if (candidate.value(QStringLiteral("id")).toString() == id)
            return candidate;
    }
    return {};
}

bool CourseCatalog::isMediaKeyAllowed(const QString &mediaKey) {
    return mediaKey == QStringLiteral("course/special_practice.mp4") ||
           mediaKey == QStringLiteral("course/stance_en.mp4") ||
           mediaKey == QStringLiteral("course/right_straight_en.mp4") ||
           mediaKey == QStringLiteral("course/sisi_bodycombat_01.mp4") ||
           // focus-mitt trainer units (course_data.gd::focus_mitt_units)
           mediaKey == QStringLiteral("sbkcourse/01_12_punch_combo_v2.mp4") ||
           mediaKey == QStringLiteral("sbkcourse/02_left_slip_32_right_roll_23.mp4") ||
           mediaKey == QStringLiteral("sbkcourse/03_right_slip_41_left_roll_14.mp4");
}
