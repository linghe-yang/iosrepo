#pragma once
#include <stdint.h>
#include <stddef.h>
// Offsets refer exclusively to the unmodified arm64 UnityFramework UUID below.
// These assertions also serve as the manifest for the offline IPA verifier.
namespace Deemo {
constexpr uint8_t uuid[] = {0x37,0xb8,0xf1,0x4d,0xcc,0xfd,0x33,0x58,0x8c,0x31,0xcb,0xe8,0x8f,0xf6,0x7b,0x2a};
struct Entry { uint32_t offset; uint32_t word; };
constexpr Entry mainStep{0xa6904,0x6dbb23e9}, playMusic{0xa58cc,0x6dbb23e9},
    leave{0xa4e6c,0xa9be4ff4}, end{0xa5fc4,0xa9be4ff4}, pause{0xa54f0,0xa9be4ff4},
    stopSource{0x180f06c,0xa9be4ff4}, playDelayed{0x180ef00,0x6dbd23e9},
    getDelta{0x183662c,0xa9be4ff4}, getTime{0x18365c4,0xa9be4ff4},
    noteStep{0x14e2c4,0xa9bd57f6}, bankPlay{0x14d534,0x6db92beb},
    getSamples{0x180ed9c,0xa9be4ff4}, setSamples{0x180eddc,0xa9bd57f6},
    clipSamples{0x180da24,0xa9be4ff4}, getClip{0x180ee2c,0xa9be4ff4}, clipHz{0x180da64,0xa9be4ff4},
    setPitch{0x180ed0c,0x6dbd23e9}, audioManager{0x201fd80,0xa9bf7bfd},
    ensureSourceGroups{0x2022eec,0xd10203ff}, createDSPByType{0x285581c,0xd100c3ff},
    setDSPParameter{0x2821460,0xd10103ff}, addDSP{0x27f8ccc,0xd100c3ff},
    removeDSP{0x2821224,0xd10083ff}, releaseDSP{0x28210d8,0xd10083ff},
    softwareFormat{0x28550c0,0xd10143ff};
constexpr Entry entries[]={mainStep,playMusic,leave,end,pause,stopSource,playDelayed,getDelta,getTime,noteStep,bankPlay,getSamples,setSamples,clipSamples,getClip,clipHz,setPitch,audioManager,ensureSourceGroups,createDSPByType,setDSPParameter,addDSP,removeDSP,releaseDSP,softwareFormat};
constexpr size_t coroutineOwner=0x20, managerSource=0x50, objectNative=0x10,
    systemSlot=0x178, sourceDryBus=0x380, sourcePitch=0x1f4;
constexpr int pitchShifterType=11;
}
