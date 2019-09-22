typedef enum {
  PROTANOPIA,
  DEUTERANOPIA,
  TRITANOPIA
} ColorblindDeficiency;

extern	Pixel to_colorblind(int r, int g, int b);
extern	void init_colorblind(ColorblindDeficiency);
