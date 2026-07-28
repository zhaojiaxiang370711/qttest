#pragma once

#include <QImage>
#include <QMutex>
#include <QQuickItem>
#include <QRectF>
#include <QSize>

class CoursePlaybackController;

// CourseVideoSurface renders the latest RGBA frame produced by a
// CoursePlaybackController. It is a deliberately bounded CPU-copy renderer:
// the controller hands off fully-decoded QImage frames on the GUI thread, this
// item copies the newest one under a short lock, and the render thread uploads
// it through a QSGSimpleTextureNode with aspect-contain geometry. It is NOT a
// zero-copy / DMA-BUF / 4K path, by design (see rendererMode "cpu-copy").
class CourseVideoSurface : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(CoursePlaybackController *controller READ controller WRITE setController NOTIFY controllerChanged)
    Q_PROPERTY(QSize videoSize READ videoSize NOTIFY videoSizeChanged)

public:
    explicit CourseVideoSurface(QQuickItem *parent = nullptr);
    ~CourseVideoSurface() override;

    CoursePlaybackController *controller() const { return m_controller; }
    void setController(CoursePlaybackController *controller);

    QSize videoSize() const { return m_videoSize; }

    // Largest rectangle, centered inside bounds, that preserves source aspect.
    // Pure geometry — exposed for unit testing.
    static QRectF containRect(const QSize &source, const QRectF &bounds);

    // Test/debug hook: pushes a synthetic frame through the same path as a real
    // decoded frame so the render path can be exercised without GStreamer media.
    void submitTestFrame(const QImage &frame);

signals:
    void controllerChanged();
    void videoSizeChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *data) override;
    void releaseResources() override;

private:
    void onFrame(const QImage &frame);
    void storeFrame(const QImage &frame);

    CoursePlaybackController *m_controller = nullptr;
    QSize m_videoSize;

    // Written on the GUI thread (storeFrame), read on the render thread
    // (updatePaintNode). The mutex covers that handoff.
    QMutex m_frameMutex;
    QImage m_pendingFrame;
    bool m_framePending = false;
    QImage m_renderFrame;
};
