//
//  Defines.h
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#ifndef Defines_h
#define Defines_h

//#define VERIFY_PIXBUF_BUFFERS   1

// Performance hit for all of these together on my iPad pro: 10 FPS -> 5 FPS
//#define VERIFY_DEPTH_BUFFERS    1
//#define VERIFY_REMAP_BUFFERS    1
//#define VERIFY_DEPTHS           1

//#define DEBUG_LAYOUT    1
//#define MEMLEAK_AIDS 1

//#define DEBUG_ORIENTATION

#define DEBUG_CONCURRENCY   1
#define DEBUG_TASK_CONFIGURATION  1
//#define DEBUG_OMIT_THUMBS 1
//#define DEBUG_BORDERS 1
//#define DEBUG_CAMERA  1
//#define DEBUG_TASK_BUSY 1
//#define DEBUG_DEPTH  1
//#define DEBUG_SOURCE  1
//#define DEBUG_THUMB_PLACEMENT 1
//#define DEBUG_EXECUTE 1
//#define DEBUG_THUMB_LAYOUT 1
//#define ONLY_RED    1   // process pure red input only

#define MAX_FPS  30
#define MAX_THUMBS_UPDATE_MS 500   // ms. Actually, it is taking about 200, and is fine.

#define POINTING_HAND_CHAR  @"☞"
#define UNICODE_PAUSE   @"\u23F8"   // two bars
#define UNICODE_PLAY    @"\u25B6"   // play triangle

#define BITMAP_OPTS kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst

#define USED(x) ((void)(x)) // to suppress "variable unused" messages

#define SAME_SIZE(s1, s2)   ((s1).width == (s2).width && (s1).height == (s2).height)

typedef uint8_t channel;

typedef struct {
    channel b, g, r, a;
} Pixel;

typedef struct {
    channel h, s, v, a;
} HSVPixel;

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

#define SEP 4  // between views
#define INSET 3 // from screen edges

#define SOURCE_SELECT_BUTTON_W  40

#define CHECKMARK   @"✓"
#define BIGPLUS     @"＋"
#define DOUBLE_PLUS @"⧺"
#define LOCK        @"🔒"
#define SHY         @"\u00ad"   // soft hyphen
#define BIGSTAR     @"✵"        // unicode pinwheel star

#define MIN_THUMB_COLS  4
#define MIN_THUMB_ROWS  3
#define MIN_IPHONE_THUMB_COLS  3
#define MIN_IPHONE_THUMB_ROWS  2

#define THUMB_W         80
//#define TIGHT_THUMB_W   60

#define PAUSE_FONT_SIZE 18
#define PAUSE_W         (PAUSE_FONT_SIZE*12)
#define THUMB_FONT_SIZE 14
#define THUMB_LABEL_H   (3.0*(THUMB_FONT_SIZE+6))
#define THUMB_LABEL_SEP 4

#define SECTION_HEADER_FONT_SIZE    20

#define EXECUTE_BORDER_W    2

#define CONTROL_BUTTON_SIZE 50

#define PARAM_LABEL_H   18
#define PARAM_LABEL_FONT_SIZE   (PARAM_LABEL_H)
#define PARAM_SLIDER_H  (40)
#define PARAM_VIEW_H    (SEP + PARAM_LABEL_H + SEP + PARAM_SLIDER_H + SEP)

#define EXECUTE_STATUS_W    30
#define EXECUTE_CHAR_W  (EXECUTE_STATUS_FONT_SIZE*0.8)
#define STEP_W          (EXECUTE_CHAR_W*2)

#define EXECUTE_FONT_SIZE   (18)
#define EXECUTE_ROW_H       (EXECUTE_FONT_SIZE + SEP)
#define EXECUTE_H_FOR(n)    ((n)*EXECUTE_ROW_H + 2*EXECUTE_BORDER_W + 2*SEP)
#define EXECUTE_MIN_H       EXECUTE_H_FOR(1)
#define EXECUTE_FULL_H      EXECUTE_H_FOR(6)

#define  LAYOUT_BEST_DISPLAY_AREA_FRAC   0.75

// There is always a bit of display available, for pinching
#define MIN_DISPLAY_W   THUMB_W
#define MIN_DISPLAY_H   THUMB_W

#define ASPECT_PCT_DIFF_OK  5.0
#define DIFF_PCT(a,b)   (100.0*fabsf((a) - (b))/(a))

#define DEGRAD(d)   (((d)/180.0) * M_PI)

#endif /* Defines_h */
