#pragma once
#include <stdbool.h>
/* Explicit per-app overrides win over both legacy list modes. */
static inline bool SBAppEnabled(bool hasOverride,bool overrideEnabled,bool legacyRestricted,bool legacySelected) {
    return hasOverride?overrideEnabled:(!legacyRestricted || legacySelected);
}
typedef struct { double x, y, w, h; } SBRect;
typedef struct { double x, y; } SBPoint;
SBPoint SBPointInFixedScreen(SBPoint point,int orientation,double portraitWidth,double portraitHeight);
SBRect SBNormalizeRect(SBRect r);
SBRect SBCenteredRect(double cx,double cy,double widthFraction,double heightFraction);
SBRect SBPixelRect(SBRect r,double screenWidth,double screenHeight);
SBRect SBDrag(SBRect r,double dx,double dy);
bool SBVisible(bool enabled,bool locked,bool restricted,bool frontKnown,bool selected,bool switcherVisible);
