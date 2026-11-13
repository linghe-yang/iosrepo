// NotePlane.clearToRetry drops the note animation worker and hides note bodies.
// Its separate wave/explosion pools still own the visible objects. Stave effects
// instead share the gameplay worker with the song clock, so cancel only their iterators.
using PianoEffect=Object(*)(Object,Object,bool,Method);
PianoEffect originalPianoEffect;
Step originalCharmingStep,originalPianoStep;
std::unordered_map<Object,bool> pianoEffects; // true after a timeline jump
uint32_t charmingHandle;

void releaseCharming() {
    if (charmingHandle) dropObject(charmingHandle);
    charmingHandle=0;
}
bool observeCharming(Object iterator,Method m) {
    bool more=originalCharmingStep(iterator,m);
    if (!chartReady || field<Object>(iterator,0x20)!=field<Object>(field<Object>(manager,managerUI),0xc0)) return more;
    if (charmingHandle && heldObject(charmingHandle)==iterator) {
        if (!more) releaseCharming();
    } else if (more) {
        releaseCharming();
        charmingHandle=retainObject(iterator,false);
    }
    return more;
}
Object makePianoEffect(Object owner,Object sound,bool background,Method m) {
    Object iterator=originalPianoEffect(owner,sound,background,m);
    if (chartReady && iterator && owner==field<Object>(manager,0x28)) pianoEffects[iterator]=false;
    return iterator;
}
bool stepPianoEffect(Object iterator,Method m) {
    auto it=pianoEffects.find(iterator);
    if (it!=pianoEffects.end() && it->second) {
        pianoEffects.erase(it);
        return false;
    }
    bool more=originalPianoStep(iterator,m);
    if (!more) pianoEffects.erase(iterator);
    return more;
}
void clearHitEffects() {
    Object combo=field<Object>(field<Object>(manager,managerUI),0xc0);
    Object charmingWorker=field<Object>(combo,0xa0);
    if (charmingWorker) at<Action>(Deemo::clearWorker)(charmingWorker,nullptr);
    Object iterator=charmingHandle?heldObject(charmingHandle):nullptr;
    if (iterator && field<Object>(iterator,0x20)==combo && field<Object>(iterator,0x30)) {
        // Enter the native fade-out's final frame. It preserves RGB, writes alpha
        // zero and finishes, even when the song itself is paused.
        writeField<int>(iterator,0x10,2);
        writeField<float>(iterator,0x28,field<float>(iterator,0x2c));
        originalCharmingStep(iterator,nullptr);
    }
    releaseCharming();

    for (auto &entry:pianoEffects) entry.second=true;
    std::unordered_set<Object> pools;
    for (size_t slot:{0x30,0x38,0x40}) {
        Object notes=field<Object>(currentPlane(),slot);
        pools.insert(field<Object>(notes,0x58));
        pools.insert(field<Object>(notes,0x60));
    }
    pools.insert(field<Object>(field<Object>(manager,0x28),0x10));
    for (Object pool:pools) {
        if (pool && field<Object>(pool,0x10)) at<Action>(Deemo::cleanEffectPool)(pool,nullptr);
    }
}
