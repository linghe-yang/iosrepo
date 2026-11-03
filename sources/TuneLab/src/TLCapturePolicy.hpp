#pragma once
#include <cmath>
#include <cstdint>
namespace tl {
// Capture intent outlives a route change or interruption. All policy calls run
// on the control thread; the observed audio counters are atomic in the adapter.
struct CapturePolicy {
    enum class Health { Waiting, Healthy, EngineStopped, NoInput, NoConvertedOutput };
    bool requested=false,starting=false,interrupted=false;
    unsigned recoveries=0;
    void request(){requested=true;starting=false;interrupted=false;recoveries=0;}
    void stop(){requested=false;starting=false;interrupted=false;recoveries=0;}
    Health inspect(double now,double start,double input,double output,bool running) const {
        if(!requested||starting||interrupted)return Health::Waiting;
        if(!running)return Health::EngineStopped;
        if(now-start<2)return Health::Waiting;
        if(now-input>2)return Health::NoInput;
        if(now-output>2)return Health::NoConvertedOutput;
        return Health::Healthy;
    }
    bool recover(){if(!requested||interrupted||starting)return false;if(++recoveries<=3)return true;requested=false;return false;}
};
inline int16_t pcm16(float sample){
    if(!std::isfinite(sample))return 0;
    double value=std::round(double(sample)*32768.);
    if(value>32767)return 32767;
    if(value<-32768)return -32768;
    return int16_t(value);
}
}
