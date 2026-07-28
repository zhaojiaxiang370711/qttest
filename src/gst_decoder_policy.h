#pragma once

#include <QString>

struct _GstElement;
typedef struct _GstElement GstElement;

struct GstDecoderPolicyResult {
    bool ok = false;
    QString mode;
    QString preferredDecoder;
    QString error;
};

class GstDecoderPolicy {
public:
    static GstDecoderPolicyResult configure(const QString &requestedMode);
    static QString modeFromEnvironment();
    static bool factoryAvailable(const QString &factoryName);
    static QString activeDecoder(GstElement *pipeline);

private:
    static bool ensureInitialized(QString *error);
};
