#pragma once
#include <stdbool.h>
typedef struct { double x, y, w, h; } SBRect;
enum { SBLeft=1, SBRight=2, SBTop=4, SBBottom=8 };
SBRect SBClamp(SBRect r, double width, double height);
SBRect SBDrag(SBRect r, double dx, double dy, double width, double height);
SBRect SBResize(SBRect r, unsigned edges, double dx, double dy, double width, double height);
bool SBVisible(bool enabled, bool locked, bool restricted, bool frontKnown, bool selected);
