#pragma once
#include <array>
#include <vector>
#include <complex>
#include <cstdint>
namespace tl {
using Keys=std::array<float,88>;
struct Partial { float bin=0,offset=0,amplitude=0,snr=0,width=0; int valid=0,code=0; };
struct Measurement {float ih=-99999,anchor=0; std::array<Partial,12> partials;};
struct Interval {int p,q,g;};
extern const Interval intervals[16];
double nominal(int note);
float beta(int p,bool modern);
std::vector<std::complex<double>> fft(const std::vector<float>& samples);
float peakOffset(std::complex<float> before,std::complex<float> peak,std::complex<float> after);
Measurement analyze(const std::vector<int16_t>& pcm,int note,float sampleRate=22050);
Keys profile(const Keys& values,const std::array<int,88>& counts);
Keys curve(const Keys& ih,int bass=3,int middle=1,int treble=6,int start=36,bool modern=true);
float stretch(const Keys& y,const Keys& ih,int note,int partial,bool modern);
Keys legacy(float b1,float k1,float b4,float k4);
std::array<float,4> fitLegacy(const Keys& ih,int points,bool modern,int bass=2,int treble=6);
Keys legacySplit(const Keys& ih,std::array<float,4> params,int split,bool modern,int bass=2);
struct Overpull {Keys offsets{};std::array<int,88> present{};int bass=25,wound=25,strut1=45,strut2=68,step=20;float woundLimit=20,plainLimit=30;};
float overpull(const Overpull&,int note,bool* limited=nullptr);
struct Pitch {bool valid=false;float hz=0,cents=0,amplitude=0;int note=-1;std::vector<float> spectrum;};
Pitch pitch(const std::vector<int16_t>& pcm,double target,int selectedNote,bool automatic);
class Resampler {
    double rate=0,next=0;long long index=-1;std::vector<float> history;float pending=0;bool hasPending=false;
public:
    explicit Resampler(double inputRate);
    std::vector<int16_t> feed(const float* samples,size_t count);
};
}
