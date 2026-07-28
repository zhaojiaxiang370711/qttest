#include "course_video_surface.h"

#include "course_playback_controller.h"

#include <QMetaObject>
#include <QMutexLocker>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <QSGTexture>
#include <algorithm>

CourseVideoSurface::CourseVideoSurface(QQuickItem *parent)
    : QQuickItem(parent) {
    setFlag(ItemHasContents, true);
}

CourseVideoSurface::~CourseVideoSurface() {
    if (m_controller)
        m_controller->disconnect(this);
}

void CourseVideoSurface::setController(CoursePlaybackController *controller) {
    if (m_controller == controller)
        return;
    if (m_controller)
        m_controller->disconnect(this);
    m_controller = controller;
    if (m_controller) {
        connect(m_controller, &CoursePlaybackController::frameReady,
                this, &CourseVideoSurface::onFrame);
    }
    emit controllerChanged();
}

void CourseVideoSurface::onFrame(const QImage &frame) {
    storeFrame(frame);
    update();
}

void CourseVideoSurface::submitTestFrame(const QImage &frame) {
    storeFrame(frame);
    update();
}

void CourseVideoSurface::storeFrame(const QImage &frame) {
    if (frame.isNull())
        return;
    {
        QMutexLocker locker(&m_frameMutex);
        m_pendingFrame = frame;
        m_framePending = true;
    }
    if (m_videoSize != frame.size()) {
        m_videoSize = frame.size();
        emit videoSizeChanged();
    }
}

QRectF CourseVideoSurface::containRect(const QSize &source, const QRectF &bounds) {
    if (source.isEmpty() || bounds.isEmpty())
        return QRectF();
    const qreal sx = bounds.width() / qreal(source.width());
    const qreal sy = bounds.height() / qreal(source.height());
    const qreal scale = std::min(sx, sy);
    const qreal w = source.width() * scale;
    const qreal h = source.height() * scale;
    return QRectF(bounds.x() + (bounds.width() - w) / 2.0,
                  bounds.y() + (bounds.height() - h) / 2.0, w, h);
}

QSGNode *CourseVideoSurface::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) {
    bool presentedNew = false;
    {
        QMutexLocker locker(&m_frameMutex);
        if (m_framePending) {
            m_renderFrame = m_pendingFrame;
            m_framePending = false;
            presentedNew = true;
        }
    }

    QImage frameForTexture;
    QQuickWindow * const win = window();
    if (presentedNew && win && !m_renderFrame.isNull())
        frameForTexture = m_renderFrame;

    // Until the first frame lands, render nothing: a QSGSimpleTextureNode with
    // no backing texture dereferences null in the software scene-graph backend.
    if (!oldNode && frameForTexture.isNull())
        return nullptr;

    auto *node = static_cast<QSGSimpleTextureNode *>(oldNode);
    if (!node) {
        node = new QSGSimpleTextureNode;
        node->setOwnsTexture(true);
        node->setFiltering(QSGTexture::Linear);
    }

    if (!frameForTexture.isNull()) {
        // The node owns its textures (setOwnsTexture), so setTexture releases
        // the previous texture on the render thread automatically. Releasing it
        // ourselves here would double-free.
        QSGTexture *texture = win->createTextureFromImage(
            frameForTexture, QQuickWindow::TextureIsOpaque);
        if (texture) {
            node->setTexture(texture);
            if (m_controller) {
                auto *controller = m_controller;
                QMetaObject::invokeMethod(controller, [controller]() {
                    controller->noteFramePresented();
                }, Qt::QueuedConnection);
            }
        }
    }

    // Never hand the scene graph a texture node without a texture.
    if (!node->texture())
        return nullptr;

    node->setRect(containRect(m_renderFrame.size(), boundingRect()));
    return node;
}

void CourseVideoSurface::releaseResources() {
    QMutexLocker locker(&m_frameMutex);
    m_pendingFrame = {};
    m_renderFrame = {};
    m_framePending = false;
}
