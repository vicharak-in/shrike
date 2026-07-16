#!/usr/bin/env python3
# Generate a HUB75 test image (hex, one {R,G,B} word per pixel) for any
# geometry / colour depth. Same border+diagonal pattern used by the 8x8
# default, plus a couple of mid-brightness probes to exercise BCM.
#
#   python gen_image.py COLS ROWS BPP OUTFILE
#   e.g.  python gen_image.py 16 16 4 image_16x16.hex
import sys

def main():
    if len(sys.argv) != 5:
        print("usage: gen_image.py COLS ROWS BPP OUTFILE", file=sys.stderr)
        sys.exit(1)
    cols, rows, bpp, out = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    maxv = (1 << bpp) - 1
    mid = maxv // 2 + 1 # a mid-scale value
    nib = (3 * bpp + 3) // 4 # hex digits per pixel word

    def word(r, g, b):
        return (r << (2 * bpp)) | (g << bpp) | b

    lines = [f"// {cols}x{rows} RGB test image, BPP={bpp}. Word = {{R,G,B}}, "
             f"addr = row*{cols}+col.\n"]
    for r in range(rows):
        toks = []
        for c in range(cols):
            if r == 0 or r == rows - 1 or c == 0 or c == cols - 1:
                v = word(maxv, 0, 0) # red border
            elif c == r:
                v = word(0, maxv, 0) # green main diagonal
            elif c == cols - 1 - r:
                v = word(0, 0, maxv) # blue anti-diagonal
            elif (r, c) == (2, 3):
                v = word(mid, mid, 0) # mid yellow (BCM probe)
            elif (r, c) == (rows - 2, cols - 2):
                v = word(0, mid, mid) # mid cyan  (BCM probe)
            else:
                v = word(0, 0, 0) # off
            toks.append(f"{v:0{nib}x}")
        lines.append(" ".join(toks) + f"   // row {r}\n")

    with open(out, "w") as f:
        f.writelines(lines)
    print(f"wrote {out}: {cols}x{rows}, BPP={bpp}, {nib} hex digit(s)/pixel")

if __name__ == "__main__":
    main()
