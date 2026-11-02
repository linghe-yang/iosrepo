/* Shared by the desktop app and SpringBoard. No ObjC or constant CFStrings. */
#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <stdbool.h>
#include "StoreLimits.h"
#define SB_DIRECTORY "/var/mobile/Library/ShadeBar"
#define SB_SETTINGS SB_DIRECTORY "/settings.plist"
static inline CFStringRef SBString(const char *s) {
    return CFStringCreateWithCString(NULL,s,kCFStringEncodingUTF8);
}
static inline CFDictionaryRef SBStoreCopy(void) {
    CFDictionaryRef result=NULL;
    FILE *file=fopen(SB_SETTINGS,"rb");
    if(file) {
        if(fseek(file,0,SEEK_END)==0) {
            long length=ftell(file);
            if(length>0 && SBStoreSizeAllowed((size_t)length) && fseek(file,0,SEEK_SET)==0) {
                UInt8 *buffer=malloc((size_t)length);
                if(buffer) {
                    if(fread(buffer,1,(size_t)length,file)==(size_t)length) {
                        CFDataRef data=CFDataCreate(NULL,buffer,length);
                        CFPropertyListRef plist=CFPropertyListCreateWithData(NULL,data,kCFPropertyListImmutable,NULL,NULL);
                        if(plist && CFGetTypeID(plist)==CFDictionaryGetTypeID()) result=(CFDictionaryRef)plist;
                        else if(plist) CFRelease(plist);
                        CFRelease(data);
                    }
                    free(buffer);
                }
            }
        }
        fclose(file);
        // Never fall back to stale preferences when a shared file exists but is corrupt.
    } else if(errno==ENOENT) {
        CFStringRef domain=SBString("com.linghe.shadebar");
        CFPreferencesSynchronize(domain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
        result=CFPreferencesCopyMultiple(NULL,domain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
        CFRelease(domain);
    }
    return result?:CFDictionaryCreate(NULL,NULL,NULL,0,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
}
static inline void SBStoreMerge(const void *key,const void *value,void *context) {
    CFDictionarySetValue((CFMutableDictionaryRef)context,key,value);
}
static inline Boolean SBStoreWrite(CFDictionaryRef changes) {
    if(mkdir(SB_DIRECTORY,0700)!=0 && errno!=EEXIST) return false;
    int lock=open(SB_DIRECTORY "/settings.lock",O_CREAT|O_RDWR,0600);
    if(lock<0) return false;
    if(flock(lock,LOCK_EX)!=0) {close(lock);return false;}
    struct stat existing;
    if(stat(SB_SETTINGS,&existing)==0 && !SBStoreSizeAllowed((size_t)existing.st_size)) {flock(lock,LOCK_UN);close(lock);return false;}
    CFDictionaryRef old=SBStoreCopy();
    CFMutableDictionaryRef merged=CFDictionaryCreateMutableCopy(NULL,0,old);
    CFRelease(old);
    CFDictionaryApplyFunction(changes,SBStoreMerge,merged);
    CFDataRef data=CFPropertyListCreateData(NULL,merged,kCFPropertyListBinaryFormat_v1_0,0,NULL);
    CFRelease(merged);
    Boolean success=false;
    if(data && SBStoreSizeAllowed((size_t)CFDataGetLength(data))) {
        char path[]=SB_SETTINGS ".XXXXXX";
        int fd=mkstemp(path);
        if(fd>=0) {
            size_t count=(size_t)CFDataGetLength(data),offset=0;
            while(offset<count) {
                ssize_t n=write(fd,CFDataGetBytePtr(data)+offset,count-offset);
                if(n<0 && errno==EINTR) continue;
                if(n<=0) break;
                offset+=(size_t)n;
            }
            int syncResult=fsync(fd);close(fd);
            if(offset==count && syncResult==0 && rename(path,SB_SETTINGS)==0) success=true;
            if(!success) unlink(path);
        }
    }
    if(data) CFRelease(data);
    flock(lock,LOCK_UN);close(lock);return success;
}
