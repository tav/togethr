#! /usr/bin/env python

# Public Domain (-) 2011 The Ampify Authors.
# See the Ampify UNLICENSE file for details.

"""Generate the togethr.at logo."""

import sys

from optparse import OptionParser

from Image import new
from ImageDraw import Draw

# ------------------------------------------------------------------------------
# Logo Spec
# ------------------------------------------------------------------------------

logo = (
    (0, 1, 0, 0, 1, 1, 1, 1, 0),
    (1, 0, 0, 1, 0, 1, 0, 1, 1),
    (0, 1, 0, 1, 1, 0, 0, 1, 1),
    (1, 0, 1, 1, 0, 0, 0, 0, 0),
    (0, 1, 1, 0, 0, 0, 0, 0, 0),
    (1, 1, 1, 1, 1, 0, 0, 1, 1),
    (0, 0, 0, 1, 1, 0, 0, 1, 1),
    (0, 1, 0, 1, 1, 0, 0, 0, 0),
    (0, 0, 0, 1, 1, 0, 0, 0, 0),
    )

color = "#3b75d1"

# ------------------------------------------------------------------------------
# Parse Command Line Flags
# ------------------------------------------------------------------------------

op = OptionParser(usage="Usage: %prog [options] <logo.png>")

op.add_option(
    '--bg', default='white', help="background color [default: white]"
    )

op.add_option(
    '--border', default='',
    help="specify an optional border color [default: black]"
    )

op.add_option(
    '--color', default=color, help="foreground color [default: %s]" % color
    )

op.add_option(
    '--invert', action='store_true',
    help="invert background/color [default: False]"
    )

op.add_option(
    '--padding', default=0, type=int, help="pixels of padding [default: 0]"
    )

op.add_option(
    '--scale', default=1, type=int,
    help="scale multiple of 9 pixels [default: 1]"
    )

options, args = op.parse_args(sys.argv[1:])
if args:
    filename = args[0]
else:
    filename = 'logo.png'

background = options.bg
border = options.border
color = options.color
invert = options.invert
scale = options.scale

if border:
    outline = 1
else:
    outline = 0

if scale <= 0:
    print "!! Scale must be a positive number !!"
    sys.exit(1)

padding = options.padding + outline
size = (scale * len(logo)) + (2 * padding)

if invert:
    background, color = color, background
    logo = [[not i for i in row] for row in logo]

# ------------------------------------------------------------------------------
# Render
# ------------------------------------------------------------------------------

im = new('RGB', (size, size), background)
draw = Draw(im)

if invert:
    pass

if border:
    start = padding - 1
    end = size - padding
    draw.rectangle([(start, start), (end, end)], outline=border)

for y, row in enumerate(logo):
    for x, pixel in enumerate(row):
        if pixel:
            xfactor = (x * scale) + padding
            yfactor = (y * scale) + padding
            for px in range(xfactor, xfactor+scale):
                for py in range(yfactor, yfactor+scale):
                    draw.point((px, py), fill=color)

im.save(filename, 'PNG')
