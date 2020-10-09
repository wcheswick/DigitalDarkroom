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

#endif

