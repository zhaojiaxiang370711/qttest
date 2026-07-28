#pragma once

#ifndef QXZN_HMI_DDS
#define QXZN_HMI_DDS 0
#endif

#if QXZN_HMI_DDS
#include <qxzn/pd02/dds/motor_bridge.h>

struct DdsApi {
    using CreateFn = decltype(&qxzn_pd02_dds_create);
    using DestroyFn = decltype(&qxzn_pd02_dds_destroy);
    using TakeHitEventFn = decltype(&qxzn_pd02_dds_take_hit_event);
    using PublishLedCommandFn = decltype(&qxzn_pd02_dds_publish_led_command);

    CreateFn create = nullptr;
    DestroyFn destroy = nullptr;
    TakeHitEventFn takeHitEvent = nullptr;
    PublishLedCommandFn publishLedCommand = nullptr;

    bool isComplete() const {
        return create && destroy && takeHitEvent && publishLedCommand;
    }
};
#endif
