// Included in Adapter.mm's namespace. Unity object references below are scoped to
// the current chart. All callbacks which touch this state run on the Unity/UI main thread.
using PairAction = void (*)(Object,Object,Method);
using FloatAction = void (*)(Object,float,Method);
using Spawn = Object (*)(Object,Object,Method);
using JudgeCall = void (*)(Object,bool,Method);
Action originalUpdate,originalRetry;
Action originalNoteSound;
FloatAction originalAddRatio;
PairAction originalSendSound;
Spawn originalSpawn,originalMakeKey;
JudgeCall originalJudge;
struct SoundEvent { Object sound; float time; };
struct DeferredKey { unsigned epoch; bool continuing; float remaining; };
std::unordered_map<Object,DeferredKey> pendingKeys;
std::vector<SoundEvent> soundLog;
std::vector<SoundEvent> backingLog;
unsigned audioEpoch=1;
bool rescheduling,transportSeek;
float remainingWait;
practice::Journal journal;
std::vector<practice::Note> chartNotes;
std::unordered_map<uintptr_t,size_t> noteIndices;
std::unordered_set<uintptr_t> rebuildSkip;
bool chartReady,historyOK,dragging,beginRequested,finishRequested,cancelRequested;
bool previewing,blockPast;
float originSec,lowestSec,positionSec,aimSec,durationSec,progressSec;
double previousTick;
Object judgingInfo;
unsigned transportID;
constexpr size_t managerPlane=0x38, managerResult=0x58, managerUI=0x40, planeParams=0x10;

template<class T> void writeField(Object object,size_t offset,T value) {
    memcpy(static_cast<char*>(object)+offset,&value,sizeof value);
}
Object currentPlane() { return field<Object>(manager,managerPlane); }
float songClock() { return field<float>(field<Object>(currentPlane(),planeParams),0x10); }
void abandonGesture() {
    dragging=beginRequested=finishRequested=cancelRequested=previewing=false;
}
void resetTransport() {
    ++transportID;++audioEpoch;
    abandonGesture();
    chartReady=false;historyOK=true;blockPast=false;
    journal={};chartNotes.clear();noteIndices.clear();soundLog.clear();backingLog.clear();rebuildSkip.clear();
    durationSec=progressSec=positionSec=aimSec=0;
    // Pending coroutines can survive a retry. Their generation invalidates them
    // until their next step; a newly allocated enumerator always replaces its entry.
    pendingKeys.clear();
}

bool loadChart() {
    Object plane=currentPlane(),result=field<Object>(manager,managerResult);
    Object chart=field<Object>(plane,0x58),list=field<Object>(chart,0x18);
    Object array=field<Object>(list,0x10);
    int count=field<int>(list,0x18);
    Object clip=at<Object(*)(Object,Method)>(Deemo::getClip)(source,nullptr);
    if (!clip || count<1 || count>200000 || !array || !result ||
        !field<Object>(manager,managerUI) || !field<Object>(plane,planeParams) ||
        field<uintptr_t>(array,0x18)<static_cast<unsigned>(count)) return false;
    float duration=at<float(*)(Object,Method)>(Deemo::clipLength)(clip,nullptr);
    if (!std::isfinite(duration) || duration<=0) return false;
    chartNotes.clear();noteIndices.clear();
    int scored=0;
    for (int i=0;i<count;++i) {
        Object info=field<Object>(array,0x20+i*sizeof(Object));
        if (!info) return false;
        float t=field<float>(info,0x38)+field<float>(info,0x3c);
        float x=field<float>(info,0x30);
        if (!std::isfinite(t) || !std::isfinite(x) || (!chartNotes.empty() && t<chartNotes.back().time)) return false;
        auto id=reinterpret_cast<uintptr_t>(info);
        if (!noteIndices.emplace(id,i).second) return false;
        bool playable=x>=-2 && x<=2;
        scored+=playable;
        chartNotes.push_back({id,t,playable});
    }
    if (scored!=field<int>(result,0x1c) || field<int>(result,0x20)!=0) return false;
    durationSec=duration;
    return true;
}

void judge(Object note,bool hit,Method method) {
    if (previewing) return;
    if (!chartReady) {originalJudge(note,hit,method);return;}
    Object previous=judgingInfo;
    judgingInfo=field<Object>(note,0x60);
    originalJudge(note,hit,method);
    judgingInfo=previous;
}
void addRatio(Object result,float ratio,Method method) {
    if (previewing) return;
    if (manager && chartReady && result==field<Object>(manager,managerResult)) {
        auto id=reinterpret_cast<uintptr_t>(judgingInfo);
        if (noteIndices.find(id)==noteIndices.end() || !journal.record(id,songClock(),ratio))
            historyOK=false; // Refuse a later seek instead of dropping a real native judgement.
    }
    originalAddRatio(result,ratio,method);
}
Object spawn(Object plane,Object info,Method method) {
    if (plane==currentPlane() && (blockPast || previewing)) {
        uintptr_t id=reinterpret_cast<uintptr_t>(info);
        if (rebuildSkip.count(id)) return nullptr;
        if (previewing) {
            auto it=noteIndices.find(id);
            if (it!=noteIndices.end() && chartNotes[it->second].time<positionSec) return nullptr;
        }
    }
    return originalSpawn(plane,info,method);
}
void noteSound(Object note,Method method) {
    if (previewing) return;
    if (!chartReady) {originalNoteSound(note,method);return;}
    Object info=field<Object>(note,0x60);
    if (chartReady && field<float>(info,0x30)>2 && noteIndices.count(reinterpret_cast<uintptr_t>(info)))
        backingLog.push_back({info,songClock()});
    originalNoteSound(note,method);
}
void sendSound(Object owner,Object sound,Method method) {
    if (previewing) return;
    if (manager==owner && sound && chartReady && !rescheduling) soundLog.push_back({sound,songClock()});
    originalSendSound(owner,sound,method);
}
Object makeKey(Object player,Object sound,Method method) {
    Object enumerator=originalMakeKey(player,sound,method);
    if (manager && player==field<Object>(manager,0x20) && enumerator)
        pendingKeys[enumerator]={audioEpoch,rescheduling,remainingWait};
    return enumerator;
}
void stopKeyVoices() {
    ++audioEpoch;
    Object bank=field<Object>(field<Object>(manager,0x20),0x10);
    if (!bank) return;
    Object worker=field<Object>(bank,0x50),pool=field<Object>(bank,0x28);
    if (worker) at<Action>(Deemo::clearWorker)(worker,nullptr);
    uintptr_t count=field<uintptr_t>(pool,0x18);
    if (!pool || count>4096) return;
    for (uintptr_t i=0;i<count;i++) {
        Object voice=field<Object>(pool,0x20+i*sizeof(Object));
        if (!field<Object>(voice,Deemo::objectNative)) continue;
        originalStop(voice,nullptr);
        at<void(*)(Object,bool,Method)>(Deemo::enableBehaviour)(voice,false,nullptr);
    }
    writeField<int>(bank,0x34,0);
}
void recoverKeys(float target) {
    soundLog.erase(std::remove_if(soundLog.begin(),soundLog.end(),
                    [&](const SoundEvent& e){return e.time>target;}),soundLog.end());
    rescheduling=true;
    for (const auto& e:soundLog) {
        remainingWait=e.time+field<float>(e.sound,0x10)-target;
        if (remainingWait>0) originalSendSound(manager,e.sound,nullptr);
    }
    rescheduling=false;
}
void restoreScore() {
    Object result=field<Object>(manager,managerResult),ui=field<Object>(manager,managerUI);
    at<Action>(Deemo::resetResult)(result,nullptr);
    for (auto event:journal.decisions) originalAddRatio(result,event.ratio,nullptr);
    at<Action>(Deemo::resetUI)(ui,nullptr);
    int combo=field<int>(result,0x18),count=field<int>(result,0x20);
    float last=journal.decisions.empty()?0:journal.decisions.back().ratio;
    at<void(*)(Object,int,float,Method)>(Deemo::comboUI)(ui,combo,last,nullptr);
    at<void(*)(Object,bool,bool,Method)>(Deemo::comboStatus)(ui,field<int>(result,0x10)==count,combo==count,nullptr);
    int score=at<Integer>(Deemo::scoreValue)(result,nullptr);
    at<FloatAction>(Deemo::scoreUI)(ui,floorf(score*.01f),nullptr);
}
void rebuildPlane(float target,bool preview) {
    Object plane=currentPlane();
    at<Action>(Deemo::clearPlane)(plane,nullptr);
    rebuildSkip.clear();
    if (!preview) {
        rebuildSkip=journal.done;
        for (auto e:backingLog) rebuildSkip.insert(reinterpret_cast<uintptr_t>(e.sound));
    }
    size_t i=0;
    if (preview) {
        auto first=std::lower_bound(chartNotes.begin(),chartNotes.end(),target,
                    [](const practice::Note& n,float t){return n.time<t;});
        i=static_cast<size_t>(first-chartNotes.begin());
    } else {
        for (;i<chartNotes.size();++i) {
            const auto& n=chartNotes[i];
            if (n.time>=target) break;
            if (rebuildSkip.count(n.id) || field<float>(reinterpret_cast<Object>(n.id),0x30)<-2) continue;
            break; // Overdue but still pending at the selected instant.
        }
    }
    writeField<int>(plane,0x60,(int)i);
    blockPast=true;
    at<FloatAction>(Deemo::updatePlaneTime)(plane,target,nullptr);
    if (preview) at<Action>(Deemo::stepPlane)(plane,nullptr);
    // Keep the skip set in force for already-scored early hits not yet spawned.
}
void finishScrub() {
    float target=cancelRequested?originSec:positionSec;
    float branch=cancelRequested?originSec:std::min(lowestSec,target);
    journal.move(originSec,branch,chartNotes);
    journal.move(branch,target,chartNotes);
    backingLog.erase(std::remove_if(backingLog.begin(),backingLog.end(),
                        [&](const SoundEvent& e){return e.time>branch;}),backingLog.end());
    if (target>branch) {
        std::unordered_set<Object> consumed;
        for (auto e:backingLog) consumed.insert(e.sound);
        for (const auto& n:chartNotes) {
            if (n.time>=target) break;
            Object info=reinterpret_cast<Object>(n.id);
            if (!n.scored && field<float>(info,0x30)>2 && consumed.insert(info).second)
                backingLog.push_back({info,std::nextafter(std::max(n.time,branch),target)});
        }
    }
    previewing=false;
    restoreScore();
    rebuildPlane(target,false);
    keyEpoch=originalTime(nullptr);
    soundLog.erase(std::remove_if(soundLog.begin(),soundLog.end(),
                  [&](const SoundEvent& e){return e.time>branch;}),soundLog.end());
    recoverKeys(target);
    abandonGesture();
    progressSec=target;
    if (!paused) {
        transportSeek=true;
        onPlay(manager,nullptr);
        transportSeek=false;
    }
}
void updateTransport(Object owner,Method method) {
    if (!manager || owner!=manager || !chartReady) {
        originalUpdate(owner,method);return;
    }
    if (beginRequested) {
        beginRequested=false;
        if (historyOK && !paused && field<int>(field<Object>(manager,managerResult),0x20)==(int)journal.decisions.size()) {
            lowestSec=originSec=positionSec=std::clamp(songClock(),0.f,durationSec);
            dragging=previewing=true;
            at<Action>(Deemo::pauseAudio)(source,nullptr);
            stopKeyVoices();
            previousTick=CACurrentMediaTime();
        } else {
            abandonGesture();
        }
    }
    if (dragging) {
        double now=CACurrentMediaTime();
        float next=finishRequested ? positionSec : practice::follow(positionSec,aimSec,durationSec,now-previousTick);
        previousTick=now;
        if (!cancelRequested && fabsf(next-positionSec)>1.e-6f) {
            bool backward=next<positionSec;
            positionSec=next;
            lowestSec=std::min(lowestSec,next);
            if (backward) rebuildPlane(next,true);
            else {
                // Reuse active pooled objects in the forward direction, allowing the
                // actual game's position coroutines to scroll the chart every frame.
                at<FloatAction>(Deemo::updatePlaneTime)(currentPlane(),next,nullptr);
                at<Action>(Deemo::stepPlane)(currentPlane(),nullptr);
            }
        }
        if (paused) cancelRequested=true;
        if (finishRequested || cancelRequested) finishScrub();
        return;
    }
    originalUpdate(owner,method);
    if (manager==owner && chartReady) progressSec=std::clamp(songClock(),0.f,durationSec);
}
void retrySong(Object owner,Method method) {
    if (manager==owner) endSong();
    originalRetry(owner,method);
}
