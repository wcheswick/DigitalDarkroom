/*
 * Copyright 2004 Bill Cheswick <ches@cheswick.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Bill Cheswick.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// see http://en.wikipedia.org/wiki/Color_blindness

#ifdef notdef

#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <time.h>
#include <assert.h>

#include "libio/arg.h"
#include "libutil/util.h"
#include "libio/io.h"
#include "libutil/font.h"
#include "libutil/button.h"
#include "colorblind.h"

/*
 * In our program, the origin is always in the lower left.  This is certainly
 * not true for some or all of the I/O devices.
 */

/*
 * Video output display size.  NB:  Each input pixel is four output
 * pixels, to speed processing time.
 */

#define VIDEO_ZOOM	2

#define VIDEO_HEIGHT	(MAX_Y*VIDEO_ZOOM)
#define VIDEO_WIDTH	(MAX_X*VIDEO_ZOOM)

#define BUTTON_WIDTH	200	/* pixels */
#define BUTTON_HEIGHT	50	/* pixels */
#define BUTTON_SEP	6

#define TOPBUTTONSPACE	22
#define BUTTONWIDTH	200
#define BUTTONHEIGHT	60
#define BUTTONSEP	5

#define NSAMPLES	10	/* randomly-saved previous pictures */

#define LIVE_TO		(10)
#define ACTIVE_TO	(60)

#define DEMO_STRAIGHT_TO	4
#define DEMO_CHANGED_TO		12

#define ALARMTIME	15
#define WARNTIME	30

Rectangle left_video_r;
Rectangle right_video_r;
Rectangle title_r;
Rectangle thanks_r;
Rectangle video_settings_r;

int debug = 0;

font *text_font;
font *button_font;
font *title_font;

long lastoptime = 0;
int needs_update = 1;

char *title;
char *thanks;

#define FILENAMELEN	20

#define OLD	Green

button *last_command = 0;
button *source = 0;
button *transform_command = 0;
button *live_button;

int refresh_screen = 1;	/* if repaint (or initialize) the screen(s) */
int show_video_settings = 0;

image frame;

enum {
	GoLive,
	ShowSample,
	SetTransform,
} button_types;

typedef	Pixel *bufptr[MAX_Y][MAX_X];

struct source {
	char *name;
	utf8 *label;
	char *file;
	image *im;
} sources[] = {
	{"live", "Live", 0},
	{"cube", "Cubes and|strawberries", "cube.pnm"},
	{"rainbow", "Rainbow", "rainbow.pnm"},
	{"ishihara25", "Ishihara 74", "ishihara9.pnm"},
//	{"ishihara29", "Ishihara 25", "ishihara25.pnm"},
//	{"ishihara45", "Ishihara 25", "ishihara25.pnm"},
//	{"ishihara5", "Ishihara 25", "ishihara25.pnm"},
//	{"ishihara8", "Ishihara 25", "ishihara25.pnm"},
	{0,0,0}
};

/*
 * We precompute a lookup table for all the color changes.  But we don't
 * have time to compute all 2^24 color translations, and don't need to:
 * this exhibit simply isn't that accurate.  
 */
#define COLOR_FUDGE	(1<<2)

#define	FUDGE_COLORS	((Z+1)/COLOR_FUDGE)
typedef Pixel (translate_table)[FUDGE_COLORS][FUDGE_COLORS][FUDGE_COLORS];

struct translations {
	char *name;
	char *label;
	ColorblindDeficiency deficit;
	char *file_name;
//	translate_table *table[2];
	translate_table *table;
} translate[] = {
	{"red", "Protanopia|insensitivity to red", PROTANOPIA, "protanope.pnm"},
	{"green", "Deuteranopia|insensitivity to green", DEUTERANOPIA, "deuteranope.pnm"},
	{"blue", "Tritanopia|insensitivity to blue", TRITANOPIA, "tritanope.pnm"},
//	{"mono", "Achromatopsia|insensitive to color", Blue, "mono.pnm"},
	{0},
};

translate_table *
setup_translation(ColorblindDeficiency deficit) {
	translate_table *table;
	int r, g, b;

	fprintf(stderr, "Initializing color lookup table %d...\n", deficit);
	table = (translate_table *)malloc(sizeof(translate_table));
	assert(table);	// out of memory initializing translation table

	init_colorblind(deficit);
	for (r=0; r<FUDGE_COLORS; r++)
		for (g=0; g<FUDGE_COLORS; g++)
			for (b=0; b<FUDGE_COLORS; b++)
				(*table)[r][g][b] =
					to_colorblind(r*COLOR_FUDGE,
					g*COLOR_FUDGE, b*COLOR_FUDGE);
	return table;
}

/*
 * Transform the given image with the current selection, writing to ivdeo_out.
 */
void
transform(button *bp, image *in) {
	Pixel *ppi = (Pixel *)in;
	Pixel *ppo = **video_out;
	struct translations *tp = &translate[(int)bp->param];

	translate_table *table = tp->table;

	int n;

	for (n = MAX_Y*MAX_X ; n>0; n--) {
		Pixel p = *ppi++;
		*ppo++ = (*table)[p.r/COLOR_FUDGE][p.g/COLOR_FUDGE][p.b/COLOR_FUDGE];
	}
}

int
do_exit(void *param, image in, image out) {
	end_display();
	exit(0);
}

/*
 * Read and store the sample image.
 */
PixMap *
read_sample_PixMap(char *fn) {
	PixMap *pm = (PixMap *)malloc(sizeof(PixMap));
	int dx, dy;
	char *ffn;

	assert(pm);	// out of memory getting pixmap of sample

	memset((void *)pm, 0, sizeof(pm));

	ffn = find_file(fn, "lib/cb");
	if (ffn == 0) {
		fprintf(stderr, "read_sample: could not find sample image: %s\n", fn);
		exit(10);
	}
	pm->pm = read_pnm_image(ffn, &dx, &dy);
	if (!pm->pm)
		exit(10);
	if (dx != MAX_X || dy != MAX_Y) {
		fprintf(stderr, "read_sample: image %s size %d,%d must be %d,%d\n",
			fn, dx, dy, MAX_X, MAX_Y);
		exit(11);
	}
	return pm;
}

#define TITLE_HEIGHT	50
#define VIDEO_SEP	10

/*
 * Figure out where everything goes.
 */
void
layout_screen(void) {
	Rectangle r;
	int i;

	text_font = load_font(TF);
	button_font = load_font(BF);
	title_font = load_font(TIF);

	title = lookup("title", 0, "What do the colorblind see?");
	thanks = lookup("thanks", 0, "Thanks to http://vischeck.com for color deficit simulation algorithms");

	title_r = (Rectangle){{0, SCREEN_HEIGHT - FONTHEIGHT(title_font)},
		{SCREEN_WIDTH, SCREEN_HEIGHT}};

	left_video_r.min.x = 0;
	left_video_r.min.y = SCREEN_HEIGHT - VIDEO_HEIGHT - TITLE_HEIGHT;
	left_video_r.max.x = left_video_r.min.x + VIDEO_WIDTH;
	left_video_r.max.y = left_video_r.min.y + VIDEO_HEIGHT;

	right_video_r.max.x = SCREEN_WIDTH;
	right_video_r.max.y = left_video_r.max.y;
	right_video_r.min.x = right_video_r.max.x - 2*VIDEO_WIDTH;
	right_video_r.min.y = left_video_r.max.y - 2*VIDEO_HEIGHT;

	r.min.x = 0 + (VIDEO_WIDTH - BUTTON_WIDTH)/2;
	r.max.x = r.min.x + BUTTON_WIDTH;
	r.max.y = left_video_r.min.y - BUTTON_SEP;
	r.min.y = r.max.y - BUTTON_HEIGHT;

	button_sep = BUTTON_SEP;
	set_font(button_font);

	live_button = add_button(r, "Live", "Live", Green, 0);
	live_button->state = On;
	live_button->value = GoLive;
	source = live_button;
	needs_update = 1;

	for (i=1; sources[i].name; i++) {
		PixMap *pm = read_sample_PixMap(sources[i].file);

		if (pm)
			sources[i].im = (image *)pm->pm;
		add_button(below(last_button->r), sources[i].name, sources[i].label,
			Green, (void *)i);
		last_button->value = ShowSample;
	}

	r.min.x = right_video_r.min.x + ((2*VIDEO_WIDTH) - BUTTON_WIDTH)/2;
	r.max.x = r.min.x + BUTTON_WIDTH;
	r.max.y = right_video_r.min.y - BUTTON_SEP;
	r.min.y = r.max.y - BUTTON_HEIGHT;

	for (i=0; translate[i].name; i++) {
		(translate[i].table) = setup_translation(translate[i].deficit);
		add_button(r, translate[i].name, translate[i].label,
			Blue, (void *)i);
		r = below(r);
		last_button->value = SetTransform;
	}

	thanks_r = (Rectangle){{0, 0}, {SCREEN_WIDTH, FONTHEIGHT(button_font)}};

	video_settings_r = thanks_r;
	video_settings_r.min.y = video_settings_r.max.y + BUTTON_SEP;
	video_settings_r.max.y = video_settings_r.min.y + FONTHEIGHT(button_font);
}

void
draw_screen(void) {
	button *bp = buttons;

	set_font(title_font);
	write_centered_string(title_r, White, title);

	set_font(button_font);
	write_centered_string(thanks_r, White, thanks);

	while (bp) {
		paint_button(bp);
		bp = bp->next;
	}

	clear_to_background(video_settings_r);
	if (show_video_settings) {
		char buf[100];
		snprintf(buf, sizeof(buf), "video settings:  hue %d  sat %d  bright %d  cont %d",
			get_hue(), get_saturation(), get_brightness(),
			get_contrast());
		write_string(video_settings_r, White, buf);
	}

	needs_update = 1;
	show_cursor();
	flush_screen();
}

static int files_written = 0;

void
kbd_hit(char key) {
	char buf[100];

	switch (key) {
	case 'a':
		abort();
	case 'd':
		dump_screen(0);
		break;
	case 't':
		display_test();
		sleep(10);
		break;
	case 'w':
	case 'W':	/* write currently displayed image out to a file */
		snprintf(buf, sizeof(buf), "grab%03d.jpeg", files_written++);
		write_jpeg_image(buf, video_out);
		break;
	case 'q':
	case 'Q':
	case 'x':
	case 'X':	/* exit the program */
		end_display();
		exit(0);
	case 'v':
		show_video_settings = !show_video_settings;
		refresh_screen = 1;
		break;
	case 'h':
		set_hue(get_hue() - 1);
		refresh_screen = 1;
		break;
	case 'H':
		set_hue(get_hue() + 1);
		refresh_screen = 1;
		break;
	case 's':
		set_saturation(get_saturation() - 1);
		refresh_screen = 1;
		break;
	case 'S':
		set_saturation(get_saturation() + 1);
		refresh_screen = 1;
		break;
	case 'b':
		set_brightness(get_brightness() - 1);
		refresh_screen = 1;
		break;
	case 'B':
		set_brightness(get_brightness() + 1);
		refresh_screen = 1;
		break;
	case 'c':
		set_contrast(get_contrast() - 1);
		refresh_screen = 1;
		break;
	case 'C':
		set_contrast(get_contrast() + 1);
		refresh_screen = 1;
		break;
	}
}

void
process_command(Point mouse) {
	button *bp = buttons;

	while (bp && (bp->state == Hidden || !ptinrect(mouse, bp->r)))
		bp = bp->next;
	if (!bp)
		return;

	switch (bp->value) {
	case GoLive:
		source->state = Off;
		paint_button(source);
		live_button->state = On;
		paint_button(live_button);
		source = bp;
		needs_update = 1;
		break;
	case ShowSample:
		if (source == bp)
			break;
		source->state = Off;
		paint_button(source);
		source = bp;
		source->state = On;
		paint_button(source);
		needs_update = 1;
		break;
	case SetTransform:
		needs_update = 1;
		if (transform_command) {
			transform_command->state = Off;
			paint_button(transform_command);
			if (bp == transform_command) {
				transform_command = 0;
				break;
			}
		}
		transform_command = bp;
		transform_command->state = On;
		paint_button(transform_command);
		needs_update = 1;
	}
	flush_screen();
}

int mouse_pressed = 0;
Point last_mouse;

void
click(Point mouse) {
	mouse_pressed = 1;
	last_mouse = mouse;
	process_command(mouse);
}


int
usage(void) {
	fprintf(stderr, "usage: chat [-h] [-d]\n");
	return 13;
}

char *prog;

int
main(int argc, char *argv[]) {
	prog = argv[0];

	load_config("cb");
	init_font_locale(lookup("locale", 0, 0));
	set_screen_size(SCREEN_WIDTH, SCREEN_HEIGHT);
	srandom(time(0));
	layout_screen();
	init_video_in();
	init_display(argc, argv, prog);

	io_main_loop();
	return 0;
}

void
do_idle(void) {
	if (refresh_screen) {
		draw_screen();
		refresh_screen = 0;
	}

	if (over_fps(30))
		return;

	if (source != live_button) {
		int source_index = (int)source->param;
		struct source *sp = &sources[source_index];

		if (!needs_update)
			return;

		write_video_frame_zoom(left_video_r.min, sp->im, 1);
		if (transform_command) {
			transform(transform_command, sp->im);
			write_video_frame_zoom(right_video_r.min, video_out, 2);
		} else
			write_video_frame_zoom(right_video_r.min, sp->im, 2);
		needs_update = 0;
	} else {
		grab_video_in();
		write_video_frame_zoom(left_video_r.min, video_in, 1);
		if (transform_command) {
			transform(transform_command, (image *)video_in);
			write_video_frame_zoom(right_video_r.min, video_out, 2);
		} else
			write_video_frame_zoom(right_video_r.min, video_in, 2);
	}
	flush_screen();
}

#endif

