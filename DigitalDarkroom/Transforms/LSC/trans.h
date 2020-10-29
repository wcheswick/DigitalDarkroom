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

/*
* include file for image transform library
 */

#define CRGB(r,g,b)	SETRGB(CLIP(r), CLIP(g), CLIP(b))
#define HALF_Z		(Z/2)

#define	Remap_White	(-1)
#define	Remap_Black	(-2)
#define Remap_Red   (-3)

typedef Point struct {
    int x, y;
};

typedef void *init_proc(void);

typedef int transform_t(void *param, image in, image out);

/* in trans.c */
extern	int irand(int i);
extern	int ptinrect(Point p, Rectangle r);

/* in trans.c */

extern	init_proc init_cone;
extern	init_proc init_bignose;
extern	init_proc init_fisheye;
extern	init_proc init_dali;
extern	init_proc init_andrew;
extern	init_proc init_twist;
extern	init_proc init_kentwist;
extern	init_proc init_escher;
extern	init_proc init_slicer;
extern	init_proc init_seurat;

extern	init_proc init_colorize;
extern	init_proc init_swapcolors;
extern	init_proc init_lum;
extern	init_proc init_high;

extern	transform_t do_remap;
extern	transform_t do_point;

extern	void init_polar(void);

/* in point.c */
extern	transform_t op_art;
extern	transform_t do_auto;

/* in geom.c */
extern	init_proc init_kite;
extern	init_proc init_pixels4;
extern	init_proc init_pixels8;
extern	init_proc init_rotate_right;
extern	init_proc init_copy_right;
extern	init_proc init_mirror;
extern	init_proc init_droop_right;
extern	init_proc init_raise_right;
extern	init_proc init_shower2;
extern	init_proc init_cylinder;
extern	init_proc init_shift_left;
extern	init_proc init_shift_right;

extern	transform_t do_shear;
extern	transform_t do_smear;
extern	transform_t do_shower;
extern	transform_t do_bleed;
extern	transform_t do_melt;
extern	transform_t do_shift_left;
extern	transform_t do_shift_right;

/* in area.c */
extern	init_proc init_zoom;

extern	transform_t do_blur;
extern	transform_t do_fs1;
extern	transform_t do_fs2;
extern	transform_t do_focus;
extern	transform_t do_sampled_zoom;
extern	transform_t do_mean;
extern	transform_t do_median;

/* in etc.c */
extern	transform_t do_diff;
extern	transform_t do_logo;
extern	transform_t do_color_logo;
extern	transform_t do_spectrum;

extern	void init_polar(void);

extern	transform_t do_point;

extern	transform_t do_bleed;
extern	transform_t do_slicer;
extern	transform_t do_melt;
extern	transform_t do_smear;
extern	transform_t monet;
extern	transform_t do_seurat;
extern	transform_t do_crazy_seurat;

extern	transform_t do_new_oil;
extern	transform_t do_cfs;
extern	transform_t do_sobel;
extern	transform_t do_neg_sobel;
extern	transform_t cartoon;
extern	transform_t do_edge;
