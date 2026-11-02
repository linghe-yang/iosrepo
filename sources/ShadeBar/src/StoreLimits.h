#pragma once
#include <stddef.h>
static inline int SBStoreSizeAllowed(size_t bytes) {
    // Text profiles can exceed the old 1 MiB read limit. Both paths must agree.
    return bytes>0 && bytes<=16u*1024u*1024u;
}
