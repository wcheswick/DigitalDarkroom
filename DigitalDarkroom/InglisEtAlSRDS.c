//
//  InglisEtAlSRDS.c
//  DigitalDarkroom
//
//  Created by William Cheswick on 9/25/20.
//  Copyright © 2022 Cheswick.com. All rights reserved.
//

#include "ThimblebySRDS.h"
/* Algorithm for drawing an autostereogram */

// From
// @ARTICLE{Inglis94displaying3d,
//     author = {Stuart Inglis and Harold W. Thimbleby and Harold W. Thimbleby and Ian Witten and Ian H. Witten},
//     title = {Displaying 3D Images: Algorithms for Single Image Random Dot Stereograms},
//     journal = {IEEE Computer},
//     year = {1994},
//     volume = {27},
//     pages = {38--48}
// }

#define round(X) (int)((X)+0.5) /* Often need to round rather than truncate */
#define DPI 72 /* Output device has 72 pixels per inch */
#define E round(2.5*DPI) /* Eye separation is assumed to be 2.5 inches */
#define mu (1/3.0) /* Depth of field (fraction of viewing distance) */
#define separation(Z) round((1-mu*Z)*E/(2-mu*Z))
/* Stereo separation corresponding to position Z */
#define far separation(0) /* ... and corresponding to far plane, Z=0 */
#define maxX 256 /* Image and object are both maxX by maxY pixels */
#define maxY 256

#ifdef notyet
void DrawAutoStereogram(float Z[][])
{ /* Object’s depth is Z[x][y] (between 0 and 1) */
    int x, y; /* Coordinates of the current point */
    for( y = 0; y < maxY; y++ ) /* Convert each scan line independently */
    { int pix[maxX]; /* Color of this pixel */
        int same[maxX]; /* Points to a pixel to the right ... */
        /*... that is constrained to be this color */
        int s; /* Stereo separation at this (x,y) point */
        int left, right; /* X-values corresponding to left and right eyes */
        
        for( x = 0; x < maxX; x++ )
        same[x] = x; /* Each pixel is initially linked with itself */
        
        for( x = 0; x < maxX; x++ )
        { s = separation(Z[x][y]);
            left = x - (s+(s&y&1))/2; /* Pixels at left and right ... */
            right = left + s; /* ... must be the same ... */
            if( 0 <= left && right < maxX ) /* ... or must they? */
            { int visible; /* First, perform hidden-surface removal */
                int t = 1; /* We will check the points (x-t,y) and (x+t,y) */
                float zt; /* Z-coord of ray at these two points */
                
                do
                { zt = Z[x][y] + 2*(2 - mu*Z[x][y])*t/(mu*E);
                    visible = Z[x-t][y]<zt && Z[x+t][y]<zt; /* False if obscured */
                    t++;
                } while( visible && zt < 1 ); /* Done hidden-surface removal ... */
                if( visible ) /* ... so record the fact that pixels at */
                { int k; /* ... left and right are the same */
                    for( k = same[left]; k != left && k != right; k = same[left] )
                    if( k < right ) /* But first, juggle the pointers ... */
                        left = k; /* ... until either same[left]=left */
                    else /* ... or same[right]=left */
                    { left = right;
                        right = k;
                    }
                    same[left] = right; /* This is where we actually record it */
                }
            }
        }
        for( x = maxX-1; x >= 0; x-- ) /* Now set the pixels on this scan line */
        { if( same[x] == x ) pix[x] = random()&1; /* Free choice; do it randomly */
        else pix[x] = pix[same[x]]; /* Constrained choice; obey constraint */
            Set_Pixel(x, y, pix[x]);
        }
    }
    DrawCircle(maxX/2-far/2, maxY*19/20); /* Draw convergence dots at far plane,*/
    DrawCircle(maxX/2+far/2, maxY*19/20); /* near the bottom of the screen */
}
#endif

