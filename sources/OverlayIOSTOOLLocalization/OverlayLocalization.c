/* Runtime UI localization for the hash-pinned OverlayIOSTOOL 5.8.12 images.
 * Only whitelisted image UUIDs and explicitly listed UI literals are changed.
 * No Objective-C swizzling, network requests, configuration-key changes or hooks
 * into unrelated apps. Host code and notification identifiers stay untouched.
 * SDK-independent declarations allow an audited freestanding ARM64 build.
 */
typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;
typedef __UINTPTR_TYPE__ uptr;
typedef __INTPTR_TYPE__ iptr;

struct ConstantString {
    const void *isa;
    u64 flags;
    const void *characters;
    u64 length;
};
struct Translation {
    const u16 *source;
    u64 source_length;
    const u16 *english;
    u64 english_length;
    const u16 *chinese;
    u64 chinese_length;
};
struct Header64 { u32 magic, cpu, subtype, type, ncmds, sizeofcmds, flags, reserved; };
struct Command { u32 cmd, size; };
struct Segment64 {
    u32 cmd, size;
    char name[16];
    u64 vmaddr, vmsize, fileoff, filesize;
    u32 maxprot, initprot, nsects, flags;
};
struct Section64 {
    char name[16], segment[16];
    u64 address, size;
    u32 offset, align, reloff, nreloc, flags, reserved1, reserved2, reserved3;
};

extern const void *CFLocaleCopyPreferredLanguages(void);
extern long CFArrayGetCount(const void *array);
extern const void *CFArrayGetValueAtIndex(const void *array, long index);
extern u8 CFStringGetCString(const void *string, char *buffer, long size, u32 encoding);
extern void CFRelease(const void *object);
extern int mprotect(void *address, uptr size, int protection);
extern int getpagesize(void);
extern void _dyld_register_func_for_add_image(void (*callback)(const struct Header64 *, iptr));

#include "translations_generated.h"

static u32 chinese_enabled;

static int equal_name(const char *a, const char *b) {
    for (u32 i = 0; i < 16; ++i) {
        if (a[i] != b[i]) return 0;
        if (!a[i]) return 1;
    }
    return 1;
}

static char normalized(char c) {
    if (c == '_') return '-';
    return c >= 'A' && c <= 'Z' ? (char)(c + ('a' - 'A')) : c;
}

int ol_should_use_chinese(const char *language) {
    if (!language) return 0;
    char tag[64];
    u32 count = 0;
    for (; language[count] && count < 63; ++count) tag[count] = normalized(language[count]);
    tag[count] = 0;
    if (count < 2 || tag[0] != 'z' || tag[1] != 'h') return 0;
    if (count <= 2 || tag[2] != '-') return 0;
    /* Explicit script takes precedence over the country/region subtag. */
    for (u32 i = 3; i < count;) {
        u32 start = i;
        while (i < count && tag[i] != '-') ++i;
        u32 length = i - start;
        if (length == 4 && tag[start] == 'h' && tag[start+1] == 'a' && tag[start+2] == 'n') {
            if (tag[start+3] == 's') return 1;
            if (tag[start+3] == 't') return 0;
        }
        ++i;
    }
    for (u32 i = 3; i < count;) {
        u32 start = i;
        while (i < count && tag[i] != '-') ++i;
        if (i - start == 2 && ((tag[start] == 'c' && tag[start+1] == 'n') ||
                              (tag[start] == 's' && tag[start+1] == 'g'))) return 1;
        ++i;
    }
    return 0;
}

static int matches(const struct ConstantString *literal, const struct Translation *translation) {
    if (!literal->characters || literal->length != translation->source_length) return 0;
    if (literal->flags == 0x7d0) {
        const u16 *characters = literal->characters;
        for (u64 i = 0; i < literal->length; ++i)
            if (characters[i] != translation->source[i]) return 0;
        return 1;
    }
    if (literal->flags == 0x7c8) {
        const u8 *characters = literal->characters;
        for (u64 i = 0; i < literal->length; ++i)
            if (characters[i] != translation->source[i]) return 0;
        return 1;
    }
    return 0;
}

void ol_image_added(const struct Header64 *header, iptr slide) {
    if (!header || header->magic != 0xfeedfacf || header->cpu != 0x100000c ||
        header->ncmds > 256 || header->sizeofcmds > 0x100000) return;
    const u8 *cursor = (const u8 *)(header + 1);
    const u8 *end = cursor + header->sizeofcmds;
    struct ConstantString *literals = 0;
    u64 size = 0;
    int recognized = 0;
    for (u32 i = 0; i < header->ncmds; ++i) {
        if (cursor + sizeof(struct Command) > end) return;
        const struct Command *command = (const void *)cursor;
        if (command->size < 8 || command->size > (uptr)(end - cursor)) return;
        if (command->cmd == 0x1b && command->size == 24) {
            for (u32 uuid = 0; uuid < OL_UUID_COUNT; ++uuid) {
                int equal = 1;
                for (u32 byte = 0; byte < 16; ++byte)
                    if (cursor[8 + byte] != ol_uuids[uuid][byte]) equal = 0;
                if (equal) recognized = 1;
            }
        }
        if (command->cmd == 0x19 && command->size >= sizeof(struct Segment64)) {
            const struct Segment64 *segment = (const void *)cursor;
            if (segment->nsects > (command->size - sizeof(*segment)) / sizeof(struct Section64)) return;
            const struct Section64 *sections = (const void *)(segment + 1);
            for (u32 section = 0; section < segment->nsects; ++section) {
                if (equal_name(sections[section].name, "__cfstring") &&
                    (equal_name(sections[section].segment, "__DATA_CONST") ||
                     equal_name(sections[section].segment, "__DATA"))) {
                    literals = (void *)(sections[section].address + slide);
                    size = sections[section].size;
                }
            }
        }
        cursor += command->size;
    }
    if (!recognized || !literals || !size || size % sizeof(*literals) || size > 0x100000) return;
    uptr page_size = (uptr)getpagesize();
    if (page_size < 4096 || (page_size & (page_size - 1))) return;
    uptr start = (uptr)literals & ~(page_size - 1);
    uptr limit = ((uptr)literals + size + page_size - 1) & ~(page_size - 1);
    if (mprotect((void *)start, limit - start, 3)) return;
    for (u64 index = 0; index < size / sizeof(*literals); ++index) {
        for (u32 translation = 0; translation < OL_TRANSLATION_COUNT; ++translation) {
            const struct Translation *entry = &ol_translations[translation];
            if (!matches(&literals[index], entry)) continue;
            /* Preserve the original CoreFoundation/Objective-C class pointer. */
            literals[index].flags = 0x7d0;
            literals[index].characters = chinese_enabled ? entry->chinese : entry->english;
            literals[index].length = chinese_enabled ? entry->chinese_length : entry->english_length;
            break;
        }
    }
    (void)mprotect((void *)start, limit - start, 1);
}

#ifndef OL_TEST
__attribute__((constructor))
#endif
void ol_initialize(void) {
    chinese_enabled = 0;
    const void *languages = CFLocaleCopyPreferredLanguages();
    if (languages) {
        if (CFArrayGetCount(languages) > 0) {
            const void *first = CFArrayGetValueAtIndex(languages, 0);
            char language[64];
            if (first && CFStringGetCString(first, language, sizeof(language), 0x08000100))
                chinese_enabled = (u32)ol_should_use_chinese(language);
        }
        CFRelease(languages);
    }
    _dyld_register_func_for_add_image(ol_image_added);
}
