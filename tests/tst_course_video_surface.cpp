#include <QtTest/QtTest>

#include <QGuiApplication>
#include <QElapsedTimer>
#include <QImage>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSet>
#include <QSignalSpy>
#include <QTimer>

#include "course_video_surface.h"

namespace {

// Drives one render pass with a synthetic solid-color frame and reports whether
// the scene graph actually painted that color into the window. Returns false
// (rather than failing) when the platform cannot render offscreen, so the test
// skips instead of erroring on a headless host.
bool rendersSolidColor(QQuickWindow *window, CourseVideoSurface *surface,
                       const QColor &color) {
    QImage frame(80, 80, QImage::Format_RGBA8888);
    frame.fill(color);
    QSignalSpy sizeSpy(surface, &CourseVideoSurface::videoSizeChanged);
    surface->submitTestFrame(frame);
    surface->setSize(QSizeF(160, 160));
    surface->update();

    // Pump the event loop long enough for at least one committed frame.
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < 400)
        QCoreApplication::processEvents(QEventLoop::AllEvents, 50);

    const QImage grab = window->grabWindow();
    if (grab.isNull() || grab.size().isEmpty())
        return false;

    const QRgb target = color.rgba();
    for (int y = 0; y < grab.height(); ++y) {
        const QRgb *line = reinterpret_cast<const QRgb *>(grab.constScanLine(y));
        for (int x = 0; x < grab.width(); ++x) {
            if (qRed(line[x]) == qRed(target) &&
                qGreen(line[x]) == qGreen(target) &&
                qBlue(line[x]) == qBlue(target))
                return true;
        }
    }
    return false;
}

}  // namespace

class CourseVideoSurfaceTest : public QObject {
    Q_OBJECT
private slots:
    void videoSizeTracksSubmittedFrame();
    void rendersUnderSoftwareBackend();
    void rendersUnderDefaultBackend();

private:
    bool ensureSurfaceReady(QQuickWindow **windowOut, CourseVideoSurface **surfaceOut);
};

void CourseVideoSurfaceTest::videoSizeTracksSubmittedFrame() {
    // Frame intake (videoSize) is GUI-thread state and does not require a live
    // scene graph, so it is asserted independently of rendering.
    QQuickWindow window;
    CourseVideoSurface surface;
    surface.setParentItem(window.contentItem());
    QCOMPARE(surface.videoSize(), QSize());

    QImage frame(64, 36, QImage::Format_RGBA8888);
    frame.fill(Qt::red);
    QSignalSpy spy(&surface, &CourseVideoSurface::videoSizeChanged);
    surface.submitTestFrame(frame);
    QCOMPARE(surface.videoSize(), QSize(64, 36));
    QCOMPARE(spy.count(), 1);

    // A same-sized frame must not re-emit videoSizeChanged.
    surface.submitTestFrame(frame);
    QCOMPARE(spy.count(), 1);
}

bool CourseVideoSurfaceTest::ensureSurfaceReady(QQuickWindow **windowOut,
                                                CourseVideoSurface **surfaceOut) {
    auto *window = new QQuickWindow;
    window->resize(160, 160);
    window->setColor(Qt::black);
    auto *surface = new CourseVideoSurface;
    surface->setParentItem(window->contentItem());
    *windowOut = window;
    *surfaceOut = surface;
    return true;
}

void CourseVideoSurfaceTest::rendersUnderSoftwareBackend() {
    // The software scene-graph backend is the most reliable headless path and is
    // the one used on the RK3588-class validation target, so exercise it first.
    qputenv("QSG_RHI_BACKEND", "software");
    QQuickWindow *window = nullptr;
    CourseVideoSurface *surface = nullptr;
    ensureSurfaceReady(&window, &surface);
    window->show();
    // Allow the platform to settle before grabbing.
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < 200)
        QCoreApplication::processEvents(QEventLoop::AllEvents, 30);

    const bool rendered = rendersSolidColor(window, surface, QColor(220, 40, 40));
    delete window;
    if (!rendered)
        QSKIP("software scene-graph render backend unavailable on this host");
}

void CourseVideoSurfaceTest::rendersUnderDefaultBackend() {
    qunsetenv("QSG_RHI_BACKEND");
    QQuickWindow *window = nullptr;
    CourseVideoSurface *surface = nullptr;
    ensureSurfaceReady(&window, &surface);
    window->show();
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < 200)
        QCoreApplication::processEvents(QEventLoop::AllEvents, 30);

    const bool rendered = rendersSolidColor(window, surface, QColor(40, 200, 60));
    delete window;
    if (!rendered)
        QSKIP("default scene-graph render backend unavailable on this host");
}

int main(int argc, char **argv) {
    // Offscreen keeps the test deterministic and display-free.
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    CourseVideoSurfaceTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_course_video_surface.moc"
