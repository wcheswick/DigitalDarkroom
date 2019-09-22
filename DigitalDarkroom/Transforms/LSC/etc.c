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


#ifdef boring
void
spectrum(void) {
	ushort x,y;
	channel rl[MAX_X], gl[MAX_X], bl[MAX_X];
	
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++)
			rl[x] = gl[x] = bl[x] = 0;
		for (x=0+3; x<MAX_X-3; x++) {
			pixel p = T(x,y);
			ushort r = R(p);
			ushort g = G(p);
			ushort b = B(p);
			rl[x+3] += r;	/* red = r */
			rl[x+2] += r;	/* yellow = r+g */
			gl[x+2] += g;
			rl[x+1] += r/2;	/* green/yellow = r/2 + g */
			gl[x+1] += g;
			gl[x]   += g;	/* green = g */
			gl[x-1] += g/2;	/* green-blue = g/2 + b/2 */
			bl[x-1] += b;
			bl[x-2] += b;	/* blue = b */
			bl[x-3] += b;	/* violet = b + r/2 */
			rl[x-3] += r/2;
		}
		for (x=0; x<MAX_X; x++)
			T(x,y) = CRGB(rl[x]/4, gl[x]/4, bl[x]/4);
	}
}
#endif

int
do_spectrum(void *param, image in, image out) {
	int x,y;
	int rl[MAX_X], gl[MAX_X], bl[MAX_X];
	
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++)
			rl[x] = gl[x] = bl[x] = 0;
		for (x=5; x<MAX_X-5; x++) {
			Pixel p = in[y][x];
			rl[x+5] += p.r;
			gl[x]   += p.g;
			bl[x-5] += p.b;
		}
		for (x=0; x<MAX_X; x++)
			out[y][x] = CRGB(rl[x], gl[x], bl[x]);
	}
	return 1;
}

#ifdef notdef
#define Re	1
#define Gr	2
#define Bl	4

static void
show(ushort x, ushort y, char *lx, char *ly, short cx, short cy) {
	ushort x1, y1;
	short mrx = cx&Re ? 1 : 0;
	short mgx = cx&Gr ? 1 : 0;
	short mbx = cx&Bl ? 1 : 0;
	short mry = cy&Re ? 1 : 0;
	short mgy = cy&Gr ? 1 : 0;
	short mby = cy&Bl ? 1 : 0;

	for (y1=0; y1<=Z; y1++) {
		ushort ty = 2*y1;
		for (x1=0; x1<=Z; x1++) {
			channel r = mrx*x1 + mry*y1;
			channel g = mgx*x1 + mgy*y1;
			channel b = mbx*x1 + mby*y1;
			pixel p = RGB(r,g,b);
			T(x+2*x1, y+ty) = p;
			T(x+2*x1+1, y+ty) = p;
			T(x+2*x1, y+ty+1) = p;
			T(x+2*x1+1, y+ty+1) = p;
		}
	}
}


void
show_spectrum(void) {
	show(0, 0, "red", "green", Re, Gr);
	show(80, 0, "red", "blue", Re, Bl);
	show(160, 0, "green", "blue", Gr, Bl);
	show(0, 80, "red+green", "blue", Re+Gr, Bl);
	show(80, 80, "red+blue", "green", Re+Bl, Gr);
	show(160, 80, "green+blue", "red", Gr+Bl, Re);
}
#endif

#ifdef notdef
/*
 * Pure B&W edge filter.
 */
int
do_edge(void *param, image in, image out) {
	ushort x,y;
	pixel grey = RGB(Z/2, Z/2, Z/2);
	lineptr addr;
	ushort dx, dy, mfp;
	
	load_in();
	for (y=0; y<MAX_Y-2; y++) {
		addr = getlineptr(0, y);
		for (x=0; x<MAX_X-2; x++) {
			channel p = LUM(in[y][x]) + Z/2 - LUM(in[y+2][x+2]);
			addr[x] = CRGB(p, p, p);
		}
		addr[MAX_X-2] = addr[MAX_X-1] = grey;
	}
	for (y=MAX_Y-2; y<MAX_Y; y++) {
		addr = getlineptr(0, y);
		for (x=0; x<MAX_X; x++)
			addr[x] = grey;
	}
	return 1;
}

int
do_edge(void *param, image in, image out) {
	int x,y;
	int dx, dy, mfp;
	
	for (y=0; y<MAX_Y-2; y++) {
		for (x=0; x<MAX_X-2; x++) {
			int r = in[y][x].r + HALF_Z - in[y+2][x+2].r;
			int g = in[y][x].g + HALF_Z - in[y+2][x+2].g;
			int b = in[y][x].b + HALF_Z - in[y+2][x+2].b;
			out[y][x] = CRGB(r, g, b);
		}
		out[y][MAX_X-2] = out[y][MAX_X-1] = Grey;
	}
	for (y=MAX_Y-2; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++)
			out[y][x] = Grey;
	}
}

int
do_diff(void *param, image in, image out) {
	int x,y;
	int dx, dy, mfp;
	
	if (!getlast())
		return;

	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++) {
			channel r = in[y][x].r + Z/2 - last(x,y));
			channel g = in[y][x].g + Z/2 - T(x,y));
			channel b = in[y][x].b + Z/2 - T(x,y));
			T(x,y) = CRGB(r, g, b);
		}
	}
	return 1;
}
#endif

Pixel
ave(Pixel p1, Pixel p2) {
	Pixel p;
	p.r = (p1.r + p2.r + 1)/2;
	p.g = (p1.g + p2.g + 1)/2;
	p.b = (p1.b + p2.b + 1)/2;
	return p;
}

#ifdef notdef
void
monet(void) {
	short dlut[Z+1], olut[Z+1];
	ushort x, y;
	int i, j=0, len=5, k;
	short prob = Z/4;

	load_in();
	for (i=0; i<=Z; i++) {
		dlut[i] = irand(Z+1) <= prob;
		olut[i] = irand(Z+1);
	}

	i = 0;
	for (y=1; y<MAX_Y-1; y++) {
		for (x=0; x<MAX_X-len; x++) {
			if (dlut[i] && LUM(in[y-1][x]) < prob) {
				for (k=0; k<len; k++) {
					T(x+k,y-1) = in[y-1][x+k] = ave(in[y-1][x+k],in[y-1][x]);
					T(x+k,y) = in[y][x+k] = ave(in[y][x+k],in[y][x]);
					T(x+k,y+1) = in[y+1][x+k] = ave(in[y+1][x+k],in[y+1][x]);

				}
			}
			if (++i > Z) {
				i = olut[j];
				j = (j+1)%(Z+1);
			}
		}
	}
}
#endif

#ifdef notdef
#define		RAN_MASK	0x1fff
#define 	LUT_RES		(Z+1)		

float
Frand(void) {
	return((double)(rand() & RAN_MASK) / (double)(RAN_MASK));
}

void
seurat(double distortion) {
	int	y, x_strt, x_stop, x_incr;
	int	dlut[LUT_RES];			/* distort lut 		*/
	int	olut[LUT_RES];			/* ran offset lut 	*/

	int	i, j;			/* worst loop counters	*/
	int	dmkr, omkr;		/* lut index markers	*/
	int	x;

	load_in();

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
			pixel val = in[y][x];
			for(j = -2; ++j < 2;)
				for(i = -2; ++i < 2;) {
					if (dlut[dmkr]) 
						T(x+i,y+j) = in[y+j][x+i] =
							val;
					if (++dmkr >= LUT_RES) {
						dmkr = olut[omkr];
						if (++omkr >= LUT_RES)
							omkr = 0;
					}
				}
		}
	}
}

int
do_seurat(void) {
	seurat(0.1);
	return 1;
}

int
do_crazy_seurat(void) {
	seurat(0.5);
	return 1;
}
#endif

#ifdef notdef
void
fs(short depth) {
	short x, y, i;
	short maxp = depth - 1;

	for(y=0; y<MAX_Y; y++) {
		for(x=0; x<MAX_X; x++) {
			short temp;
			channel c;
			channel e = in[y][x];

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
			in[y][x] = c;
			temp = 3*e/8;
			if (y < MAX_Y-1) {
				in[y+1][x] += temp;
				if (x < MAX_X-1)
					in[y+1][x+1] += e-2*temp;
			}
			if (x < MAX_X-1)
				in[y][x+1] += temp;
		}
	}
}

int
do_fs1(void) {
	short x, y;

	load_in();
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			in[y][x] = LUM(in[y][x]);
	
	fs(1);
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++) {
			channel c = in[y][x];
			T(x,y) = RGB(c,c,c);
		}
	return 1;
}

int
do_fs2(void) {
	short x, y;

	load_in();
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			in[y][x] = LUM(in[y][x]);
	
	fs(4);
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++) {
			channel c = in[y][x];
			T(x,y) = RGB(c,c,c);
		}
	return 1;
}

int
do_cfs(void) {
	lineptr addr;
	short x, y;

	for (y=0; y<MAX_Y; y++) {
		addr = getlineptr(0, y);
		for (x=0; x<MAX_X; x++)
			in[y][x] = R(addr[x]);
	}
	fs(1);
	for (y=0; y<MAX_Y; y++) {
		addr = getlineptr(0, y);
		for (x=0; x<MAX_X; x++) {
			pixel p = addr[x];
			addr[x] = RGB(in[y][x], G(p), B(p));
		}
	}

	for (y=0; y<MAX_Y; y++) {
		addr = getlineptr(0, y);
		for (x=0; x<MAX_X; x++)
			in[y][x] = G(addr[x]);
	}
	fs(1);
	for (y=0; y<MAX_Y; y++) {
		addr = getlineptr(0, y);
		for (x=0; x<MAX_X; x++) {
			pixel p = addr[x];
			addr[x] = RGB(R(p), in[y][x], B(p));
		}
	}

	for (y=0; y<MAX_Y; y++) {
		addr = getlineptr(0, y);
		for (x=0; x<MAX_X; x++)
			in[y][x] = B(addr[x]);
	}
	fs(1);
	for (y=0; y<MAX_Y; y++) {
		addr = getlineptr(0, y);
		for (x=0; x<MAX_X; x++) {
			pixel p = addr[x];
			addr[x] = RGB(R(p), G(p), in[y][x]);
		}
	}
	return 1;
}

#endif


/*
 * Tom Duff's logo algorithm
 */
#define HEIGHT	12

channel bw_frame[MAX_Y][MAX_X];

int
stripe(int x, int p0, int p1, int c){
	if(p0==p1){
		if(c>Z){
			bw_frame[p0][x] = Z;
			return c-Z;
		}
		bw_frame[p0][x] = c;
		return 0;
	}
	if (c>2*Z) {
		bw_frame[p0][x] = Z;
		bw_frame[p1][x] = Z;
		return c-2*Z;
	}
	bw_frame[p0][x] = c/2;
	bw_frame[p1][x] = c - c/2;
	return 0;
}

void
compute_logo(void) {
	int x, y;
	int hgt = HEIGHT;
	int c;
	int y0, y1, ye;

	for (y=0; y<MAX_Y; y+= hgt) {
		if (y+hgt>MAX_Y)
			hgt = MAX_Y-y;
		for (x=0; x < MAX_X; x++) {
			c=0;
			for(y0=0; y0<hgt; y0++)
				c += bw_frame[y+y0][x];

			y0 = y+(hgt-1)/2;
			y1 = y+(hgt-1-(hgt-1)/2);
			for (; y0 >= y; --y0, ++y1)
				c = stripe(x, y0, y1, c);
		}
	}
}

int
do_logo(void *param, image in, image out) { 
	int x, y;

	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++)
			bw_frame[y][x] = LUM(in[y][x]);
	}
	compute_logo();
	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++) {
			channel c = bw_frame[y][x];
			out[y][x] = SETRGB(c, c, c);
		}
	}
	return 1;
}

#ifdef notdef
void
do_color_logo(void *param, image in, image out) { 
	int x, y;

	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++)
			bw_frame[y][x] = in[y][x].r;
	}
	compute_logo();
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			frame[y][x].r = bw_frame[y][x];

	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++)
			bw_frame[y][x] = in[y][x].g;
	}
	compute_logo();
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++)
			frame[y][x].g = bw_frame[y][x];

	for (y=0; y<MAX_Y; y++) {
		for (x=0; x<MAX_X; x++)
			bw_frame[y][x] = in[y][x].b;
	}
	compute_logo();
	for (y=0; y<MAX_Y; y++)
		for (x=0; x<MAX_X; x++) {
			Pixel p;
			p = frame[y][x];
			p.b = bw_frame[y][x];
			out[y][x] = p;
		}
}

#endif
#endif

