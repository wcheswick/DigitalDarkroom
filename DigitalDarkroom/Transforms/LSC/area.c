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


#define	BROWNIAN	5	/*number of random walks/pixel */

int
do_brownian(void *param, image in, image out) {
	int x,y;

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++) {
			u_int i;
			int nx = x;
			int ny = y;
			for (i=0; i<BROWNIAN; i++) {
				nx += irand(3) - 1;
				ny += irand(3) - 1;
			}
			if (nx < 0) nx = 0;
			else if (nx >= MAX_X) nx = MAX_X-1;
			if (ny < 0) ny = 0;
			else if (ny >= MAX_Y) ny = MAX_Y-1;
			out[y][x] = in[ny][nx];
		}
	return 1;
}

#define ZOOM	2

void *
init_zoom(void) {
	int x, y;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization
		
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){CENTER_X+((x-CENTER_X)/ZOOM),
			    CENTER_Y+((y-CENTER_Y)/ZOOM)};
	return rmp;
}

/*
 * compute the r,g,b value at a fractional pixel position by
 * interpolating from the four closest pixels.
 *
 * Assumes all requested pixels are surrounded by known pixels.
 */
static Pixel
sample(image in, double x, double y) {
	u_int minx = x;
	u_int miny = y;
	double leftward = x - minx;
	double downward = y - miny;
	double dl = leftward*downward;
	double dr = (1.0-leftward)*downward;
	double ul = leftward*(1.0 - downward);
	double ur = (1.0 - leftward)*(1.0 - downward);
	Pixel dlp = in[miny][minx];
	Pixel drp = in[miny][minx+1];
	Pixel ulp = in[miny+1][minx];
	Pixel urp = in[miny+1][minx+1];
	int r = dlp.r*dl + drp.r*dr + ulp.r*ul + urp.r*ur;
	int g = dlp.g*dl + drp.g*dr + ulp.g*ul + urp.g*ur;
	int b = dlp.b*dl + drp.b*dr + ulp.b*ul + urp.b*ur;
	return CRGB(r,g,b);
}

#define	SZOOM	(ZOOM+0.1)	/* not an exact integer, for smoothness */

int
do_sampled_zoom(void *param, image in, image out) {
	int x,y;
	
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++)
			out[y][x] =
			   sample(in, (double)(CENTER_X+((x-CENTER_X))/(double)SZOOM),
			          (double)(CENTER_Y+((y-CENTER_Y))/(double)SZOOM));
	}
	return 1;
}

int
do_blur(void *param, image in, image out) {
	int x,y;
	
	for (y=1; y<MAX_Y-1; y++) {
		for (x=1; x<MAX_X-1; x++) {
			Pixel p = {0,0,0,Z};
			p.r = (in[y][x].r + in[y][x+1].r +
				     in[y][x-1].r +	in[y-1][x].r +
				     in[y+1][x].r)/5;
			p.g = (in[y][x].g + in[y][x+1].g +
				     in[y][x-1].g +	in[y-1][x].g +
				     in[y+1][x].g)/5;
			p.b = (in[y][x].b + in[y][x+1].b +
				     in[y][x-1].b +	in[y-1][x].b +
				     in[y+1][x].b)/5;
			out[y][x] = p;
		}
	}
	return 1;
}

#define N	3
#define NPIX	((2*N+1)*(2*N+1))

int
do_mean(void *param, image in, image out) {
	int x,y;
	int dx, dy;
	
	for (y=0; y<MAX_Y; y++) {	/*border*/
		for (x=0; x<N; x++)
			out[y][x] = out[y][MAX_X-x] = White;
		if (y<N || y>MAX_Y-N)
			for (x=0; x<MAX_X; x++)
				out[y][x] = White;
	}
	for (y=N; y<MAX_Y-N; y++) {
		for (x=N; x<MAX_X-N; x++) {
			int redsum=0, greensum=0, bluesum=0;

			for (dy=y-N; dy <= y+N; dy++)
				for (dx=x-N; dx <=x+N; dx++) {
					redsum += in[dy][dx].r;
					greensum += in[dy][dx].g;
					bluesum += in[dy][dx].b;
				}
			out[y][x] = SETRGB(redsum/NPIX, greensum/NPIX, bluesum/NPIX);
		}
	}
	return 1;
}

int
do_median(void *param, image in, image out) {
	int x,y;
	int dx, dy;
	u_int rh[Z+1], gh[Z+1], bh[Z+1];
	
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<N; x++)
			out[y][x] = out[y][MAX_X-x-1] = White;
		if (y<N || y>MAX_Y-N)
			for (x=0; x<MAX_X; x++)
				out[y][x] = White;
	}
	for (y=N; y<MAX_Y-N-1; y++) {
		for (x=N; x<MAX_X-N-1; x++) {
			int r, g, b;
			int sum;

			for (dx=0; dx<=Z; dx++)
				rh[dx] = bh[dx] = gh[dx] = 0;
			for (dy=y-N; dy <= y+N; dy++)
				for (dx=x-N; dx <= x+N; dx++) {
					Pixel p = in[dy][dx];
					rh[p.r]++;
					gh[p.g]++;
					bh[p.b]++;
				}
			for (r=0, sum=0; r<=Z; r++) {
				sum += rh[r];
				if (sum > NPIX/2)
					break;
			}
			for (g=0, sum=0; g<=Z; g++) {
				sum += gh[g];
				if (sum > NPIX/2)
					break;
			}
			for (b=0, sum=0; b<=Z; b++) {
				sum += bh[b];
				if (sum > NPIX/2)
					break;
			}
			out[y][x] = SETRGB(r, g, b);
		}
	}
	return 1;
}


int
do_focus(void *param, image in, image out) {
	int x,y;
	
	for (y=1; y<MAX_Y-1; y++) {
		for (x=1; x<MAX_X-1; x++) {
			int r, g, b;
			r = 5*in[y][x].r - in[y][x+1].r -
				in[y][x-1].r - in[y-1][x].r -
				in[y+1][x].r;
			g = 5*in[y][x].g - in[y][x+1].g -
				in[y][x-1].g - in[y-1][x].g -
				in[y+1][x].g;
			b = 5*in[y][x].b - in[y][x+1].b -
				in[y][x-1].b - in[y-1][x].b -
				in[y+1][x].b;
			out[y][x] = CRGB(r,g,b);
		}
	}
	return 1;
}

#ifdef notdef

/*
 * Bayer-Powell noise removal filter.
 * If the average of the neighbors differs from
 * the center by more than N, replace the center
 * with the average of the neighbors.
 */
#define	N	3

int
do_nonoise(void *param, image in, image out) {
	int x,y;
	
	for (y=1; y<MAX_Y; y++) {
		for (x=1; x<MAX_X; x++) {
			u_int ave;
			ave = (in[y-1][x-1]+in[y-1][x]+in[y-1][x+1] + 
			       in[y][x-1]  +              in[y][x+1] +
			       in[y+1][x-1]+in[y+1][x]+in[y+1][x+1])/8;
			if (abs(in[y][x] - ave) > N)
				VIDEO(x,y) = ave;
			else
				VIDEO(x,y) = in[y][x];
		}
	}
	return 1;
}
#endif
#endif

