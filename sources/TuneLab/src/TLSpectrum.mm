#import "TLSpectrum.h"
#import "TLOriginalRuntime.h"
#include "../native/OriginalDSP.hpp"
#include <vector>
#include <cmath>
#include <algorithm>
@implementation TLSpectrum {
    float _pitchError;
    NSArray *_configuration;
}
- (float)pitchError{return _pitchError;}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){self.opaque=YES;_target=440;_fundamental=440;_zoom=1;_thickness=1;_pitchError=-99999;}
    return self;
}
- (void)drawRect:(CGRect)rect {
    float scale=self.contentScaleFactor,w=self.bounds.size.width,h=self.bounds.size.height;
    if(w<10||h<30||!_runtime)return;
    int width=std::min(4096,int(w*scale)),height=std::min(4096,int(h*scale));
    float target=std::max(25.5f,std::min(10199.f,_target));
    float lo,hi;
    switch(_zoom){case 0:lo=_fundamental*.5;hi=std::max(_fundamental*13,target*1.077982f);break;case 2:case 5:lo=target*.927659;hi=target*1.077982;break;case 3:lo=target*.97153;hi=target*1.0293;break;default:lo=target*.86055;hi=target*1.162;break;}
    constexpr float bin=22050.f/8192.f;
    int first=std::max(10,int(lo/bin)),last=std::min(4095,std::max(first+8,int(hi/bin)));first=std::min(first,last-4);
    lo=first*bin;hi=last*bin;
    int plot=std::max(1,height-int(15*scale));
    std::vector<uint32_t> pixels(size_t(width)*height,_dark?0xff000000:0xffffffff);
    TLNativeBitmap bitmap{uint32_t(width),uint32_t(height),uint32_t(width*4),1,0,pixels.data()};
    NSArray *configuration=@[@(width),@(plot),@(_zoom),@(target),@(first),@(last),@(_thickness),@(_dark?0xffffffff:0xff000000)];
    // The original setup routine also recalculates demodulator parameters. It
    // belongs to geometry / target changes, never the per-frame paint path.
    if(![_configuration isEqual:configuration]){[_runtime call:@"setupSpectrumGraph" arguments:configuration];_configuration=configuration;}
    _pitchError=[[_runtime call:@"drawSpectrumGraph" arguments:@[[NSValue valueWithPointer:&bitmap]]] floatValue];
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext=CGBitmapContextCreate(pixels.data(),width,height,8,width*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGImageRef image=CGBitmapContextCreateImage(bitmapContext);[[UIImage imageWithCGImage:image scale:scale orientation:UIImageOrientationUp] drawInRect:self.bounds];CGImageRelease(image);CGContextRelease(bitmapContext);CGColorSpaceRelease(space);
    CGContextRef c=UIGraphicsGetCurrentContext();CGFloat bottom=plot/scale;
    float f0=target/bin,minus=f0*.9942404f,plus=f0*1.005793f;
    auto x=[&](float frequency)->float {float f=frequency/bin;if(_zoom<4)return (f-first)*w/(last-first);float start=w*3/8,end=start+w/4;if(f<minus)return (f-first)*start/(minus-first);if(f>plus)return end+(f-plus)*(w-end)/(last-plus);return start+(f-minus)*(w/4)/(plus-minus);};
    auto line=[&](float px,UIColor *color,float top,float end){if(px<0||px>w)return;CGContextSetStrokeColorWithColor(c,color.CGColor);CGContextSetLineWidth(c,1/scale);CGContextMoveToPoint(c,px,top);CGContextAddLineToPoint(c,px,end);CGContextStrokePath(c);};
    UIColor *ink=_dark?UIColor.whiteColor:UIColor.blackColor;
    line(x(target),[UIColor colorWithRed:1 green:.31 blue:.31 alpha:1],0,bottom);
    for(float cents:{-200.f,-100.f,-10.f,10.f,100.f,200.f})if(fabs(cents)==100||(_zoom>=2&&fabs(cents)==10)||(_zoom>=4&&fabs(cents)==200))line(x(target*powf(2,cents/1200)),[UIColor colorWithRed:.49 green:1 blue:.49 alpha:1],0,bottom);
    NSDictionary *attrs=@{NSFontAttributeName:[UIFont fontWithName:@"Roboto-Regular" size:13]?:[UIFont systemFontOfSize:13],NSForegroundColorAttributeName:ink};
    if(_zoom<4){
        int increments[]={1,2,5,10,25,50,100,250,500,1000,2500,5000},minor[]={10,10,10,10,5,10,10,5,10,10,5,10},half[]={2,2,5,2,1,5,2,1,5,2,1,5};int index=0;
        while(index<11&&13*4.1f*(hi-lo)/w>increments[index])index++;
        float step=float(increments[index])/minor[index];
        for(int tick=ceilf(lo/step);tick*step<hi;tick++){float px=x(tick*step);if(tick%minor[index]==0){NSString *text=[NSString stringWithFormat:@"%3.0f",tick*step];CGSize size=[text sizeWithAttributes:attrs];[text drawAtPoint:CGPointMake(px-size.width/2,bottom) withAttributes:attrs];}line(px,[UIColor colorWithRed:.5 green:.5 blue:1 alpha:1],bottom,bottom*(tick%(minor[index]/half[index])==0?.8:.95));}
    }else for(int cents:{-200,-100,-10,10,100,200})if(abs(cents)<200||_zoom==4){NSString *text=[NSString stringWithFormat:@"%+d",cents];CGSize size=[text sizeWithAttributes:attrs];[text drawAtPoint:CGPointMake(x(target*powf(2,cents/1200))-size.width/2,bottom) withAttributes:attrs];}
    [ink setStroke];CGContextSetLineWidth(c,1/scale);CGContextMoveToPoint(c,0,bottom);CGContextAddLineToPoint(c,w,bottom);CGContextStrokePath(c);
    NSString *label=@[@"wide",@"±260",@"±130",@"±50",@"±260 (wide middle)",@"±130 (wide middle)"][MAX(0,MIN(5,_zoom))];
    [[NSString stringWithFormat:@"%@\n%@",label,_intervals?:@""] drawInRect:CGRectMake(0,0,w,90) withAttributes:attrs];
}
@end
