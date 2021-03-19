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
#include <string.h>
#include <assert.h>

#include "libutil/util.h"
#include "libio/io.h"
#include "trans.h"

/*
 * These two probably don't belong in this routine.
 */
int
irand(int i) {
	return random() % i;
}

/*
 * Melt is broken
 */
#define A	(2.5*M_PI)
#define C	512

int
do_melt(void *param, image in, image out) {
	int x, y, k;

	memcpy(video_out, in, sizeof(video_out));
	for (k=0; k<MAX_X*MAX_Y/8; k++) {
		x = random() % MAX_X;
		y = random() % MAX_Y-1;
		
		while (y > 0 && LUM(out[y][x]) <= LUM(out[y-1][x])) {
			Pixel t = out[y][x];
			out[y][x] = out[y+1][x];
			out[y+1][x] = t;
			y--;
		}
	}
	return 1;
} 

/*
 * Polar transforms
 */

#define MAX_R	((double)(CENTER_Y))

double R;

void
init_polar(void) {
	R = hypot(MAX_X, MAX_Y);
}

/*
 * Create a bit-movement lookup table for a given polar function
 */
static remap *
setup_polar(Point func(double r, double a)) {
	int i, j;
	remap *rmp = (remap *)malloc(sizeof(remap));

	assert(rmp);	// out of memory during initialization

	for (i=0; i<=CENTER_X; i++) {
		for (j=0; j<=CENTER_Y; j++) {
			double r = hypot(i, j);
			double a;
			if (i == 0 && j == 0)
				a = 0;
			else
				a = atan2(j, i);
			(*rmp)[CENTER_X-i][CENTER_Y-j] = func(r, M_PI+a);
			if (CENTER_Y+j < MAX_Y)
				(*rmp)[CENTER_X-i][CENTER_Y+j] = func(r, M_PI-a);
			if (CENTER_X+i < MAX_X) {
				if (CENTER_Y+j < MAX_Y)
					(*rmp)[CENTER_X+i][CENTER_Y+j] = func(r, a);
				(*rmp)[CENTER_X+i][CENTER_Y-j] = func(r, -a);
			}
		}
	}
	return rmp;
}

Point
compute_cone(double r, double a) {
	double r1 = sqrt(r*MAX_R);
	return (Point){CENTER_X+(int)(r1*cos(a)), CENTER_Y+(int)(r1*sin(a))};
}

void *
init_cone(void) {
	return setup_polar(compute_cone);
}

#define INRANGE(p)	(p.x >= 0 && p.x < MAX_X && p.y >= 0 && p.y < MAX_Y)

Point
compute_twist(double r, double a) {
	double newa = a + (r/3.0)*(M_PI/180.0);
	Point p;
	p.x = CENTER_X + r*cos(newa);
	p.y = CENTER_Y + r*sin(newa);
	if (INRANGE(p))
		return p;
	else
		return (Point){Remap_White,0};
}

void *
init_twist(void) {
	return setup_polar(compute_twist);
}

Point
compute_dali(double r, double a) {
	Point p;

	p.x = CENTER_X + r*cos(a);
	p.y = CENTER_Y + r*sin(a);
	p.x = CENTER_X + (r*cos(a + (p.y*p.x/17000.0)));
	if (p.x >= 0 && p.x < MAX_X)
		return p;
	else
		return (Point){Remap_White,0};
}

void *
init_dali(void) {
	return setup_polar(compute_dali);
}

/* the following is cool, but broken */

Point
compute_kentwist(double r, double a) {
	Point p;
	p.x = CENTER_X+(int)(r*cos(a));
	p.y = CENTER_Y+(int)(r*sin(a+r/30.0));
	if (INRANGE(p))
		return p;
	else
		return (Point){Remap_White,0};
}

void *
init_slicer(void) {
	int x, y, r = 0;
	int dx, dy, xshift[MAX_Y], yshift[MAX_X];
	remap *rmp = (remap *)malloc(sizeof(remap));

	assert(rmp);	// out of memory during initialization

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){x,y};

	for (x = dx = 0; x < MAX_X; x++) {
		if (dx == 0) {
			r = (random()&63) - 32;
			dx = 8+(random()&31);
		} else
			dx--;
		yshift[x] = r;
	}

	for (y = dy = 0; y < MAX_Y; y++) {
		if (dy == 0) {
			r = (random()&63) - 32;
			dy = 8+(random()&31);
		} else
			dy--;
		xshift[y] = r;
	}

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++) {
			dx = x + xshift[y];
			dy = y + yshift[x];
			if (dx < MAX_X && dy < MAX_Y && dx>=0 && dy>=0)
				(*rmp)[x][y] = (Point){dx,dy};
		}
	return rmp;
}

void *
init_kentwist(void) {
	return setup_polar(compute_kentwist);
}

#ifdef NOTUSED
int
do_remap(void *param, image in, image out) {
	remap *map = (remap *)param;
	int x,y;

	if (map == 0)
		return 0;		/* debugging */

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++) {
			Point from = (*map)[x][y];
			if (from.x == Remap_White)
				out[y][x] = White;
			else if (from.x == Remap_Black)
				out[y][x] = Black;
            else if (from.x == Remap_Red)
                out[y][x] = Red;
            else if (from.x == Remap_Yellow)
                out[y][x] = Yellow;
			else
				out[y][x] = in[from.y][from.x];
		}
	return 1;
}
#endif

static Pixel
ave(Pixel p1, Pixel p2) {
	Pixel p;
	p.r = (p1.r + p2.r + 1)/2;
	p.g = (p1.g + p2.g + 1)/2;
	p.b = (p1.b + p2.b + 1)/2;
	p.a = Z;
	return p;
}

int
monet(void *param, image in, image out) {
	int dlut[Z+1], olut[Z+1];
	int x, y;
	int i, j=0, len=5, k;
	int prob = Z/4;
	image frame;

	for (i=0; i<=Z; i++) {
		dlut[i] = irand(Z+1) <= prob;
		olut[i] = irand(Z+1);
	}

	i = 0;
	memcpy(frame, in, sizeof(frame));
	memset(video_out, 0, sizeof(video_out));
	for (y=1; y<MAX_Y-1; y++) {
		for (x=0; x<MAX_X-len; x++) {
			if (dlut[i] && LUM(frame[y-1][x]) < prob) {
				for (k=0; k<len; k++) {
					out[y-1][x+k] = frame[y-1][x+k] =
						ave(frame[y-1][x+k],frame[y-1][x]);
					out[y  ][x+k] = frame[y][x+k] =
						ave(frame[y][x+k],frame[y][x]);
					out[y+1][x+k] = frame[y+1][x+k] =
						ave(frame[y+1][x+k],frame[y+1][x]);

				}
			}
			if (++i > Z) {
				i = olut[j];
				j = (j+1)%(Z+1);
			}
		}
	}
	return 1;
}

#define		RAN_MASK	0x1fff
#define 	LUT_RES		(Z+1)		

static float
Frand(void) {
	return((double)(random() & RAN_MASK) / (double)(RAN_MASK));
}

static remap *
seurat(double distortion) {
	int	y, x_strt, x_stop, x_incr;
	int	dlut[LUT_RES];		/* distort lut 		*/
	int	olut[LUT_RES];		/* ran offset lut 	*/

	int	i, j;			/* worst loop counters	*/
	int	dmkr, omkr;		/* lut index markers	*/
	int	x;
	remap *rmp = (remap *)malloc(sizeof(remap));

	assert(rmp);	// out of memory during initialization

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			(*rmp)[x][y] = (Point){x,y};

	for(i = 0; i < LUT_RES; i++) {
		dlut[i] = (Frand() <= distortion);
		olut[i] = LUT_RES * Frand();
	}

	dmkr = omkr = 0;

	for (y = 1; y < MAX_Y - 1; y++) {
		if ((y % 2)) {
			x_strt = 1; x_stop = MAX_X - 1; x_incr = 1;
		} else {
			x_strt = MAX_X - 2; x_stop = 0; x_incr = -1;
		}
		for(x = x_strt; x != x_stop; x += x_incr){
			for(j = -2; ++j < 2;)
				for(i = -2; ++i < 2;) {
					if (dlut[dmkr])
						(*rmp)[x+i][y+j] = (Point){x,y};
					if (++dmkr >= LUT_RES) {
						dmkr = olut[omkr];
						if (++omkr >= LUT_RES)
							omkr = 0;
					}
				}
		}
	}
	return rmp;
}

void *
init_seurat(void) {
	return seurat(0.2);	// was 0.1. crazy seurat is 0.5
}

#define	N	2

#if 0

#define N_BUCKETS	(Z+1)
#define	BUCKET(x)	(x)
#define	UNBUCKET(x)	(x)
#else
#define N_BUCKETS	(32)
#define	BUCKET(x)	((x)>>3)
#define UNBUCKET(x)	((x)<<3)
#endif

int
do_new_oil(void *param, image in, image out) {
	int rmax, gmax, bmax;
	u_int x,y;
	int dx, dy, dz;
	int rh[N_BUCKETS], gh[N_BUCKETS], bh[N_BUCKETS];
	Pixel p = {0,0,0,Z};
	
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<N; x++)
			out[y][x] = out[y][MAX_X-x-1] = White;
		if (y<N || y>MAX_Y-N)
			for (x=0; x<MAX_X; x++)
				out[y][x] = White;
	}

	for (dz=0; dz<N_BUCKETS; dz++)
		rh[dz] = bh[dz] = gh[dz] = 0;

	/*
	 * Initialize our histogram with the upper left NxN pixels
	 */
	y=N;
	x=N;
	for (dy=y-N; dy<=y+N; dy++)
		for (dx=x-N; dx<=x+N; dx++) {
			p = in[dy][dx];
			rh[BUCKET(p.r)]++;
			gh[BUCKET(p.g)]++;
			bh[BUCKET(p.b)]++;
		}
	rmax=0, gmax=0, bmax=0;
	for (dz=0; dz<N_BUCKETS; dz++) {
		if (rh[dz] > rmax) {
			p.r = UNBUCKET(dz);
			rmax = rh[dz];
		}
		if (gh[dz] > gmax) {
			p.g = UNBUCKET(dz);
			gmax = gh[dz];
		}
		if (bh[dz] > bmax) {
			p.b = UNBUCKET(dz);
			bmax = bh[dz];
		}
	}
	out[y][x] = p;

	while (1) {
		/*
		 * Creep across the row one pixel at a time updating our
		 * histogram by subtracting the contribution of the left-most
		 * edge and adding the new right edge.
		 */
		for (x++; x<MAX_X-N; x++) {
			for (dy=y-N; dy<=y+N; dy++) {
				Pixel op = in[dy][x-N-1];
				Pixel ip = in[dy][x+N];
				rh[BUCKET(op.r)]--;
				rh[BUCKET(ip.r)]++;
				gh[BUCKET(op.g)]--;
				gh[BUCKET(ip.g)]++;
				bh[BUCKET(op.b)]--;
				bh[BUCKET(ip.b)]++;
			}
			rmax=0, gmax=0, bmax=0;
			for (dz=0; dz<N_BUCKETS; dz++) {
				if (rh[dz] > rmax) {
					p.r = UNBUCKET(dz);
					rmax = rh[dz];
				}
				if (gh[dz] > gmax) {
					p.g = UNBUCKET(dz);
					gmax = gh[dz];
				}
				if (bh[dz] > bmax) {
					p.b = UNBUCKET(dz);
					bmax = bh[dz];
				}
			}
			out[y][x] = p;
		}

		/*
		 * Now move our histogram down a pixel on the right hand side,
		 * and recompute our histograms.
		 */
		y++;
		if (y+N >= MAX_Y)
			break;		/* unfortunate place to break out of the loop */
		x = MAX_X - N - 1;
		for (dx=x-N; dx<=x+N; dx++) {
			Pixel op = in[y-N-1][dx];
			Pixel ip = in[y+N][dx];
			rh[BUCKET(op.r)]--;
			rh[BUCKET(ip.r)]++;
			gh[BUCKET(op.g)]--;
			gh[BUCKET(ip.g)]++;
			bh[BUCKET(op.b)]--;
			bh[BUCKET(ip.b)]++;
		}
		rmax=0, gmax=0, bmax=0;
		for (dz=0; dz<N_BUCKETS; dz++) {
			if (rh[dz] > rmax) {
				p.r = UNBUCKET(dz);
				rmax = rh[dz];
			}
			if (gh[dz] > gmax) {
				p.g = UNBUCKET(dz);
				gmax = gh[dz];
			}
			if (bh[dz] > bmax) {
				p.b = UNBUCKET(dz);
				bmax = bh[dz];
			}
		}
		out[y][x] = p;
	
		/*
		 * Now creep the histogram back to the left, one pixel at a time
		 */
		for (x=x-1; x>=N; x--) {
			for (dy=y-N; dy<=y+N; dy++) {
				Pixel op = in[dy][x+N+1];
				Pixel ip = in[dy][x-N];
				rh[BUCKET(op.r)]--;
				rh[BUCKET(ip.r)]++;
				gh[BUCKET(op.g)]--;
				gh[BUCKET(ip.g)]++;
				bh[BUCKET(op.b)]--;
				bh[BUCKET(ip.b)]++;
			}
			rmax=0, gmax=0, bmax=0;
			for (dz=0; dz<N_BUCKETS; dz++) {
				if (rh[dz] > rmax) {
					p.r = UNBUCKET(dz);
					rmax = rh[dz];
				}
				if (gh[dz] > gmax) {
					p.g = UNBUCKET(dz);
					gmax = gh[dz];
				}
				if (bh[dz] > bmax) {
					p.b = UNBUCKET(dz);
					bmax = bh[dz];
				}
			}
        }
        out[y][x] = p;

		/*
		 * Move our histogram down one pixel on the left side.
		 */
		y++;
		x = N;
		if (y+N >= MAX_Y)
			break;		/* unfortunate place to break out of the loop */
		for (dx=x-N; dx<=x+N; dx++) {
			Pixel op = in[y-N-1][dx];
			Pixel ip = in[y+N][dx];
			rh[BUCKET(op.r)]--;
			rh[BUCKET(ip.r)]++;
			gh[BUCKET(op.g)]--;
			gh[BUCKET(ip.g)]++;
			bh[BUCKET(op.b)]--;
			bh[BUCKET(ip.b)]++;
		}
		rmax=0, gmax=0, bmax=0;
		for (dz=0; dz<N_BUCKETS; dz++) {
			if (rh[dz] > rmax) {
				p.r = UNBUCKET(dz);
				rmax = rh[dz];
			}
			if (gh[dz] > gmax) {
				p.g = UNBUCKET(dz);
				gmax = gh[dz];
			}
			if (bh[dz] > bmax) {
				p.b = UNBUCKET(dz);
				bmax = bh[dz];
			}
		}
		out[y][x] = p;
	}
	return 1;
}

/* this runs at about 2.4 frames per second on digitalis using hx */

int
do_oil(void *param, image in, image out) {
	u_int x,y;
	int dx, dy;
	u_int rh[Z+1], gh[Z+1], bh[Z+1];
	
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<N; x++)
			out[y][x] =out[y][MAX_X-x-1] = White;
		if (y<N || y>MAX_Y-N)
			for (x=0; x<MAX_X; x++)
				out[y][x] = White;
	}
	for (y=N; y<MAX_Y-N; y++) {
		for (x=N; x<MAX_X-N; x++) {
			Pixel p = {0,0,0,Z};
			int rmax=0, gmax=0, bmax=0;

			for (dx=0; dx<=Z; dx++)
				rh[dx] = bh[dx] = gh[dx] = 0;
			for (dy=y-N; dy < y+N; dy++)
				for (dx=x-N; dx <x+N; dx++) {
					Pixel p = in[dy][dx];
					rh[p.r]++;
					gh[p.g]++;
					bh[p.b]++;
				}
			for (dx=0; dx<=Z; dx++) {
				if (rh[dx] > rmax) {
					p.r = dx;
					rmax = rh[dx];
				}
				if (gh[dx] > gmax) {
					p.g = dx;
					gmax = gh[dx];
				}
				if (bh[dx] > bmax) {
					p.b = dx;
					bmax = bh[dx];
				}
			}
			out[y][x] = p;
		}
	}
	return 1;
}

/* Monochrome floyd-steinberg */

static void
fs(int depth, int buf[MAX_Y][MAX_X]) {
	int x, y, i;
	int maxp = depth - 1;

	for(y=0; y<MAX_Y; y++) {
		for(x=0; x<MAX_X; x++) {
			int temp;
			int c = 0;
			int e = buf[y][x];

			switch (depth) {
			case 1:	if (e > Z/2) {
					i=0;
					c = Z;
					e -= Z;
				} else {
					i = 1;
					c = 0;
				}
				break;
			case 4:	i = (depth*e)/Z;
				if (i<0)
					i=0;
				else if (i>maxp)
					i=maxp;
				e -= (i*Z)/3;
				i = maxp-i;
				c = Z - i*Z/(depth-1);
				break;
			}
			buf[y][x] = c;
			temp = 3*e/8;
			if (y < MAX_Y-1) {
				buf[y+1][x] += temp;
				if (x < MAX_X-1)
					buf[y+1][x+1] += e-2*temp;
			}
			if (x < MAX_X-1)
				buf[y][x+1] += temp;
		}
	}
}

int
do_cfs(void *param, image in, image out) {
	int x, y;
	int r[MAX_Y][MAX_X], g[MAX_Y][MAX_X], b[MAX_Y][MAX_X];

	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++) {
			r[y][x] = in[y][x].r;
			g[y][x] = in[y][x].g;
			b[y][x] = in[y][x].b;
		}

	fs(4, r);
	fs(4, g);
	fs(4, b);
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++) {
			Pixel p = {0,0,0,Z};
			p.r = r[y][x];
			p.g = g[y][x];
			p.b = b[y][x];
			out[y][x] = p;
		}
	}
	return 1;
}

int
do_neg_sobel(void *param, image in, image out) {
	int x, y;
	
	for (y=1; y<MAX_Y-1; y++) {
		for (x=1; x<MAX_X-1; x++) {
			int aa, bb, s;
			Pixel p = {0,0,0,Z};
			aa = R(in[y-1][x-1])+R(in[y-1][x])*2+
				R(in[y-1][x+1])-
			    R(in[y+1][x-1])-R(in[y+1][x])*2-
				R(in[y+1][x+1]);
			bb = R(in[y-1][x-1])+R(in[y][x-1])*2+
				R(in[y+1][x-1])-
			    R(in[y-1][x+1])-R(in[y][x+1])*2-
				R(in[y+1][x+1]);
			s = sqrt(aa*aa + bb*bb);
			if (s > Z)
				p.r = Z;
			else
				p.r = s;

			aa = G(in[y-1][x-1])+G(in[y-1][x])*2+
				G(in[y-1][x+1])-
			    G(in[y+1][x-1])-G(in[y+1][x])*2-
				G(in[y+1][x+1]);
			bb = G(in[y-1][x-1])+G(in[y][x-1])*2+
				G(in[y+1][x-1])-
			    G(in[y-1][x+1])-G(in[y][x+1])*2-
				G(in[y+1][x+1]);
			s = sqrt(aa*aa + bb*bb);
			if (s > Z)
				p.g = Z;
			else
				p.g = s;

			aa = B(in[y-1][x-1])+B(in[y-1][x])*2+
				B(in[y-1][x+1])-
			    B(in[y+1][x-1])-B(in[y+1][x])*2-
				B(in[y+1][x+1]);
			bb = B(in[y-1][x-1])+B(in[y][x-1])*2+
				R(in[y+1][x-1])-
			    B(in[y-1][x+1])-B(in[y][x+1])*2-
				B(in[y+1][x+1]);
			s = sqrt(aa*aa + bb*bb);
			if (s > Z)
				p.b = Z;
			else
				p.b = s;
			p.r = Z - p.r;
			p.g = Z - p.g;
			p.b = Z - p.b;
			out[y][x] = p;
		}
	}
	return 1;
}

#define	S	60		// pixels on a side
#define SQRT34	0.8660254	// sqrt(3/4)
#define D	((int)(S*SQRT34))	// x distance to the center of the block

/*
 * corner zero of each block is the unshared corner.  Corners are labeled
 * clockwise, and so are the block faces.
 */

struct block {
	Point	f[3][4];	// three faces, four corners
} block;

void
make_block(Point origin, struct block *b) {
	b->f[0][0] = origin;
	b->f[0][1] = b->f[1][3] = (Point){origin.x,origin.y+S};
	b->f[0][2] = b->f[1][2] = b->f[2][2] =
		(Point){origin.x+D,origin.y+(S/2)};
	b->f[0][3] = b->f[2][1] = (Point){origin.x+D,origin.y-(S/2)};

	b->f[1][0] = (Point){origin.x+D, origin.y + 3*S/2};
	b->f[1][1] = b->f[2][3] = (Point){origin.x+2*D, origin.y+S};

	b->f[2][0] = (Point){origin.x+2*D, origin.y};
}

#define NX_BLOCKS	(int)((MAX_X/(2*D)) + 2)
#define NY_BLOCKS	(int)((MAX_Y/(3*S/2)) + 2)

struct block_list {
	int	x,y;	// the location of the lower left corner
	struct block b;
} block_list[NX_BLOCKS][NY_BLOCKS];

void
layout_blocks(void) {
	int row, col;
	Point start = {-irand(D/2), -irand(S/2)};

	for (row=0; row<NY_BLOCKS; ) {
		Point origin = start;
		for (col=0; col<NX_BLOCKS; col++) {
			make_block(origin, &block_list[col][row].b);
			origin.x = origin.x + 2*D;
		}
		if (++row & 1) { /* if odd rows are staggered to the left */
			start.x -= D;
			start.y += (3*S/2);
		} else {
			start.x += D;
			start.y += (3*S/2);
		}
	}
}

void
put_image(remap *rmp, Point corners[4]) {
	int x, y;
	float dxx, dxy, dyx, dyy;
#ifdef notdef
	int xstart;
	int ll = 2;
	int lr = 1;
	int ul = 3;
#else
	int ll = irand(4);
	int dir = irand(1)*2;
	int lr = (ll + 3 + dir) % 4;
	int ul = (ll + 1 + dir) % 4;
#endif

	dxx = (corners[lr].x - corners[ll].x)/(float)MAX_X;	
	dxy = (corners[lr].y - corners[ll].y)/(float)MAX_X;
	dyx = (corners[ul].x - corners[ll].x)/(float)MAX_Y;	
	dyy = (corners[ul].y - corners[ll].y)/(float)MAX_Y;

	for (y=0; y<MAX_Y; y++) {	// we could actually skip some of these
		for (x=0; x<MAX_X; x++)	{
			Point p;
			p.x = corners[ll].x + y*dyx + x*dxx;
			p.y = corners[ll].y + y*dyy + x*dxy;
			if (INRANGE(p))
				(*rmp)[p.x][p.y] = (Point){x,y};
		}
	}
}

void *
init_escher(void) {
	int row, col, x, y, i, j;
	remap *rmp = (remap *)malloc(sizeof(remap));
	assert(rmp);	// out of memory during initialization

	for (x=0; x<MAX_X; x++)
		for (y=0; y<MAX_Y; y++)
			(*rmp)[x][y] = (Point){Remap_White,0};
	layout_blocks();
	for (row=0; row<NY_BLOCKS; row++)
		for (col=0; col<NX_BLOCKS; col++)
			for (i=0; i<3; i++)	// for each face
				for (j=0; j<4; j++) {	// each corner
					Point p = block_list[col][row].b.f[i][j];
					if (INRANGE(p))
						(*rmp)[p.x][p.y] =
							(Point){Remap_Black,0};
				}
	for (row=0; row<NY_BLOCKS; row++)
		for (col=0; col<NX_BLOCKS; col++)
			for (i=0; i<3; i++)
				put_image(rmp, block_list[col][row].b.f[i]);
	return rmp;
}

#endif

