/* 
 * colorblind.c
 *
 * This is the guts of the colorblind computation from cdisplay_colorblind.c
 *
 * Bill Cheswick, March 2007
 *
 * Original GIMP code Copyright (C) 1995-1997 Spencer Kimball and Peter Mattis
 * Copyright (C) 2002-2003 Michael Natterer <mitch@gimp.org>,
 *                         Sven Neumann <sven@gimp.org>,
 *                         Robert Dougherty <bob@vischeck.com> and
 *                         Alex Wade <alex@vischeck.com>
 *
 * This code is an implementation of an algorithm described by Hans Brettel,
 * Francoise Vienot and John Mollon in the Journal of the Optical Society of
 * America V14(10), pg 2647. (See http://vischeck.com/ for more info.)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifdef notdef
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <sys/types.h>

#include "libutil/util.h"
#include "libio/io.h"
#include "colorblind.h"

int deficiency;
double inflection;

double rgb2lms[9];
double lms2rgb[9];
double gammaRGB[3];

static void
colorblind_init (void) {
  /* For most modern Cathode-Ray Tube monitors (CRTs), the following
   * are good estimates of the RGB->LMS and LMS->RGB transform
   * matrices.  They are based on spectra measured on a typical CRT
   * with a PhotoResearch PR650 spectral photometer and the Stockman
   * human cone fundamentals. NOTE: these estimates will NOT work well
   * for LCDs!
   */
  rgb2lms[0] = 0.05059983;
  rgb2lms[1] = 0.08585369;
  rgb2lms[2] = 0.00952420;

  rgb2lms[3] = 0.01893033;
  rgb2lms[4] = 0.08925308;
  rgb2lms[5] = 0.01370054;

  rgb2lms[6] = 0.00292202;
  rgb2lms[7] = 0.00975732;
  rgb2lms[8] = 0.07145979;

  lms2rgb[0] =  30.830854;
  lms2rgb[1] = -29.832659;
  lms2rgb[2] =   1.610474;

  lms2rgb[3] =  -6.481468;
  lms2rgb[4] =  17.715578;
  lms2rgb[5] =  -2.532642;

  lms2rgb[6] =  -0.375690;
  lms2rgb[7] =  -1.199062;
  lms2rgb[8] =  14.273846;

  /* The RGB<->LMS transforms above are computed from the human cone
   * photo-pigment absorption spectra and the monitor phosphor
   * emission spectra. These parameters are fairly constant for most
   * humans and most montiors (at least for modern CRTs). However,
   * gamma will vary quite a bit, as it is a property of the monitor
   * (eg. amplifier gain), the video card, and even the
   * software. Further, users can adjust their gammas (either via
   * adjusting the monitor amp gains or in software). That said, the
   * following are the gamma estimates that we have used in the
   * Vischeck code. Many colorblind users have viewed our simulations
   * and told us that they "work" (simulated and original images are
   * indistinguishabled).
   */
  gammaRGB[0] = 2.1;
  gammaRGB[1] = 2.0;
  gammaRGB[2] = 2.1;
}

double a1, b1, c1;
double a2, b2, c2;

Pixel
to_colorblind(int r, int g, int b) {
  double              tmp;
  double              red, green, blue, redOld, greenOld;
	Pixel p;


        /* Remove gamma to linearize RGB intensities */
        red   = pow (r/255.0,   1.0 / gammaRGB[0]);
        green = pow (g/255.0, 1.0 / gammaRGB[1]);
        blue  = pow (b/255.0,  1.0 / gammaRGB[2]);

        /* Convert to LMS (dot product with transform matrix) */
        redOld   = red;
        greenOld = green;

        red   = redOld * rgb2lms[0] + greenOld * rgb2lms[1] + blue * rgb2lms[2];
        green = redOld * rgb2lms[3] + greenOld * rgb2lms[4] + blue * rgb2lms[5];
        blue  = redOld * rgb2lms[6] + greenOld * rgb2lms[7] + blue * rgb2lms[8];

        switch (deficiency)
          {
          case DEUTERANOPIA:
            tmp = blue / red;
            /* See which side of the inflection line we fall... */
            if (tmp < inflection)
              green = -(a1 * red + c1 * blue) / b1;
            else
              green = -(a2 * red + c2 * blue) / b2;
            break;

          case PROTANOPIA:
            tmp = blue / green;
            /* See which side of the inflection line we fall... */
            if (tmp < inflection)
              red = -(b1 * green + c1 * blue) / a1;
            else
              red = -(b2 * green + c2 * blue) / a2;
            break;

          case TRITANOPIA:
            tmp = green / red;
            /* See which side of the inflection line we fall... */
            if (tmp < inflection)
              blue = -(a1 * red + b1 * green) / c1;
            else
              blue = -(a2 * red + b2 * green) / c2;
            break;

          default:
            break;
          }

        /* Convert back to RGB (cross product with transform matrix) */
        redOld   = red;
        greenOld = green;

        red   = redOld * lms2rgb[0] + greenOld * lms2rgb[1] + blue * lms2rgb[2];
        green = redOld * lms2rgb[3] + greenOld * lms2rgb[4] + blue * lms2rgb[5];
        blue  = redOld * lms2rgb[6] + greenOld * lms2rgb[7] + blue * lms2rgb[8];

        /* Apply gamma to go back to non-linear intensities */
        red   = pow (red,   gammaRGB[0]);
        green = pow (green, gammaRGB[1]);
        blue  = pow (blue,  gammaRGB[2]);

	p = SETRGB(CLIP(red*Z), CLIP(green*Z), CLIP(blue*Z));
	return p;
}

static void
init_deficiency(void) {
  double              anchor_e[3];
  double              anchor[12];

  /*  This function performs initialisations that are dependant
   *  on the type of color deficiency.
   */

  /* Performs protan, deutan or tritan color image simulation based on
   * Brettel, Vienot and Mollon JOSA 14/10 1997
   *  L,M,S for lambda=475,485,575,660
   *
   * Load the LMS anchor-point values for lambda = 475 & 485 nm (for
   * protans & deutans) and the LMS values for lambda = 575 & 660 nm
   * (for tritans)
   */
  anchor[0] = 0.08008;  anchor[1]  = 0.1579;    anchor[2]  = 0.5897;
  anchor[3] = 0.1284;   anchor[4]  = 0.2237;    anchor[5]  = 0.3636;
  anchor[6] = 0.9856;   anchor[7]  = 0.7325;    anchor[8]  = 0.001079;
  anchor[9] = 0.0914;   anchor[10] = 0.007009;  anchor[11] = 0.0;

  /* We also need LMS for RGB=(1,1,1)- the equal-energy point (one of
   * our anchors) (we can just peel this out of the rgb2lms transform
   * matrix)
   */
  anchor_e[0] =
    rgb2lms[0] + rgb2lms[1] + rgb2lms[2];
  anchor_e[1] =
    rgb2lms[3] + rgb2lms[4] + rgb2lms[5];
  anchor_e[2] =
    rgb2lms[6] + rgb2lms[7] + rgb2lms[8];

  switch (deficiency)
    {
    case DEUTERANOPIA:
      /* find a,b,c for lam=575nm and lam=475 */
      a1 = anchor_e[1] * anchor[8] - anchor_e[2] * anchor[7];
      b1 = anchor_e[2] * anchor[6] - anchor_e[0] * anchor[8];
      c1 = anchor_e[0] * anchor[7] - anchor_e[1] * anchor[6];
      a2 = anchor_e[1] * anchor[2] - anchor_e[2] * anchor[1];
      b2 = anchor_e[2] * anchor[0] - anchor_e[0] * anchor[2];
      c2 = anchor_e[0] * anchor[1] - anchor_e[1] * anchor[0];
      inflection = (anchor_e[2] / anchor_e[0]);
      break;

    case PROTANOPIA:
      /* find a,b,c for lam=575nm and lam=475 */
      a1 = anchor_e[1] * anchor[8] - anchor_e[2] * anchor[7];
      b1 = anchor_e[2] * anchor[6] - anchor_e[0] * anchor[8];
      c1 = anchor_e[0] * anchor[7] - anchor_e[1] * anchor[6];
      a2 = anchor_e[1] * anchor[2] - anchor_e[2] * anchor[1];
      b2 = anchor_e[2] * anchor[0] - anchor_e[0] * anchor[2];
      c2 = anchor_e[0] * anchor[1] - anchor_e[1] * anchor[0];
      inflection = (anchor_e[2] / anchor_e[1]);
      break;

    case TRITANOPIA:
      /* Set 1: regions where lambda_a=575, set 2: lambda_a=475 */
      a1 = anchor_e[1] * anchor[11] - anchor_e[2] * anchor[10];
      b1 = anchor_e[2] * anchor[9]  - anchor_e[0] * anchor[11];
      c1 = anchor_e[0] * anchor[10] - anchor_e[1] * anchor[9];
      a2 = anchor_e[1] * anchor[5]  - anchor_e[2] * anchor[4];
      b2 = anchor_e[2] * anchor[3]  - anchor_e[0] * anchor[5];
      c2 = anchor_e[0] * anchor[4]  - anchor_e[1] * anchor[3];
      inflection = (anchor_e[1] / anchor_e[0]);
      break;

    default:
	fprintf(stderr, "init_deficiency: unknown deficiency: %d\n", deficiency);
	exit(13);
    }
}

void
init_colorblind(ColorblindDeficiency def) {
	deficiency = def;
	colorblind_init();
	init_deficiency();
}
#endif

