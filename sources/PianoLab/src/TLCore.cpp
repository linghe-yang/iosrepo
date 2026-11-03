#include "TLCore.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <limits>
#include <stdexcept>
namespace tl {
static constexpr double pi=3.14159265358979323846;
const Interval intervals[16]={{2,1,12},{4,2,12},{6,3,12},{8,4,12},{10,5,12},{12,6,12},{4,1,24},{8,2,24},{12,3,24},{3,1,19},{6,2,19},{3,2,7},{6,4,7},{8,1,36},{9,3,19},{6,1,31}};
double nominal(int n){return 27.5*std::exp2(n/12.);}
float beta(int p,bool modern){static const float b[]={0,1,4,8.45f,13.18f,19.72f,27.27f,35.53f,46.25f,57.12f,69.43f,83.22f,96.6f,109.8f,125.4f,139.5f,156.1f};if(p<1||p>16)throw std::invalid_argument("partial");return modern?p*p:b[p];}
std::vector<std::complex<double>> fft(const std::vector<float>& samples){
    size_t n=samples.size();if(n<2||(n&(n-1)))throw std::invalid_argument("FFT length");
    std::vector<std::complex<double>> out(samples.begin(),samples.end());size_t j=0;
    for(size_t i=1;i<n;i++){size_t bit=n>>1;while(j&bit){j^=bit;bit>>=1;}j^=bit;if(i<j)std::swap(out[i],out[j]);}
    for(size_t size=2;size<=n;size*=2){size_t half=size/2;std::vector<std::complex<double>> w(half);for(size_t k=0;k<half;k++)w[k]=std::polar(1.,-2*pi*k/size);for(size_t start=0;start<n;start+=size)for(size_t k=0;k<half;k++){auto a=out[start+k],b=w[k]*out[start+k+half];out[start+k]=a+b;out[start+k+half]=a-b;}}
    return out;
}
float peakOffset(std::complex<float> a,std::complex<float> p,std::complex<float> b){
    double denom=p.imag()*p.imag()+p.real()*p.real();if(denom==0)return 0;
    auto dot=[&](std::complex<float> z){return double(p.imag()*z.imag()+p.real()*z.real())/denom;};
    double ap=dot(b),am=dot(a);if(ap==1||am==1)return 0;
    double dp=-ap/(1-ap),dm=am/(1-am);
    auto tau=[](double x){return .25*std::log(3*x*x+6*x+1)-.102062072*std::log((x+.183503419)/(x+1.816496581));};
    double value=(dp+dm)*.5+tau(dp*dp)-tau(dm*dm);return std::isfinite(value)?std::max(-.5,std::min(.5,value)):0;
}
Measurement analyze(const std::vector<int16_t>& pcm,int note,float sr){
    if(note<0||note>87||pcm.size()!=size_t(note<45?65536:note<66?32768:16384)||!std::isfinite(sr)||sr<20000)throw std::invalid_argument("measurement input");
    std::vector<float> input(pcm.begin(),pcm.end());auto transformed=fft(input);size_t n=pcm.size();
    std::vector<std::complex<float>> bins(transformed.begin(),transformed.end());std::vector<float> power(n);
    for(size_t k=0;k<n;k++){float r=bins[k].real(),i=bins[k].imag();power[k]=std::sqrt(r*r+i*i);}
    float scale=n/sr,fund=scale*float(nominal(note));int floor=int(scale*107),ceiling=std::min(int(n/2)-2,int(scale*9033));
    auto at=[&](int k){if(k<1||k>=int(n/2)-1||power[k]==0)return float(k);return k+peakOffset(bins[k-1],bins[k],bins[k+1]);};
    int lo=std::max(int(fund*.917f),floor),hi=std::min(int(fund*8.51472f),ceiling),dominant=lo;
    if(lo>hi)throw std::invalid_argument("frequency band");
    for(int k=lo;k<=hi;k++)if(power[k]>power[dominant])dominant=k;
    float peak=at(dominant);int harmonic=std::max(1,std::min(8,int(peak/fund+.48528f)));float anchor=peak/harmonic;
    Measurement result;result.anchor=anchor;float maxamp=0;
    static const float boundaries[]={.5,1.5,2.5,3.5,4.5,5.5,6.5,7.5,8.55,9.6,10.7,11.75,12.8};
    for(int p=1;p<=12;p++){
        auto& r=result.partials[p-1];lo=std::max(int(anchor*boundaries[p-1]),floor);hi=std::min(int(anchor*boundaries[p]+.5f),ceiling);int best=-1;float amplitude=0;
        for(int k=lo;k<=hi;k++){if(power[k]>amplitude){amplitude=power[k];best=k;}if(lo<best&&best<hi){r.bin=at(best);r.amplitude=amplitude;}}
        if(r.amplitude)r.offset=std::log(double(r.bin/(anchor*p)))*1731.234049;
        maxamp=std::max(maxamp,r.amplitude);
    }
    int radius=int(anchor*.5f),run=int(anchor*.06f);
    for(auto& r:result.partials){float amp=r.amplitude;
        if(amp==0)r.code=1;else if(amp*100/maxamp<.06f)r.code=3;
        if(amp){int center=int(r.bin+.5f),left=0,right=0,lc=0,rc=0;
            if(radius>1)for(int d=1;d<radius;d++){
                if(center-d<0||center+d>=int(n))break;
                if(!left){if(amp*.4f<=power[center-d])lc=0;else {if(lc>=run-1)left=center-d+run-1;lc++;}}
                if(!right){if(amp*.4f<=power[center+d])rc=0;else {if(rc>=run-1)right=center+d-run+1;rc++;}}
                if(left&&right)break;
            }
            if(left&&right){float total=0;int terms=0;for(int k=std::max(0,center-radius);k<std::min(int(n),center+radius);k++)if(k<left||k>right){total+=power[k];terms++;}
                r.snr=total?amp*terms/total:std::numeric_limits<float>::infinity();r.valid=r.snr>13;if(!r.valid&&!r.code)r.code=4;
                r.width=(right-left+1)*1730.f/r.bin;if(r.width>5882/r.bin+9.7f&&r.valid){r.valid=0;if(!r.code)r.code=5;}
            }else if(!r.code)r.code=2;
        }
        if(r.code)r.valid=0;r.amplitude=maxamp?amp*100/maxamp:std::numeric_limits<float>::quiet_NaN();
    }
    std::vector<float> slopes;
    for(int i=0;i<12;i++)if(result.partials[i].valid)for(int j=i+1;j<12;j++)if(result.partials[j].valid)slopes.push_back((result.partials[j].offset-result.partials[i].offset)/float((j+1)*(j+1)-(i+1)*(i+1)));
    if(!slopes.empty()){std::sort(slopes.begin(),slopes.end());result.ih=slopes[slopes.size()/2];float intercept=0;int count=0;for(int i=0;i<12;i++)if(result.partials[i].valid){intercept+=result.partials[i].offset-result.ih*float((i+1)*(i+1));count++;}intercept/=count;for(auto& r:result.partials)if(r.valid)r.offset-=intercept;}
    return result;
}
Keys profile(const Keys& values,const std::array<int,88>& counts){
    std::vector<int> x;std::vector<double> y;char text[64];for(int n=0;n<88;n++)if(counts[n]>0){x.push_back(n);std::snprintf(text,sizeof(text),"%5.3f",double(values[n]));y.push_back(std::max(.001,std::strtod(text,nullptr)));}
    Keys out{};int count=x.size();if(!count)return out;if(count==1){out.fill(y[0]);return out;}
    auto seg=[&](int n,int lo,int hi){double xa=x[lo],xb=x[hi],ya=y[lo],yb=y[hi],slope=std::log(yb/ya)/(xb-xa);if(std::abs(slope)<=double(.138692f))return ya*std::exp(slope*(n-xa));slope=std::copysign(double(.138692f),slope);double a=(yb-ya)/(std::exp(slope*xb)-std::exp(slope*xa)),c=ya-a*std::exp(slope*xa);return c+a*std::exp(slope*n);};
    for(int n=0;n<88;n++){int pos=std::lower_bound(x.begin(),x.end(),n)-x.begin(),hi=std::max(1,std::min(count-1,pos)),lo=hi-1;double value;
        if(n==x[hi]){out[n]=y[hi];continue;}
        if(pos==0||pos==count){if(x[hi]-x[lo]<10){if(pos==0){while(x[hi]-x[lo]<10&&hi<count-1)hi++;}else while(x[hi]-x[lo]<10&&lo>=2)lo--;}value=seg(n,lo,hi);}
        else {int midpoint=(x[lo]+x[hi])/2,half=(x[hi]-x[lo])/2,d=std::min(n-x[lo],x[hi]-n);value=seg(n,lo,hi);int a=-1,b=-1;if(n<midpoint&&hi>=3){a=hi-2;b=hi-1;}if(n>=midpoint&&hi+1<count){a=hi;b=hi+1;}if(a>=0)value=((half+d)*value+(half-d)*seg(n,a,b))/(2*half);}
        out[n]=std::min(20.,value);
    }return out;
}
Keys curve(const Keys& ih,int bass,int middle,int treble,int start,bool modern){
    if(bass<0||bass>15||middle<0||middle>15||treble<0||treble>15)throw std::invalid_argument("interval");
    Keys y{};auto delta=[&](int n,int p){return ih[n]*(beta(p,modern)-1);};auto mid=intervals[middle];int end=start+mid.g;if(start<=0||end>=88||end+1<intervals[treble].g||start-1+intervals[bass].g>=88)throw std::invalid_argument("middle region");
    float low=(delta(end,mid.q)+(mid.g&1?-1.955f:0))-delta(start,mid.p);
    for(int n=0;n<88;n++)y[n]=low+(n-start)*(-low)/(end-start);
    auto lower=[&](int n,int index){auto i=intervals[index];float v=y[n+i.g]+delta(n+i.g,i.q);if(i.g&1)v+=-1.955f;return v-delta(n,i.p);};
    auto upper=[&](int n,int index){auto i=intervals[index];return (y[n-i.g]+delta(n-i.g,i.p))-delta(n,i.q)-(i.g&1?-1.955f:0);};
    auto down=[&](){for(int n=start-1;n>=0;n--){float a=lower(n,bass),b=lower(n,middle);y[n]=a+(b-a)*n/start;}};
    auto up=[&](){for(int n=end+1;n<88;n++){float a=upper(n,middle),b=upper(n,treble);y[n]=a+(b-a)*(n-end)/(87-end);}};
    if(intervals[bass].g<intervals[treble].g){down();up();}else {up();down();}return y;
}
float stretch(const Keys& y,const Keys& ih,int n,int p,bool modern){return (y.at(n)+ih.at(n)*(beta(p,modern)-1))-y[48];}
Keys legacy(float b1,float k1,float b4,float k4){Keys out{};for(int n=0;n<88;n++)out[n]=b1*std::exp(double((n-40)/k1))-b4*std::exp(double((40-n)/k4));return out;}
static const float weights[]={0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.12f,0.126f,0.134f,0.14f,0.148f,0.154f,0.162f,0.168f,0.176f,0.182f,0.19f,0.196f,0.204f,0.21f,0.218f,0.224f,0.232f,0.238f,0.244f,0.252f,0.258f,0.266f,0.272f,0.28f,0.286f,0.294f,0.3f,0.308f,0.314f,0.322f,0.328f,0.336f,0.342f,0.35f,0.356f,0.364f,0.37f,0.37f,0.362f,0.356f,0.348f,0.342f,0.334f,0.328f,0.32f,0.314f,0.306f,0.3f,0.292f,0.284f,0.278f,0.27f,0.264f,0.256f,0.25f,0.242f,0.236f,0.228f,0.222f,0.214f,0.208f,0.2f,0.2f};
float overpull(const Overpull& s,int n,bool* limited){
    auto factor=[&](int note){int i=note<=s.bass?note*25/s.bass:std::min(87,(note-s.bass)*62/(87-s.bass)+25);return weights[i];};
    auto pre=[&](int note){if(s.present[note])return s.offsets[note];int lo=note-1,hi=note+1;while(lo>=0&&!s.present[lo])lo--;while(hi<88&&!s.present[hi])hi++;if(note<=s.bass&&s.bass<hi)hi=88;if(lo<=s.bass&&s.bass<note)lo=-1;if(lo>=0&&hi<88){float w=float(hi-note)/(hi-lo);return s.offsets[lo]*w+(1-w)*s.offsets[hi];}return lo>=0?s.offsets[lo]:hi<88?s.offsets[hi]:0.f;};
    auto cross=[&](int lo,int hi){return lo<=s.strut2&&s.strut2<hi?.4f:lo<=s.strut1&&s.strut1<hi?.3f:1.f;};
    if(n<0||n>87||s.bass<=0||s.bass>=87)throw std::invalid_argument("overpull");
    float total=0,denom=0,w=1;for(int d=0;d<20;d++){int hi=n+d,lo=n-d;if(hi<88){float err=pre(hi);if(n<=s.bass&&s.bass<hi)err*=.11f;total+=cross(n,hi)*err*w*factor(hi);}if(lo>=0){float a=factor(lo),err=pre(lo);if(lo<=s.bass&&s.bass<n)err*=.81f;total+=cross(lo,n)*err*w*(a*a);}denom+=w;w*=.894f;}float value=s.step*.05f*(-total/denom),limit=n<=s.wound?s.woundLimit:s.plainLimit;if(limited)*limited=value>limit;return std::min(value,limit);
}
Pitch pitch(const std::vector<int16_t>& pcm,double target,int selected,bool automatic){
    Pitch r;if(pcm.size()<4096||target<20||target>10000)return r;std::vector<float> samples(pcm.begin(),pcm.end());double energy=0;for(auto v:samples)energy+=v*v;if(std::sqrt(energy/samples.size())<25)return r;
    auto z=fft(samples);size_t n=z.size();std::vector<float> mag(n/2);float maximum=0;for(size_t k=1;k<n/2;k++){mag[k]=std::abs(z[k]);maximum=std::max(maximum,mag[k]);}
    r.spectrum.resize(256);for(int i=0;i<256;i++){int a=std::max(1,int(20*std::pow(500.,i/256.)*n/22050)),b=std::min(int(n/2)-1,int(20*std::pow(500.,(i+1)/256.)*n/22050));float v=0;for(int k=a;k<=b;k++)v=std::max(v,mag[k]);r.spectrum[i]=maximum?std::max(0.f,1+float(std::log10(std::max(1.f,v)/maximum))/5):0;}
    if(automatic){double best=0;int chosen=selected;for(int note=0;note<88;note++){double score=0;for(int p=1;p<=6;p++){double f=nominal(note)*p;if(f>9000)break;int k=std::round(f*n/22050);float v=0;for(int j=std::max(1,k-2);j<=std::min(int(n/2)-1,k+2);j++)v=std::max(v,mag[j]);score+=v/std::sqrt(double(p));}if(score>best){best=score;chosen=note;}}r.note=chosen;}
    else r.note=selected;
    int lo=std::max(1,int(target*.96*n/22050)),hi=std::min(int(n/2)-2,int(target*1.04*n/22050)),k=lo;
    for(int j=lo;j<=hi;j++)if(mag[j]>mag[k])k=j;if(k<=lo||k>=hi||mag[k]<maximum*.005)return r;
    double background=0;size_t backgroundCount=0;for(size_t j=1;j<mag.size();j++)if(std::abs(int(j)-k)>5){background+=mag[j];backgroundCount++;}if(backgroundCount&&mag[k]<8*background/backgroundCount)return r;
    float frac=peakOffset(std::complex<float>(z[k-1]),std::complex<float>(z[k]),std::complex<float>(z[k+1]));r.hz=(k+frac)*22050/n;r.cents=1200*std::log2(r.hz/target);r.amplitude=mag[k]/maximum;r.valid=std::isfinite(r.cents)&&std::abs(r.cents)<75;return r;
}
Resampler::Resampler(double sr):rate(sr){if(!std::isfinite(sr)||sr<22050||sr>192000)throw std::invalid_argument("sample rate");history.reserve(256);}
std::vector<int16_t> Resampler::feed(const float* samples,size_t count){
    std::vector<int16_t> out;out.reserve(count*22050/rate+2);auto quant=[](float v){return int16_t(std::max(-32768.,std::min(32767.,std::round(double(v)*32768))));};
    for(size_t i=0;i<count;i++){float v=std::isfinite(samples[i])?samples[i]:0;if(rate==44100){if(!hasPending){pending=v;hasPending=true;}else {out.push_back((int(quant(pending))+int(quant(v)))/2);hasPending=false;}continue;}if(rate==22050){out.push_back(quant(v));continue;}
        history.push_back(v);index++;if(history.size()>96)history.erase(history.begin());
        while(next<=index){double t=next-24,cut=.45*std::min(1.,22050/rate),sum=0,norm=0;long long center=std::floor(t);
            for(long long j=center-23;j<=center+24;j++){double d=t-j;if(std::abs(d)>=24)continue;double sinc=d==0?2*cut:std::sin(2*pi*cut*d)/(pi*d),w=sinc*(.5+.5*std::cos(pi*d/24));long long idx=j-(index+1-(long long)history.size());if(idx>=0&&idx<(long long)history.size())sum+=history[idx]*w;norm+=w;}out.push_back(quant(norm?sum/norm:0));next+=rate/22050;
        }
    }return out;
}
}
