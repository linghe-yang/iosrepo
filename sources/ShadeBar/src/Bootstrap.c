/* SpringBoard entry point: C only, no Objective-C classes or constant strings.
 * The renderer is loaded only after an explicit desktop-app start request.
 */
#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>

#define DIRECTORY "/var/mobile/Library/ShadeBar"
#define GUARD DIRECTORY "/loading.guard"
#define STATUS DIRECTORY "/status.plist"
#define RENDERER "/var/jb/Applications/ShadeBar.app/Frameworks/ShadeRenderer.dylib"
static void *renderer;
static int starting;
static int renderer_ready;
static CFStringRef string(const char *s) {return CFStringCreateWithCString(NULL,s,kCFStringEncodingUTF8);}
static void status(const char *state,const char *detail) {
    CFStringRef keys[3]={string("state"),string("detail"),string("time")};
    char timestamp[32];snprintf(timestamp,sizeof(timestamp),"%lld",(long long)time(NULL));
    CFStringRef values[3]={string(state),string(detail?detail:""),string(timestamp)};
    CFDictionaryRef dict=CFDictionaryCreate(NULL,(const void **)keys,(const void **)values,3,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
    CFDataRef bytes=CFPropertyListCreateData(NULL,dict,kCFPropertyListXMLFormat_v1_0,0,NULL);
    if(bytes) {
        int fd=open(STATUS ".tmp",O_WRONLY|O_CREAT|O_TRUNC,0600);
        if(fd>=0) {size_t size=(size_t)CFDataGetLength(bytes);ssize_t written=write(fd,CFDataGetBytePtr(bytes),size);fsync(fd);close(fd);if(written==(ssize_t)size) rename(STATUS ".tmp",STATUS);}
        CFRelease(bytes);
    }
    CFRelease(dict);for(int i=0;i<3;i++){CFRelease(keys[i]);CFRelease(values[i]);}
}
static void enabled(int value) {
    CFStringRef domain=string("com.linghe.shadebar"),key=string("enabled");
    CFPreferencesSetValue(key,value?kCFBooleanTrue:kCFBooleanFalse,domain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
    CFPreferencesSynchronize(domain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
    CFRelease(domain);CFRelease(key);
}
static void start(void *unused) {
    if(starting) return;
    if(renderer_ready) {status("running","Renderer already loaded; settings notification applies changes.");return;}
    starting=1;
    status("loading","Loading the renderer after a manual request.");
    int fd=open(GUARD,O_WRONLY|O_CREAT|O_TRUNC,0600);
    if(fd<0) {status("failed","Could not create startup guard.");starting=0;enabled(0);return;}
    const char *note="Manual renderer initialization has not completed.\n";
    (void)write(fd,note,strlen(note));fsync(fd);close(fd);
    if(!renderer) renderer=dlopen(RENDERER,RTLD_NOW|RTLD_LOCAL);
    if(!renderer) {const char *error=dlerror();status("failed",error?error:"dlopen failed");enabled(0);starting=0;return;}
    int (*entry)(void)=dlsym(renderer,"ShadeRendererStart");
    if(!entry || !entry()) {status("failed","Renderer initialization failed; inspect renderer-error.txt.");enabled(0);starting=0;return;}
    renderer_ready=1;unlink(GUARD);status("running","Renderer initialization returned successfully.");starting=0;
}
static void requested(CFNotificationCenterRef center,void *observer,CFStringRef name,const void *object,CFDictionaryRef info) {
    dispatch_async_f(dispatch_get_main_queue(),NULL,start);
}
static void setup(void *unused) {
    mkdir(DIRECTORY,0700);
    enabled(0); // Never restore the previous enabled flag during SpringBoard startup.
    status(access(GUARD,F_OK)==0?"guarded":"ready","Desktop app must explicitly start the overlay after each SpringBoard launch.");
    CFStringRef name=string("com.linghe.shadebar.start");
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,requested,name,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    CFRelease(name);
}
__attribute__((constructor)) static void bootstrap(void) {
    dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),NULL,setup);
}
