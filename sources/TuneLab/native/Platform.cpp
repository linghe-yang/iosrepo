// Android platform-boundary adapters. Mathematical/signal processing code remains original.
#include "OriginalDSP.hpp"
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <cstdint>
#include <mutex>
#include <cerrno>
extern "C" unsigned char TLNativeROM[],TLNativeRAM[];
extern "C" int __cxa_atexit(void(*)(void*),void*,void*);
extern "C" void __cxa_finalize(void*);
extern "C" void __stack_chk_fail();
struct TLFixup{uint32_t offset;uint64_t value;const char* symbol;};
#include "Fixups.inc"
static void* jniTable[240]{};
static void** jniEnvironment=jniTable;
extern "C" void* TLNativeEnvironment(){return &jniEnvironment;}
extern "C" void* TLNativeAddress(uint32_t address){return address<0x14000?TLNativeROM+address:TLNativeRAM+address-0x14000;}
static void* directAddress(void*,void* buffer){return buffer;}
struct AndroidVaList{unsigned char *stack,*grTop,*vrTop;int32_t grOffset,vrOffset;};
static int formatAndroid(char* destination,int flags,size_t maxLength,const char* format,AndroidVaList* args){
    if(std::strcmp(format,"%5.3f")!=0){if(maxLength)destination[0]=0;errno=EINVAL;return -1;}
    double value;std::memcpy(&value,args->vrOffset<0?args->vrTop+args->vrOffset:args->stack,sizeof(value));
    return std::snprintf(destination,maxLength,format,value);
}
static int scanAndroid(const char* text,const char* format,float* output){if(std::strcmp(format,"%f")!=0){errno=EINVAL;return 0;}return std::sscanf(text,format,output);}
static int timeAndroid(int clock,struct timespec* value){if(clock==1)return ::clock_gettime(CLOCK_MONOTONIC,value);if(clock==0)return ::clock_gettime(CLOCK_REALTIME,value);errno=EINVAL;return -1;}
static int bitmapInfo(void*,TLNativeBitmap* bitmap,void* output){if(!bitmap||!output)return -1;std::memcpy(output,bitmap,5*sizeof(uint32_t));return 0;}
static int bitmapLock(void*,TLNativeBitmap* bitmap,void** output){if(!bitmap||!output||!bitmap->pixels)return -1;*output=bitmap->pixels;return 0;}
static int bitmapUnlock(void*,TLNativeBitmap*){return 0;}
template<typename T> static void* pointer(T fn){return reinterpret_cast<void*>(reinterpret_cast<uintptr_t>(fn));}
static void* host(const char* name){
    if(!std::strcmp(name,"expf"))return pointer(&::expf);
    if(!std::strcmp(name,"exp"))return pointer(static_cast<double(*)(double)>(&::exp));
    if(!std::strcmp(name,"logf"))return pointer(&::logf);
    if(!std::strcmp(name,"log"))return pointer(static_cast<double(*)(double)>(&::log));
    if(!std::strcmp(name,"sin"))return pointer(static_cast<double(*)(double)>(&::sin));
    if(!std::strcmp(name,"atan"))return pointer(static_cast<double(*)(double)>(&::atan));
    if(!std::strcmp(name,"memcpy"))return pointer(&::memcpy);
    if(!std::strcmp(name,"qsort"))return pointer(&::qsort);
    if(!std::strcmp(name,"__vsprintf_chk"))return pointer(&formatAndroid);
    if(!std::strcmp(name,"sscanf"))return pointer(&scanAndroid);
    if(!std::strcmp(name,"clock_gettime"))return pointer(&timeAndroid);
    if(!std::strcmp(name,"AndroidBitmap_getInfo"))return pointer(&bitmapInfo);
    if(!std::strcmp(name,"AndroidBitmap_lockPixels"))return pointer(&bitmapLock);
    if(!std::strcmp(name,"AndroidBitmap_unlockPixels"))return pointer(&bitmapUnlock);
    if(!std::strcmp(name,"__cxa_finalize"))return pointer(&::__cxa_finalize);
    if(!std::strcmp(name,"__cxa_atexit"))return pointer(&::__cxa_atexit);
    if(!std::strcmp(name,"__stack_chk_fail"))return pointer(&::__stack_chk_fail);
    std::abort(); // Unknown platform imports must never silently return success.
}
extern "C" void TLNativeInitialize(){
    static std::once_flag initialized;
    std::call_once(initialized,[]{
        uint64_t guard=0;arc4random_buf(&guard,sizeof(guard));std::memcpy(TLNativeRAM+0x28,&guard,sizeof(guard));
        for(const auto& fix:kFixups){uintptr_t value=fix.symbol?reinterpret_cast<uintptr_t>(host(fix.symbol))+fix.value:reinterpret_cast<uintptr_t>(TLNativeAddress(fix.value));std::memcpy(TLNativeRAM+fix.offset,&value,sizeof(value));}
        jniTable[0x730/sizeof(void*)]=pointer(&directAddress);
    });
}
