#!/usr/bin/env python3
"""Render the OneClick app icon from its SVG and write every artifact that uses it.

The artwork lives in ``assets/icon.svg``, which is the source of truth: it is
declarative, so it can be read, edited and previewed in any browser. It is shared
-- the README shows it, and this script rasterizes it into the app's icon ladder
-- so it sits beside the repository rather than inside the asset catalog, where
only the compiler would see it. The PNG rungs in ``AppIcon.appiconset`` are what
the asset catalog compiles; ``assets/icon.png`` is the copy the README embeds.

This is the only icon script. It used to be split across a shell wrapper that
assembled a standalone ``.icns`` with ``iconutil``, but nothing consumed that
file: the app's icon is ``Contents/Resources/AppIcon.icns``, which actool builds
from the PNG ladder below because the target sets
``ASSETCATALOG_COMPILER_APPICON_NAME``. The wrapper's one durable contribution
was verifying all ten rungs survived conversion, and that check now lives here
behind ``--icns``, so it is still available without keeping a whole entry point
whose product nothing reads.

The SVG is rasterized here rather than through a drawing library, because the
icon only needs a handful of constructs and numpy is already a build dependency.
What is implemented is exactly what the file uses:

* ``<rect>`` with ``rx``                     -- the rounded plate
* ``<path>`` with ``M L H A Z``              -- the rings, the bars, the pointer
* ``<g transform="translate(x y)">``         -- the mark's optical offset
* ``fill`` with a colour or a vertical multi-stop linear gradient
* ``stroke`` with a width and round caps/joins -- the arcs and bars are stroked

Anything else raises, so the icon can never silently render wrong.

Fills use the even-odd rule at 3x supersampling and strokes are measured as the
distance from the centreline (which is what a round cap and a round join mean);
the box filter down is what gives the small rungs clean edges. Both kernels walk
one edge or segment at a time: batching them was tried and is slower, for the
reason `fill_rings` documents.
"""
import argparse
import json
import math
import re
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ElementTree
import zlib
from pathlib import Path
from typing import Callable

import numpy

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "src" / "app" / "resources"
ICONSET = RESOURCES / "Assets.xcassets" / "AppIcon.appiconset"
CONTENTS_PATH = ICONSET / "Contents.json"
# The artwork, shared with the README, and the copy the README embeds.
ARTWORK_PATH = ROOT / "assets" / "icon.svg"
PREVIEW_PATH = ROOT / "assets" / "icon.png"
PREVIEW_PIXELS = 512
DEFAULT_ICNS_PATH = ROOT / ".build" / "OneClick.icns"

ICONUTIL = "/usr/bin/iconutil"
SUPERSAMPLE = 3
# The artwork's own coordinate space: the viewBox `load_svg` insists on.
SOURCE_SIZE = 1024
ARC_STEP = 1.5        # pixels between arc samples
# Slots in a macOS AppIcon catalog: filename stem -> pixel count.
SLOTS = {
    "icon_16x16": 16, "icon_16x16@2x": 32,
    "icon_32x32": 32, "icon_32x32@2x": 64,
    "icon_128x128": 128, "icon_128x128@2x": 256,
    "icon_256x256": 256, "icon_256x256@2x": 512,
    "icon_512x512": 512, "icon_512x512@2x": 1024,
}

NS = "{http://www.w3.org/2000/svg}"
_TOKEN = re.compile(r"([MLHVAZmlhvaz])|(-?\d*\.?\d+(?:e-?\d+)?)")

# Xcode writes Contents.json with a two-space indent, one entry per line, and a
# trailing newline after every closing brace. Reproduced exactly so regenerating
# it is a no-op in git rather than a whitespace-only diff.
CONTENTS_INDENT = "  "
FIELD_INDENT = CONTENTS_INDENT * 2


def contents_json() -> str:
    """The ``Contents.json`` describing `SLOTS`, in Xcode's own layout.

    Generated here rather than left as a hand-maintained file: a rung added to
    `SLOTS` but not referenced here would be written as a PNG and then ignored by
    actool, which looks exactly like a rendering bug.

    The literal layout matters. Xcode indents these entries by two spaces and
    their closing braces by one, which no generic JSON dumper produces; getting it
    wrong is a whitespace-only diff every time the file is regenerated.
    """
    entries = []
    for name in SLOTS:
        stem, _, scale = name.partition("@")
        points = int(stem.split("x")[-1])
        entries.append("\n".join([
            f'{CONTENTS_INDENT}{{',
            f'{FIELD_INDENT}"filename" : "{name}.png",',
            f'{FIELD_INDENT}"idiom" : "mac",',
            f'{FIELD_INDENT}"scale" : "{scale or "1x"}",',
            f'{FIELD_INDENT}"size" : "{points}x{points}"',
            f'{CONTENTS_INDENT}}}',
        ]))
    return "\n".join([
        "{",
        f'{CONTENTS_INDENT}"images" : [',
        ",\n".join(entries),
        f'{CONTENTS_INDENT}],',
        f'{CONTENTS_INDENT}"info" : {{',
        f'{FIELD_INDENT}"author" : "xcode",',
        f'{FIELD_INDENT}"version" : 1',
        f'{CONTENTS_INDENT}}}',
        "}",
        "",
    ])


# --------------------------------------------------------------- path parsing

def parse_path(data: str):
    """Path data -> [(command, [numbers])], with relative and H/V expanded."""
    tokens = []
    for command, number in _TOKEN.findall(data):
        tokens.append(command if command else float(number))
    raw = []
    for token in tokens:
        if isinstance(token, str):
            raw.append([token, []])
        else:
            if not raw:
                raise ValueError("path data must start with a command")
            raw[-1][1].append(token)

    commands = []
    current = numpy.zeros(2)
    start = numpy.zeros(2)
    for command, values in raw:
        relative = command.islower()
        kind = command.upper()
        if kind == "M":
            for index in range(0, len(values), 2):
                point = numpy.array(values[index:index + 2], dtype=float)
                current = current + point if relative else point
                commands.append(("M" if index == 0 else "L", current.copy()))
                if index == 0:
                    start = current.copy()
        elif kind == "L":
            for index in range(0, len(values), 2):
                point = numpy.array(values[index:index + 2], dtype=float)
                current = current + point if relative else point
                commands.append(("L", current.copy()))
        elif kind == "H":
            for value in values:
                current = current + numpy.array([value, 0.0]) if relative else numpy.array([value, current[1]])
                commands.append(("L", current.copy()))
        elif kind == "V":
            for value in values:
                current = current + numpy.array([0.0, value]) if relative else numpy.array([current[0], value])
                commands.append(("L", current.copy()))
        elif kind == "A":
            for index in range(0, len(values), 7):
                rx, ry, rotation, large, sweep = values[index:index + 5]
                point = numpy.array(values[index + 5:index + 7], dtype=float)
                end = current + point if relative else point
                commands.append(("A", (rx, ry, rotation, int(large), int(sweep), end)))
                current = end
        elif kind == "Z":
            commands.append(("Z", start.copy()))
            current = start.copy()
        else:
            raise ValueError(f"unsupported path command {command!r}")
    return commands


def arc_points(start, rx, ry, rotation, large_arc, sweep, end, step=ARC_STEP):
    """Sample an SVG elliptical arc.

    This is the specification's endpoint-to-centre conversion, including the
    radius correction for arcs too small to span their endpoints, so the raster
    is the same curve a viewer draws.
    """
    x1, y1 = start
    x2, y2 = end
    if rx == 0 or ry == 0:
        return [numpy.array(end, dtype=float)]
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(rotation)
    cos_phi, sin_phi = math.cos(phi), math.sin(phi)

    dx2, dy2 = (x1 - x2) / 2.0, (y1 - y2) / 2.0
    x1p = cos_phi * dx2 + sin_phi * dy2
    y1p = -sin_phi * dx2 + cos_phi * dy2

    lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if lam > 1:
        rx *= math.sqrt(lam)
        ry *= math.sqrt(lam)

    numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    factor = math.sqrt(max(0.0, numerator / denominator))
    if large_arc == sweep:
        factor = -factor
    cxp = factor * rx * y1p / ry
    cyp = -factor * ry * x1p / rx
    cx = cos_phi * cxp - sin_phi * cyp + (x1 + x2) / 2.0
    cy = sin_phi * cxp + cos_phi * cyp + (y1 + y2) / 2.0

    def angle(ux, uy, vx, vy):
        length = math.hypot(ux, uy) * math.hypot(vx, vy)
        value = max(-1.0, min(1.0, (ux * vx + uy * vy) / length if length else 1.0))
        sign = -1.0 if (ux * vy - uy * vx) < 0 else 1.0
        return sign * math.acos(value)

    theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and delta > 0:
        delta -= 2 * math.pi
    elif sweep and delta < 0:
        delta += 2 * math.pi

    steps = max(4, int(abs(delta) / (2 * math.pi) * 2 * math.pi * max(rx, ry) / step))
    points = []
    for index in range(1, steps + 1):
        theta = theta1 + delta * index / steps
        points.append(numpy.array([
            cos_phi * rx * math.cos(theta) - sin_phi * ry * math.sin(theta) + cx,
            sin_phi * rx * math.cos(theta) + cos_phi * ry * math.sin(theta) + cy]))
    points[-1] = numpy.array(end, dtype=float)
    return points


def path_polylines(data: str):
    """Path data -> list of polylines, one per subpath, plus a closed flag."""
    polylines = []
    points = []
    for command, value in parse_path(data):
        if command == "M":
            if len(points) > 1:
                polylines.append((numpy.array(points), False))
            points = [value]
        elif command in ("L", "A"):
            if command == "L":
                points.append(value)
            else:
                rx, ry, rotation, large, sweep, end = value
                points.extend(arc_points(points[-1], rx, ry, rotation, large, sweep, end))
        elif command == "Z":
            if len(points) > 1:
                polylines.append((numpy.array(points), True))
            points = []
    if len(points) > 1:
        polylines.append((numpy.array(points), False))
    return polylines


# ------------------------------------------------------------- stroking

def _bounds(rings):
    """User-space bounding box of a set of rings, as (top, bottom)."""
    ys = [point[1] for ring in rings for point in ring]
    return float(min(ys)), float(max(ys))


# A miter and a round join differ by a fraction of the stroke width until the
# centreline turns sharply; this is where that stops being true.
SHARP_TURN_DEGREES = 15.0


def _sharpest_turn(polyline):
    """The largest direction change along a polyline, in degrees."""
    points = numpy.asarray(polyline, dtype=float)
    if len(points) < 3:
        return 0.0
    directions = points[1:] - points[:-1]
    lengths = numpy.hypot(directions[:, 0], directions[:, 1])
    keep = lengths > 1e-9
    directions = directions[keep] / lengths[keep][:, None]
    if len(directions) < 2:
        return 0.0
    dots = numpy.clip(numpy.sum(directions[1:] * directions[:-1], axis=1), -1.0, 1.0)
    return float(numpy.degrees(numpy.arccos(dots)).max())


def _floats(text):
    return [float(value) for value in re.findall(r"-?\d*\.?\d+(?:e-?\d+)?", text or "")]


def _colour(value):
    value = (value or "").strip()
    if value.startswith("#"):
        value = value[1:]
        if len(value) == 3:
            value = "".join(character * 2 for character in value)
        return numpy.array([int(value[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)
    raise ValueError(f"unsupported colour {value!r}")


def _rounded_rect_path(x, y, width, height, radius):
    """A rounded rectangle as path data, so it is sampled by the arc code.

    Emitted as four arcs rather than generated point by point: the arc sampler
    is already the one path data uses, so the plate and the artwork's own arcs
    cannot disagree about where a curve runs.
    """
    radius = min(radius, width / 2, height / 2)
    return (f"M {x + radius} {y} H {x + width - radius} "
            f"A {radius} {radius} 0 0 1 {x + width} {y + radius} "
            f"V {y + height - radius} "
            f"A {radius} {radius} 0 0 1 {x + width - radius} {y + height} "
            f"H {x + radius} "
            f"A {radius} {radius} 0 0 1 {x} {y + height - radius} "
            f"V {y + radius} "
            f"A {radius} {radius} 0 0 1 {x + radius} {y} Z")


def load_svg(path: Path):
    """The SVG as a list of paint primitives, in draw order.

    A paint is either a colour or a gradient: ("gradient", [(offset, colour,
    opacity), ...]) evaluated along y over the element's own bounding box, which
    is what a vertical ``objectBoundingBox`` gradient means.
    """
    root = ElementTree.parse(path).getroot()
    if root.get("viewBox") not in (None, "0 0 1024 1024"):
        raise ValueError(f"unexpected viewBox {root.get('viewBox')!r}")

    gradients = {}
    for element in root.iter(f"{NS}linearGradient"):
        axis = [element.get(name, default) for name, default in
                (("x1", "0"), ("y1", "0"), ("x2", "1"), ("y2", "0"))]
        if axis != ["0", "0", "0", "1"]:
            raise ValueError(f"only top-to-bottom gradients are supported, got {axis}")
        stops = []
        for stop in element.iter(f"{NS}stop"):
            stops.append((float(stop.get("offset", "0")),
                          _colour(stop.get("stop-color")),
                          float(stop.get("stop-opacity", "1"))))
        if len(stops) < 2:
            raise ValueError("a gradient needs at least two stops")
        gradients[element.get("id")] = ("gradient", sorted(stops))

    primitives = []

    def paint_of(element, parent_paint):
        fill = element.get("fill", parent_paint.get("fill", "none"))
        if fill.startswith("url("):
            key = fill[fill.index("#") + 1:fill.index(")")]
            if key not in gradients:
                raise ValueError(f"unknown gradient {key!r}")
            return gradients[key]
        if fill == "none":
            return None
        return _colour(fill)

    def walk(element, parent_paint, offset):
        paint = dict(parent_paint)
        for name in ("fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin"):
            if element.get(name) is not None:
                paint[name] = element.get(name)
        transform = element.get("transform")
        if transform:
            match = re.fullmatch(r"translate\(\s*(-?[\d.]+)[ ,]+(-?[\d.]+)\s*\)", transform.strip())
            if not match:
                raise ValueError(f"unsupported transform {transform!r}")
            offset = offset + numpy.array([float(match.group(1)), float(match.group(2))])

        tag = element.tag.split("}")[-1]
        if tag == "path":
            stroke = paint.get("stroke", "none")
            colour = paint_of(element, paint)
            caps = []
            if colour is not None:
                for polyline, closed in path_polylines(element.get("d")):
                    points = polyline + offset
                    if closed:
                        points = numpy.vstack([points, points[:1]])
                    caps.append(points)
            if stroke != "none":
                width = float(paint.get("stroke-width", 1.0))
                # Strokes are measured as a distance from the centreline, which
                # *is* a round cap and a round join. A butt cap would render
                # differently, and so would a miter join -- but a join only
                # matters where the centreline turns, so a straight stroke is
                # fine whatever the join says (SVG's default is miter).
                if paint.get("stroke-linecap", "butt") != "round":
                    raise ValueError("only round line caps are supported")
                join = paint.get("stroke-linejoin", "miter")
                for polyline, _ in path_polylines(element.get("d")):
                    if join != "round" and _sharpest_turn(polyline) > SHARP_TURN_DEGREES:
                        raise ValueError("only round line joins are supported")
                    primitives.append(dict(kind="stroke", colour=_colour(stroke),
                                           width=width, centreline=polyline + offset,
                                           box=_bounds([polyline + offset])))
            if colour is not None and caps:
                primitives.append(dict(kind="fill", colour=colour, rings=caps,
                                       box=_bounds(caps)))
        elif tag == "rect":
            if element.get("stroke") is not None:
                raise ValueError("stroked rects are not supported")
            x, y = _floats(element.get("x", "0"))[0], _floats(element.get("y", "0"))[0]
            width, height = _floats(element.get("width"))[0], _floats(element.get("height"))[0]
            radius = _floats(element.get("rx", "0"))[0]
            colour = paint_of(element, paint)
            if colour is not None:
                rings = [numpy.asarray(polyline) + offset
                         for polyline, _ in path_polylines(_rounded_rect_path(x, y, width, height, radius))]
                primitives.append(dict(kind="fill", colour=colour, rings=rings,
                                       box=_bounds(rings)))
        elif tag in ("g", "svg", "defs"):
            if tag == "defs":
                return
            for child in element:
                walk(child, paint, offset)
        elif tag in ("linearGradient", "stop"):
            return
        else:
            raise ValueError(f"unsupported element <{tag}>")

    walk(root, {}, numpy.zeros(2))
    return primitives


# --------------------------------------------------------------- rasterizing

def _sample_grid(lo, hi, size, sp):
    """Pixel-centre sample coordinates covering [lo, hi], plus the pixel range."""
    start = max(0, int(numpy.floor(lo)) - 1)
    stop = min(size, int(numpy.ceil(hi)) + 2)
    start = min(start, max(0, stop - 1))
    return start, stop, start + (numpy.arange((stop - start) * sp) + 0.5) / sp


def fill_rings(rings, size: int, scale: float, samples_per_pixel: int) -> numpy.ndarray:
    """Even-odd coverage in [0, 1] for filled rings, as a size x size array.

    Even-odd is what the artwork's filled paths mean (the pointer has a notch,
    which is a concavity rather than a hole, so either rule agrees there), and
    the rings it is given never self-overlap.

    The edge loop is deliberately one edge at a time. Batching it into a numpy
    reduction over `(edges, rows, columns)` looks like the obvious win and is
    measurably a loss: the plate's ring has 797 vertices, so a batch allocates a
    dense array of every edge against every sample, and the memory traffic for
    that costs more than the Python it removes -- 6.0s against 3.6s for the same
    ring at 1024. The per-edge form touches one `(rows, columns)` array per edge
    instead, which stays in cache.
    """
    coverage = numpy.zeros((size, size), dtype=float)
    # A ring needs at least three points to enclose anything. Skipping the rest
    # is not just an optimization: a two-point ring collapses the sample window.
    scaled = [numpy.asarray(ring, dtype=float) * scale for ring in rings if len(ring) > 2]
    if not scaled:
        return coverage
    xs = [point[0] for ring in scaled for point in ring]
    ys = [point[1] for ring in scaled for point in ring]
    sp = samples_per_pixel
    x0, x1, px_row = _sample_grid(min(xs), max(xs), size, sp)
    y0, y1, py_col = _sample_grid(min(ys), max(ys), size, sp)
    if x1 <= x0 or y1 <= y0:
        return coverage
    px = px_row[None, :]
    py = py_col[:, None]

    inside = numpy.zeros(((y1 - y0) * sp, (x1 - x0) * sp), dtype=bool)
    for ring in scaled:
        count = len(ring)
        for index in range(count):
            ax, ay = ring[index]
            bx, by = ring[(index + 1) % count]
            if ay == by:
                continue
            # Half-open vertical test keeps shared vertices from counting twice.
            straddles = (ay > py) != (by > py)
            x_at_y = ax + (py - ay) * (bx - ax) / (by - ay)
            inside ^= straddles & (px < x_at_y)

    fine = inside.reshape(y1 - y0, sp, x1 - x0, sp)
    coverage[y0:y1, x0:x1] = fine.mean(axis=(1, 3))
    return coverage


def stroke_coverage(centreline, width, size: int, scale: float, samples_per_pixel: int):
    """Coverage of a stroked polyline, as the band within half the width of it.

    Measured as a distance rather than built as an outline: a stroked shape's
    outline crosses itself at inner corners, and then no fill rule recovers the
    band. Distance does not care about winding, and round caps and joins are
    simply what "within half the width of the centreline" already means.

    Like `fill_rings`, this stays one segment at a time: batching segments into a
    `(segments, rows, columns)` reduction was tried and is slower here, for the
    same reason.
    """
    coverage = numpy.zeros((size, size), dtype=float)
    points = numpy.asarray(centreline, dtype=float) * scale
    keep = numpy.ones(len(points), bool)
    keep[1:] = numpy.hypot(*(points[1:] - points[:-1]).T) > 1e-9
    points = points[keep]
    if len(points) < 2:
        return coverage
    half = width * scale / 2.0
    sp = samples_per_pixel
    x0, x1, px_row = _sample_grid(float(points[:, 0].min()) - half,
                                  float(points[:, 0].max()) + half, size, sp)
    y0, y1, py_col = _sample_grid(float(points[:, 1].min()) - half,
                                  float(points[:, 1].max()) + half, size, sp)
    if x1 <= x0 or y1 <= y0:
        return coverage
    px = px_row[None, :]
    py = py_col[:, None]

    # Distance to the polyline: the nearest point on any segment, accumulated
    # with an in-place element-wise minimum. There is no pruning of the segment
    # set -- every segment is measured against every sample in the window.
    distance = numpy.full(((y1 - y0) * sp, (x1 - x0) * sp), numpy.inf)
    for index in range(len(points) - 1):
        ax, ay = points[index]
        bx, by = points[index + 1]
        dx, dy = bx - ax, by - ay
        length_squared = dx * dx + dy * dy
        if length_squared == 0:
            continue
        # how far along the segment each sample projects, clamped to the segment
        t = ((px - ax) * dx + (py - ay) * dy) / length_squared
        numpy.clip(t, 0.0, 1.0, out=t)
        numpy.minimum(distance, numpy.hypot(px - (ax + t * dx), py - (ay + t * dy)),
                      out=distance)

    fine = (distance <= half).reshape(y1 - y0, sp, x1 - x0, sp)
    coverage[y0:y1, x0:x1] = fine.mean(axis=(1, 3))
    return coverage


def render(primitives, size: int) -> numpy.ndarray:
    """RGBA float image of the icon at `size` x `size`, values in [0, 1].

    Elements are composited source-over in premultiplied form, so a translucent
    paint -- the plate's sheen, which is white at 30% fading to nothing -- washes
    over what is underneath instead of thinning the icon's own alpha.
    """
    scale = size / SOURCE_SIZE
    # y in user units, for evaluating vertical gradients
    rows = (numpy.arange(size) + 0.5) / scale

    premultiplied = numpy.zeros((size, size, 3), dtype=float)
    alpha = numpy.zeros((size, size), dtype=float)
    for element in primitives:
        if element["kind"] == "fill":
            coverage = fill_rings(element["rings"], size, scale, SUPERSAMPLE)
        else:
            coverage = stroke_coverage(element["centreline"], element["width"],
                                       size, scale, SUPERSAMPLE)
        paint = element["colour"]
        if isinstance(paint, tuple):
            _, stops = paint
            top, bottom = element["box"]
            ramp = numpy.clip((rows - top) / max(bottom - top, 1e-6), 0.0, 1.0)
            offsets = numpy.array([stop[0] for stop in stops])
            colour = numpy.stack([numpy.interp(ramp, offsets,
                                               [stop[1][channel] for stop in stops])
                                  for channel in range(3)], axis=-1)
            opacity = numpy.interp(ramp, offsets, [stop[2] for stop in stops])
        else:
            colour = numpy.broadcast_to(paint, (size, 3)).copy()
            opacity = numpy.ones(size)

        source_alpha = coverage * opacity[:, None]
        premultiplied = (premultiplied * (1 - source_alpha[..., None])
                         + colour[:, None, :] * source_alpha[..., None])
        alpha = alpha * (1 - source_alpha) + source_alpha

    # the paints carry 0-255 colours, the API hands back [0, 1]
    opaque = numpy.maximum(alpha, 1e-6)
    return numpy.concatenate([premultiplied / opaque[..., None] / 255.0,
                              alpha[..., None]], axis=-1)


def encode_png(rgba: numpy.ndarray) -> bytes:
    """The PNG byte stream for an RGBA float image.

    Written by hand rather than through an imaging library: the encoding needed
    here is one IHDR, one IDAT of filtered scanlines and one IEND, which is less
    code than taking on a dependency for it. Returning bytes rather than writing
    a file is what lets `--check` compare an image it just rendered against the
    committed one without touching the tree.
    """
    height, width = rgba.shape[:2]
    data = numpy.clip(rgba * 255.0 + 0.5, 0, 255).astype(numpy.uint8)

    # Every scanline is prefixed with filter type 0 (None) and nothing else; the
    # whole filtered image is one array so the encoder never loops in Python.
    raw = numpy.hstack([numpy.zeros((height, 1), dtype=numpy.uint8),
                        data.reshape(height, width * 4)]).tobytes()

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))


def write_icns(image: Callable[[int], numpy.ndarray], destination: Path) -> None:
    """Assemble a standalone `.icns` from the rendered ladder, then verify it.

    `iconutil` is used rather than writing the container here: CGImageDestination
    silently encodes only a few of the images it is handed, which produces an
    icon that looks right until a large view asks for the 512 or 1024 rung. The
    round trip below re-reads every slot, so a truncated `.icns` fails here
    instead of in the Dock.

    Nothing in the build consumes this file -- actool makes the app's
    `Contents/Resources/AppIcon.icns` from the PNG ladder -- so it is written only
    when `--icns` asks for it, and is worth having exactly when someone wants a
    standalone icon to look at or drag somewhere.
    """
    names = [f"{name}.png" for name in SLOTS]
    with tempfile.TemporaryDirectory() as workspace:
        iconset = Path(workspace) / "AppIcon.iconset"
        iconset.mkdir()
        for name, pixels in SLOTS.items():
            (iconset / f"{name}.png").write_bytes(encode_png(image(pixels)))

        destination.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([ICONUTIL, "-c", "icns", str(iconset), "-o", str(destination)], check=True)

        verify = Path(workspace) / "Verify.iconset"
        subprocess.run([ICONUTIL, "-c", "iconset", str(destination), "-o", str(verify)], check=True)
        missing = [name for name in names if not (verify / name).is_file()
                   or (verify / name).stat().st_size == 0]
        if missing:
            raise SystemExit(f"{destination} is missing {', '.join(missing)}")

    print(f"Wrote {destination} ({len(names)} sizes verified)")


def parse_arguments(argv):
    parser = argparse.ArgumentParser(
        description="Render assets/icon.svg into the app icon ladder and the README's copy.")
    parser.add_argument("--check", action="store_true",
                        help="re-render and compare against the committed files; write nothing")
    parser.add_argument("--icns", nargs="?", const=DEFAULT_ICNS_PATH, type=Path,
                        metavar="PATH",
                        help=f"also assemble a verified standalone .icns (default {DEFAULT_ICNS_PATH})")
    return parser.parse_args(argv)


def main(argv=None) -> int:
    arguments = parse_arguments(argv)
    primitives = load_svg(ARTWORK_PATH)

    # One render per distinct pixel count, shared by every consumer below: the
    # ladder and the preview repeat sizes (32, 256 and 512 each appear twice, and
    # 512 a third time), and `--check` and `--icns` both need what the writer
    # needs. Rendering is by far the slowest step here, so this memo is the whole
    # difference between a 13-second and a 32-second `--check`.
    cache: dict[int, numpy.ndarray] = {}

    def image(pixels: int) -> numpy.ndarray:
        if pixels not in cache:
            cache[pixels] = render(primitives, pixels)
        return cache[pixels]

    targets = [(PREVIEW_PATH, PREVIEW_PIXELS)]
    targets += [(ICONSET / f"{name}.png", pixels) for name, pixels in SLOTS.items()]

    if arguments.check:
        return check_targets(image, targets)

    ICONSET.mkdir(parents=True, exist_ok=True)
    for path, pixels in targets:
        path.write_bytes(encode_png(image(pixels)))
    CONTENTS_PATH.write_text(contents_json(), encoding="utf-8")

    print(f"Rendered {ARTWORK_PATH}")
    print(f"Wrote {len(SLOTS)} PNG slots to {ICONSET}")
    print(f"Wrote {CONTENTS_PATH}")
    print(f"Wrote {PREVIEW_PATH}")
    if arguments.icns:
        write_icns(image, arguments.icns)
    return 0


def check_targets(image: Callable[[int], numpy.ndarray], targets) -> int:
    """Report every generated file that no longer matches its committed copy.

    This is what turns "I edited the SVG and forgot to regenerate" from something
    only a human notices into a failing command. Missing files are reported
    separately from stale ones: on a fresh checkout that has not run the
    generator yet, "not generated" is the honest explanation.
    """
    missing = []
    stale = []
    for path, pixels in targets:
        if not path.is_file():
            missing.append(path)
        elif path.read_bytes() != encode_png(image(pixels)):
            stale.append(path)
    # The catalog's Contents.json lists the rungs actool will compile, so a
    # rung that exists but is not listed is as wrong as a stale image.
    if CONTENTS_PATH.read_text(encoding="utf-8") != contents_json():
        stale.append(CONTENTS_PATH)

    for path in missing:
        print(f"missing: {path}", file=sys.stderr)
    for path in stale:
        print(f"out of date: {path}", file=sys.stderr)
    if missing or stale:
        print("Run `python3 script/generate_icon.py` and commit the result.", file=sys.stderr)
        return 1
    print(f"Generated icon files match {ARTWORK_PATH} ({len(targets)} files and Contents.json)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
