#pragma once
#include <cmath>

// A source consumes original samples at 'rate'. Its local effect cancels that
// pitch change. Chart time stays in ORIGINAL song seconds, including after seeks.
struct Tempo {
    float rate = 1;
    float pitchCorrection() const { return 1.0f / rate; }
    float chartDelta(float realSeconds) const { return realSeconds * rate; }
    float wallDuration(float songSeconds) const { return songSeconds / rate; }
    float audibleSampleDelay(float seconds, float clipHz) const { return seconds * rate * clipHz; }
};

// The host supplies a source-local bus. Effects are never attached to the master.
struct PitchBackend {
    int (*create)(void *system, int type, void **effect);
    int (*parameter)(void *effect, int parameter, float value);
    int (*attach)(void *bus, void *effect, void **connection);
    int (*remove)(void *effect);
    int (*release)(void *effect);
};
class PitchSession {
    void *effect_ = nullptr;
public:
    static constexpr int fftFrames = 512;
    int start(const PitchBackend &api, void *system, void *bus, int pitchType, Tempo tempo) {
        if (effect_ || !system || !bus || !(tempo.rate >= .5f && tempo.rate <= 2)) return -1;
        void *node = nullptr;
        int rc = api.create(system, pitchType, &node);
        if (rc || !node) return rc ? rc : -2;
        rc = api.parameter(node, 1, fftFrames);
        if (!rc) rc = api.parameter(node, 0, tempo.pitchCorrection());
        if (!rc) rc = api.attach(bus, node, nullptr);
        if (rc) { api.release(node); return rc; }
        effect_ = node;
        return 0;
    }
    void stop(const PitchBackend &api) {
        if (effect_) {
            api.remove(effect_);
            api.release(effect_);
            effect_ = nullptr;
        }
    }
};
