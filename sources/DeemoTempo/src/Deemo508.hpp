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
constexpr Entry managerUpdate{0xa4bb4,0xa9be4ff4};
constexpr Entry unscaledDelta{0x1836694,0xa9be4ff4};
constexpr Entry judgeNote{0xcb6c4,0x6dbb2beb};
constexpr Entry clickNote{0xcb5f4,0xa9be4ff4};
constexpr Entry addRatio{0xb12d4,0xb9402008};
constexpr Entry activeNote{0xd14e4,0x6dbc23e9};
constexpr Entry clearPlane{0xd0e40,0xa9bd57f6};
constexpr Entry updatePlaneTime{0xd1728,0x6dbb23e9};
constexpr Entry stepPlane{0xd18f0,0xa9be4ff4};
constexpr Entry resetResult{0xb11d4,0xb9401c08};
constexpr Entry scoreValue{0xb0f78,0x6dbd23e9};
constexpr Entry resetUI{0xa5d3c,0x6dbb2beb};
constexpr Entry comboUI{0xa7ae4,0x6dbc23e9};
constexpr Entry comboStatus{0xaa980,0xa9bd57f6};
constexpr Entry scoreUI{0xaaaa8,0xd10103ff};
constexpr Entry clearWorker{0xb59c0,0xa9be4ff4};
constexpr Entry enableBehaviour{0x181292c,0xa9bd57f6};
constexpr Entry pauseAudio{0x180f0b0,0xa9be4ff4};
constexpr Entry noteSound{0xcb92c,0xa9be4ff4};
constexpr Entry keyEnumerator{0x14e1f4,0xa9bd57f6};
constexpr Entry retry{0xa5c50,0xa9be4ff4};
constexpr Entry sendSound{0xa4ee8,0xa9bd57f6};
constexpr Entry clipLength{0x180d9e4,0xa9be4ff4};
constexpr Entry setupNote{0xcafc4,0xa9bd57f6};
constexpr Entry positionIterator{0xcb394,0xa9be4ff4};
constexpr Entry positionStep{0xcca14,0xd101c3ff};
constexpr Entry setNoteObjectActive{0xa3794,0xa9bf7bfd};
constexpr Entry activeTime{0xa7e98,0xa9be4ff4};
constexpr Entry setSongTime{0xa7e10,0xbd001000};
constexpr Entry cleanEffectPool{0xa3a6c,0xa9bd57f6}, charmingStep{0x801a0,0x6dbc23e9},
    pianoEffect{0x151280,0xa9bd57f6}, pianoEffectStep{0x15132c,0xd10183ff};
constexpr Entry endStep{0xa63ec,0xa9be4ff4},linkEndStep{0xa659c,0xa9be4ff4},
    resultInit{0x134a04,0xa9be4ff4},resetCount{0xb121c,0x1e620020};
constexpr Entry entries[]={mainStep,playMusic,leave,end,pause,stopSource,playDelayed,getDelta,getTime,noteStep,bankPlay,getSamples,setSamples,clipSamples,getClip,clipHz,setPitch,audioManager,ensureSourceGroups,createDSPByType,setDSPParameter,addDSP,removeDSP,releaseDSP,softwareFormat,managerUpdate,judgeNote,clickNote,addRatio,activeNote,clearPlane,updatePlaneTime,stepPlane,resetResult,scoreValue,resetUI,comboUI,comboStatus,scoreUI,clearWorker,enableBehaviour,pauseAudio,noteSound,keyEnumerator,retry,sendSound,clipLength,setupNote,positionIterator,positionStep,setNoteObjectActive,activeTime,setSongTime,endStep,linkEndStep,resultInit,resetCount,unscaledDelta,cleanEffectPool,charmingStep,pianoEffect,pianoEffectStep};
constexpr size_t coroutineOwner=0x20, managerSource=0x50, objectNative=0x10,
    systemSlot=0x178, sourceDryBus=0x380, sourcePitch=0x1f4;
constexpr int pitchShifterType=11;
}
