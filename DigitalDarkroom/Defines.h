//
//  Defines.h
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#ifndef Defines_h
#define Defines_h

// #define DEBUG_CAMERA_CAPTURE_SIZE   1
//#define DEBUG_TASK_CONFIGURATION  1
#define DEBUG_LAYOUT    1
//#define DEBUG_DEPTH  1
//#define DEBUG_SOURCE  1
//#define DEBUG_ORIENTATION 1
//#define DEBUG_CAMERA  1

typedef u_char channel;

typedef struct {
    channel b, g, r, a;
} Pixel;

// PixelIndex_t: index into an image, range 0..configuredPixelsInImage, or
//  several small negative numbers indicating a particular color instead of
//  an existing pixel.

typedef long PixelIndex_t;

#define LATER   0   /*later*/

// view tools

#define BELOW(r)    ((r).origin.y + (r).size.height)
#define RIGHT(r)    ((r).origin.x + (r).size.width)

#define SET_VIEW_X(v,nx) {CGRect _f = (v).frame; _f.origin.x = (nx); (v).frame = _f;}
#define SET_VIEW_Y(v,ny) {CGRect _f = (v).frame; _f.origin.y = (ny); (v).frame = _f;}

#define SET_VIEW_WIDTH(v,w)     {CGRect _f = (v).frame; _f.size.width = (w); (v).frame = _f;}
#define SET_VIEW_HEIGHT(v,h)    {CGRect _f = (v).frame; _f.size.height = (h); (v).frame = _f;}

#define CENTER_VIEW(cv, v)  {CGRect _f = (cv).frame; \
        _f.origin.x = ((v).frame.size.width - _f.size.width)/2.0; \
        (cv).frame = _f;}

#define SECTION_HEADER_FONT_SIZE    24
#define TABLE_ENTRY_FONT_SIZE       18

#define USED(x) ((void)(x))

#endif /* Defines_h */
