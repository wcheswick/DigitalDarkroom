//
//  Defines.h
//  DigitalDarkroom
//
//  Created by ches on 9/15/19.
//  Copyright © 2019 Cheswick.com. All rights reserved.
//

#ifndef Defines_h
#define Defines_h

#define DEBUG_LAYOUT    1
//#define DEBUG_CAMERA_CAPTURE_SIZE   1
//#define DEBUG_TASK_CONFIGURATION  1
//#define DEBUG_DEPTH  1
//#define DEBUG_SOURCE  1
#define DEBUG_ORIENTATION 1
//#define DEBUG_CAMERA  1
#define DEBUG_EXECUTE 1

#define POINTING_HAND_CHAR  @"☞"

#define USED(x) ((void)(x)) // to suppress "variable unused" messages

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

#define SEP 4  // between views
#define INSET 3 // from screen edges

#define SOURCE_SELECT_BUTTON_W  40

#define CHECKMARK   @"✓"
#define BIGPLUS     @"＋"

#define MIN_THUMB_COLS  4
#define MIN_THUMB_ROWS  3
#define MIN_IPHONE_THUMB_COLS  3
#define MIN_IPHONE_THUMB_ROWS  2

#define SMALL_THUMB_W   65
#define THUMB_W         80

#define OLIVE_FONT_SIZE 14
#define OLIVE_LABEL_H   (2.0*(OLIVE_FONT_SIZE+4))

#define SECTION_HEADER_FONT_SIZE    24

#define EXECUTE_ROW_H       17

#define EXECUTE_MIN_ROWS_BELOW  2     // a squeeze for iphones, more for others

#define EXECUTE_STATUS_FONT_SIZE    (EXECUTE_ROW_H-2)

#define EXECUTE_BORDER_W    2
#define EXECUTE_MAX_VISIBLE_ROWS   4
#define EXECUTE_MAX_VISIBLE_VIEW_H      (2*EXECUTE_BORDER_W + EXECUTE_MAX_VISIBLE_ROWS*EXECUTE_ROW_H)

#define EXECUTE_BUTTON_H        (EXECUTE_MIN_ROWS_BELOW*EXECUTE_ROW_H + 2*EXECUTE_BORDER_W)
#define EXECUTE_BUTTON_FONT_H   (EXECUTE_BUTTON_H - 2)
#define EXECUTE_BUTTON_FONT_W   (EXECUTE_BUTTON_FONT_H)

#define EXECUTE_MIN_BELOW_H     (EXECUTE_BUTTON_H)
#define EXECUTE_BEST_BELOW_H    (EXECUTE_MAX_VISIBLE_ROWS * \
                    (EXECUTE_BUTTON_H + SEP) + 2*EXECUTE_BORDER_W)
#define EXECUTE_NAME_W  140
#define EXECUTE_NUMBERS_W   45
#define EXECUTE_BUTTON_W    (EXECUTE_BUTTON_FONT_W)
#define EXECUTE_CELL_SELECTED_BORDER_W  3.0
#define EXECUTE_CELL_SELECTED_CORNER_RADIUS  5

#define EXECUTE_STATUS_W    30
#define EXECUTE_CHAR_W  (EXECUTE_STATUS_FONT_SIZE*0.8)
#define STEP_W          (EXECUTE_CHAR_W*2)

#define EXECUTE_LIST_W  (EXECUTE_BORDER_W + EXECUTE_CHAR_W + STEP_W + 2*SEP + EXECUTE_NAME_W + 2*EXECUTE_NUMBERS_W + SEP + EXECUTE_BORDER_W)
#define EXECUTE_VIEW_W  (EXECUTE_BUTTON_W + SEP + EXECUTE_LIST_W)
#define EXECUTE_VIEW_H  EXECUTE_MAX_VISIBLE_VIEW_H

#define EXECUTE_VIEW_ANIMATION_TIME 0.4


#define EXECUTE_STEP_TAG    10

#define STACKING_BUTTON_FONT_SIZE   (EXECUTE_BUTTON_H-6)

#endif /* Defines_h */
