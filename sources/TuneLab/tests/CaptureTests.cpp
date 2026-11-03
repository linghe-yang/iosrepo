#include "../src/TLCapturePolicy.hpp"
#include "../src/TLPCMBlocks.hpp"
#include <iostream>
#include <limits>
#include <stdexcept>
#include <vector>

int main(){
    unsigned checks=0,partitions=0;
    auto check=[&](bool passed,const char *name){checks++;if(!passed)throw std::runtime_error(name);};
    using H=tl::CapturePolicy::Health;tl::CapturePolicy capture;
    check(capture.inspect(10,0,0,0,false)==H::Waiting,"idle does not restart");
    capture.request();capture.starting=true;
    check(capture.inspect(10,0,0,0,false)==H::Waiting,"permission/start is not a stalled engine");
    capture.starting=false;
    check(capture.inspect(10.5,10,10,10,true)==H::Waiting,"converter warmup");
    check(capture.inspect(13,10,12.9,12.9,true)==H::Healthy,"live capture");
    check(capture.inspect(13,10,12.9,12.9,false)==H::EngineStopped,"route/configuration engine stop detected");
    check(capture.requested&&capture.recover(),"route recovery preserves capture intent");
    capture.interrupted=true;
    check(capture.inspect(30,10,12,12,false)==H::Waiting,"interruption suspends watchdog");
    check(!capture.recover()&&capture.requested,"interruption does not lose capture intent");
    capture.interrupted=false;
    check(capture.recover(),"interruption end can restart");
    capture.stop();
    check(!capture.recover()&&!capture.requested,"background/explicit stop cancels pending recovery");
    capture.request();
    check(capture.inspect(15,10,10,10,true)==H::NoInput,"running engine without callbacks detected");
    check(capture.inspect(15,10,14.9,10,true)==H::NoConvertedOutput,"conversion starvation detected");
    check(capture.recover()&&capture.recover()&&capture.recover()&&!capture.recover(),"failed recovery is bounded");
    capture.request();check(capture.recoveries==0&&capture.requested,"manual retry clears failure budget");

    for(int value=-32768;value<=32767;value++)check(tl::pcm16(float(value)/32768.f)==value,"all int16 amplitudes survive normalization/quantization");
    check(tl::pcm16(2)==32767&&tl::pcm16(-2)==-32768,"clipping");
    check(tl::pcm16(std::numeric_limits<float>::quiet_NaN())==0&&tl::pcm16(std::numeric_limits<float>::infinity())==0,"nonfinite input");
    check(tl::pcm16(1.f/65536)==1&&tl::pcm16(-1.f/65536)==-1,"halfway rounding");

    std::vector<int16_t> input(2048*64+733);for(size_t i=0;i<input.size();i++)input[i]=int16_t((i*739+37)&65535);
    for(size_t chunk:{1,2,127,128,256,480,512,882,1024,1600,1764,2048,3072,4096,8192}){
        tl::PCMBlocks blocks;int16_t *registered=blocks.data();size_t consumed=0,offset=0;
        while(offset<input.size()){
            size_t count=std::min(chunk,input.size()-offset);
            blocks.append(input.data()+offset,count,[&]{check(blocks.data()==registered,"registered native input address stays stable");check(std::equal(blocks.frame.begin(),blocks.frame.end(),input.begin()+consumed),"no samples duplicated/lost/reordered across variable callback sizes");consumed+=2048;});
            offset+=count;
        }
        check(consumed==2048*64&&blocks.used==733,"complete blocks only; remainder retained");partitions++;
    }
    tl::PCMBlocks blocks;std::vector<int16_t> old(511,111),fresh(2048,222);unsigned complete=0;
    blocks.append(old.data(),old.size(),[&]{complete++;});blocks.reset();
    blocks.append(fresh.data(),fresh.size(),[&]{complete++;check(std::equal(blocks.frame.begin(),blocks.frame.end(),fresh.begin()),"new audio session cannot contain stale partial block");});
    check(complete==1,"reset does not emit an incomplete block");
    std::cout<<"{\"passed\":true,\"checks\":"<<checks<<",\"callback_partition_cases\":"<<partitions<<",\"all_int16_values_verified\":true,\"route_interruption_watchdog_and_reset_verified\":true,\"apple_audio_converter_executed\":false}"<<std::endl;
}
