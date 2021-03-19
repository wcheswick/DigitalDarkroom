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
#include <stdlib.h>
#include <sys/types.h>
#include <math.h>
#include <assert.h>

#include "libutil/util.h"
#include "libio/io.h"
#include "trans.h"

#define DROOP	60

void *
init_droop_right(void) {
	int x, y;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization
	assert(MAX_X>MAX_Y);

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){x,y};

        for (x=CENTER_X; x<MAX_X; x++) {
                int droop = DROOP*(x-CENTER_X)/CENTER_X;
                if (droop > DROOP)
                        droop = DROOP;
                for (y=0; y<MAX_Y; y++)
                        if (y+droop >= MAX_Y)
                                (*rmp)[x][y] = (Point){Remap_White,0};
                        else
                                (*rmp)[x][y] = (Point){x,y+droop};
        }
	return rmp;
}

void *
init_raise_right(void) {
	int x, y;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization
	assert(MAX_X>MAX_Y);

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){x,y};

        for (x=CENTER_X; x<MAX_X; x++) {
                int droop = DROOP*(x-CENTER_X)/CENTER_X;
                if (droop > DROOP)
                        droop = DROOP;
                for (y=0; y<MAX_Y; y++)
                        if (y-droop < 0)
                                (*rmp)[x][y] = (Point){Remap_White,0};
                        else
                                (*rmp)[x][y] = (Point){x,y-droop};
        }
	return rmp;
}

void *
init_rotate_left(void) {
	int x, y;
	int indent = (MAX_X-MAX_Y)/2; /* assume MAX_X>MAX_Y */
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization
	assert(MAX_X>MAX_Y);

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){Remap_White,0};

	for (y=0; y<MAX_Y; y++)
		for (x=indent; x<indent+MAX_Y; x++)
			(*rmp)[x][y] = (Point){y+indent, MAX_Y-1-(x-indent)};
	return rmp;
}

void *
init_rotate_right(void) {
	int x, y;
	int indent = (MAX_X-MAX_Y)/2; /* assume MAX_X>MAX_Y */
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization
	assert(MAX_X>MAX_Y);

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){Remap_White,0};

	for (x=indent; x<indent+MAX_Y; x++)
		for (y=0; y<MAX_Y; y++)
			(*rmp)[x][y] = (Point){MAX_X-indent-1-y, x-indent};
	return rmp;
}

void *
init_kite(void) {
	int x, y;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization

	for (y=0; y<MAX_Y; y++) {
		int ndots;

		if (y <= CENTER_Y)
			ndots = (y*(MAX_X-1))/MAX_Y;
		else
			ndots = ((MAX_Y-y-1)*(MAX_X))/MAX_Y;

		(*rmp)[CENTER_X][y] = (Point){CENTER_X,y};
		(*rmp)[0][y] = (Point){Remap_White,0};
		
		for (x=1; x<=ndots; x++) {
			int dist = (x*(CENTER_X-1))/ndots;

			(*rmp)[CENTER_X+x][y] = (Point){CENTER_X + dist,y};
			(*rmp)[CENTER_X-x][y] = (Point){CENTER_X - dist,y};
		}
		for (x=ndots; x<CENTER_X; x++)
			(*rmp)[CENTER_X+x][y] = (*rmp)[CENTER_X-x][y] =
				(Point){Remap_White,0};
	}
	return rmp;
}

void *
init_copy_right(void) {
	int x, y;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization

	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X/2; x++)
			(*rmp)[x][y] = (Point){x,y};
		for (x=MAX_X/2; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){MAX_X-x-1,y};
	}
	return rmp;
}

void *
init_mirror(void) {
	int x, y;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){MAX_X-x-1,y};
	return rmp;
}

int
do_shear(void *param, image in, image out) {
	int x, y, dx, dy, r, yshift[MAX_X];
	
	for (x = r = 0; x < MAX_X; x++) {
		if (irand(256) < 128)
			r--;
		else
			r++;
		yshift[x] = r;
	}
	for (y = 0; y < MAX_Y; y++) {
		if (irand(256) < 128)
			r--;
		else
			r++;
		for (x = 0; x < MAX_X; x++) {
			dx = x+r; dy = y+yshift[x];
			if (dx >= MAX_X || dy >= MAX_Y ||
			    dx < 0 || dy < 0)
				out[y][x] = White;
			else
				out[y][x] = in[dy][dx];
		}
	}
	return 1;
}

#define A	(2.5*M_PI)
#define C	512
int
do_smear(void *param, image in, image out) {
	int x,y;
		
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++) {
			int dx = MAX_X*cos(((x-C)*A)*2/MAX_X) / 6;
			out[y][x] = in[y][x + dx];
		}
					
	}
	return 1;
}

#define NSHOWER	2500
#define SHOWERSIZE	5

int
do_shower(void *param, image in, image out) {
	int i, x, y;

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			out[y][x] = White;
	for(i=0; i<NSHOWER; i++) {
		int x = irand(MAX_X-1);
		int y = irand(MAX_Y-1);
		int x1, y1;
		Pixel p = in[y][x];
		
		for (y1=y-SHOWERSIZE; y1<=y+SHOWERSIZE; y1++) {
			if (y1 < 0 || y1 >= MAX_Y)
				continue;
			for (x1=x-SHOWERSIZE; x1<=x+SHOWERSIZE; x1++) {
				if (x1 < 0 || x1 >= MAX_X)
					continue;
				out[y1][x1] = p;
			}
		}
	}
	return 1;
}

#define	D	8
#define P	20	/*cycles/picture*/

void *
init_shower2(void) {
	int x, y;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization
		
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){x,y};
	for (y=0; y<MAX_Y; y++)
		for (x=0+D; x<MAX_X-D; x++)
			(*rmp)[x][y] = (Point){x+(int)(D*sin(P*x*2*M_PI/MAX_X)), y};
	return rmp;
}

void *
init_cylinder(void) {
	int x, y;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<=CENTER_X; x++) {
			int fromx = CENTER_X*sin((M_PI/2)*x/CENTER_X);
			assert(fromx >= 0 && fromx < MAX_X);
			(*rmp)[x][y] = (Point){fromx, y};
			(*rmp)[MAX_X-1-x][y] = (Point){MAX_X-1-fromx, y};
		}
	return rmp;
}

void *
init_shift_left(void) {
	int x, y;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization

	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X-2; x++)
			(*rmp)[x][y] = (Point){x+1, y};
		(*rmp)[MAX_X-1][y] = (Point){Remap_White,0};
	}
	return rmp;
}

void *
init_shift_right(void) {
	int x, y;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization

	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X-2; x++)
			(*rmp)[x+1][y] = (Point){x, y};
		(*rmp)[0][y] = (Point){Remap_White,0};
	}
	return rmp;
}

static void
init_pixels(int pixsize, remap *rmp) {
	int x,y;
	
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){(x/pixsize)*pixsize,
				(y/pixsize)*pixsize};
}

void *
init_pixels4(void) {
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization

	init_pixels(4, rmp);
	return rmp;
}

void *
init_pixels8(void) {
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization

	init_pixels(8, rmp);
	return rmp;
}

int
do_bleed(void *param, image in, image out) {
	int x,y;

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			out[y][x] = White;
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++) {
			channel pix = LUM(in[y][x])>>4;
			int shift = pix;
			int newy = y - shift;
			if (newy >= 0)
				out[newy][x] = in[y][x];
			else
				out[y][x] = in[y][x];
		}
	}
	return 1;
}

#ifdef notdef
/* XXX */
void
do_melt(param *void, image in, image out) {
	int x, y, k;

	for (k=0; k<MAX_X*MAX_Y/8; k++) {
		x = irand(MAX_X);
		y = irand(MAX_Y-1);
		
		while (y > 0 && LUM(out[y][x]) <= LUM(out[y-1][x])) {
			pixel t = out[y][x];
			out[y][x] = out[y+1][x];
			out[y+1][x] = out[y][x];
			y--;
		}
	}
} 
#endif
#endif
