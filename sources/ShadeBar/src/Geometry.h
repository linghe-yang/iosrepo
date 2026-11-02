#pragma once
#include <stdbool.h>
typedef struct { double x, y, w, h; } SBRect;
typedef struct { double x, y; } SBPoint;
SBPoint SBPointInFixedScreen(SBPoint point,int orientation,double portraitWidth,double portraitHeight);
SBRect SBNormalizeRect(SBRect r);
SBRect SBCenteredRect(double cx,double cy,double widthFraction,double heightFraction);
SBRect SBPixelRect(SBRect r,double screenWidth,double screenHeight);
SBRect SBDrag(SBRect r,double dx,double dy);
bool SBVisible(bool enabled,bool locked,bool restricted,bool frontKnown,bool selected);
