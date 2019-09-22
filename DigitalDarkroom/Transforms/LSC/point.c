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

#ifdef notdef
#include <stdio.h>
#include <sys/types.h>
#include <math.h>

#include "libutil/util.h"
#include "libio/io.h"
#include "trans.h"

int
do_point(void *param, image in, image out) {
	int x,y;
	Pixel (*func)(Pixel) = param;
	
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			out[y][x] = func(in[y][x]);
	return 1;
}

#define CX	(MAX_X/4)
#define CY	(MAX_Y*3/4)
#define OPSHIFT	(3 /*was 0*/)

int
op_art(void *param, image in, image out) {
	int x,y;
	
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++) {
			Pixel p = in[y][x];
			long factor = (CX-(x-CX)*(x-CX) - (y-CY)*(y-CY));
			int r = p.r^(p.r*factor >> OPSHIFT);
			int g = p.g^(p.g*factor >> OPSHIFT);
			int b = p.b^(p.b*factor >> OPSHIFT);
			out[y][x] = CRGB(r,g,b);
		}
	}
	return 1;
}

#ifdef notdef
void
colorbars(image in, image out) {
	int x,y;
	
	for (y=0; y<MAX_Y; y++) {
		int colormask = (y / 20) & 0x7;
		channel r = (colormask & 1) ? Z : 0;
		channel g = (colormask & 2) ? Z : 0;
		channel b = (colormask & 4) ? Z : 0;
		lineptr addr = getlineptr(0, y);

		for (x=0; x<MAX_X; x++)
			addr[x] = RGB(r*x/MAX_X, g*x/MAX_X, b*x/MAX_X);
	}
}
#endif

channel rl[31] = {0,0,0,0,0,0,0,0,0,0,		5,10,15,20,25,Z,Z,Z,Z,Z,	0,0,0,0,0,5,10,15,20,25,Z};
channel gl[31] = {0,5,10,15,20,25,Z,Z,Z,Z,	Z,Z,Z,Z,Z,Z,Z,Z,Z,Z,		25,20,15,10,5,0,0,0,0,0,0};
channel bl[31] = {Z,Z,Z,Z,Z,25,15,10,5,0,	0,0,0,0,0,5,10,15,20,25,	5,10,15,20,25,Z,Z,Z,Z,Z,Z};	

static Pixel
colorize(Pixel p) {
#if Z == 31
	channel pw = ((p.r^p.b^p.g) + p.r + p.g + p.b)&Z;
	return SETRGB(rl[pw], gl[pw], bl[pw]);
#elif Z == 255
	channel pw = (((p.r>>3)^(p.g>>3)^(p.b>>3)) + (p.r>>3) + (p.g>>3) + (p.b>>3))&31;
	return SETRGB(rl[pw]<<3, gl[pw]<<3, bl[pw]<<3);
#else
	ERR
#endif
}

void *
init_colorize(void) {
	return colorize;
}

static Pixel
swapcolors(Pixel p) {
	return SETRGB(p.g, p.b, p.r);
}

void *
init_swapcolors(void) {
	return swapcolors;
}

static Pixel
lum(Pixel p) {
	channel lum = LUM(p);	/* wasteful, but cleaner code */
	return SETRGB(lum, lum, lum);
}

void *
init_lum(void) {
	return lum;
}

static Pixel
high(Pixel p) {
	return SETRGB(	CLIP((p.r-HALF_Z)*2+HALF_Z),
			CLIP((p.g-HALF_Z)*2+HALF_Z),
			CLIP((p.b-HALF_Z)*2+HALF_Z));
}

void *
init_high(void) {
	return high;
}

static Pixel
negative(Pixel p) {
	return SETRGB(Z-p.r, Z-p.g, Z-p.b);
}

void *
init_negative(void) {
	return negative;
}

static Pixel
solarize(Pixel p) {
	return SETRGB(	p.r < Z/2 ? p.r : Z-p.r,
			p.g < Z/2 ? p.g : Z-p.g,
			p.b < Z/2 ? p.b : Z-p.r);
}

void *
init_solarize(void) {
	return solarize;
}

#define TMASK 0xe0

static Pixel
truncatepix(Pixel p) {
	return SETRGB(p.r&TMASK, p.g&TMASK, p.b&TMASK);
}

void *
init_truncatepix(void) {
	return truncatepix;
}

static Pixel
brighten(Pixel p) {
	return SETRGB(	p.r+(Z-p.r)/8,
			p.g+(Z-p.g)/8,
			p.b+(Z-p.b)/8);
}

void *
init_brighten(void) {
	return brighten;
}

/*
 * auto-contrast:  a sort of AGC on the contrast/brightness settings.
 */
int
do_auto(void *param, image in, image out) {
	int i, n;
	u_long ps;
	u_long hist[Z+1];
	float map[Z+1];
	int x, y;

	n = MAX_X*MAX_Y;
	for (i = 0; i < Z+1; i++)
		hist[i] = 0;
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			hist[LUM(in[y][x])]++;
	ps = 0;
	for (i = 0; i < Z+1; i++) {
		map[i] = Z*((float)ps/((float)MAX_X*MAX_Y));
		ps += hist[i];
	}
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++) {
			Pixel p = in[y][x];
			channel l = LUM(p);
			float a = (map[l] - l)/Z;
			int r = p.r + (a*(Z-p.r));
			int g = p.g + (a*(Z-p.g));
			int b = p.b + (a*(Z-p.b));
			out[y][x] = CRGB(r,g,b);
		}
	return 1;
}
#endif

