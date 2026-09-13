import importlib.util
import json
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

import numpy


ROOT = Path(__file__).resolve().parents[2]
ICON_SCRIPT = ROOT / "script" / "generate_icon.py"
LIB_SCRIPT = ROOT / "script" / "lib.sh"
ICONSET = ROOT / "src" / "app" / "resources" / "Assets.xcassets" / "AppIcon.appiconset"

spec = importlib.util.spec_from_file_location("oneclick_generate_icon", ICON_SCRIPT)
icon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(icon)


class ContentsJsonTests(unittest.TestCase):
    def test_regenerated_contents_matches_the_committed_catalog(self):
        """Xcode's own layout, byte for byte.

        A whitespace-only difference here would show up as a spurious diff every
        time the generator runs, which is exactly what makes people stop running
        it. The committed file is also the one actool actually reads.
        """
        self.assertEqual(icon.contents_json(), icon.CONTENTS_PATH.read_text(encoding="utf-8"))

    def test_every_slot_is_listed_and_the_scale_matches_the_pixel_count(self):
        listed = json.loads(icon.contents_json())["images"]
        self.assertEqual([entry["filename"] for entry in listed],
                         [f"{name}.png" for name in icon.SLOTS])
        for entry in listed:
            stem = entry["filename"][: -len(".png")]
            pixels = icon.SLOTS[stem]
            points = int(entry["size"].split("x")[0])
            scale = int(entry["scale"].rstrip("x"))
            self.assertEqual(points * scale, pixels,
                             f"{entry['filename']} declares {points}x{points}@{scale}x "
                             f"but SLOTS renders {pixels}px")

    def test_contents_follows_slots_so_a_new_rung_cannot_be_orphaned(self):
        """The regression this guards: a rung written but not referenced.

        actool ignores an unreferenced PNG, so the icon would silently keep the
        old artwork at that size. Rewriting SLOTS must therefore move the file,
        not just the renderer.
        """
        original = dict(icon.SLOTS)
        try:
            icon.SLOTS["icon_1024x1024"] = 2048
            listed = json.loads(icon.contents_json())["images"]
            self.assertIn("icon_1024x1024.png", [entry["filename"] for entry in listed])
        finally:
            icon.SLOTS.clear()
            icon.SLOTS.update(original)


class PngEncodingTests(unittest.TestCase):
    def test_encoding_is_deterministic(self):
        image = numpy.zeros((5, 4, 4), dtype=float)
        image[..., 3] = 1.0
        self.assertEqual(icon.encode_png(image), icon.encode_png(image))

    def test_encoding_writes_the_expected_png_container(self):
        image = numpy.zeros((3, 7, 4), dtype=float)
        image[..., 3] = 0.5
        data = icon.encode_png(image)
        self.assertTrue(data.startswith(b"\x89PNG\r\n\x1a\n"))
        self.assertEqual(data[12:16], b"IHDR")
        # width, height, bit depth, colour type
        self.assertEqual(data[16:26], b"\x00\x00\x00\x07\x00\x00\x00\x03\x08\x06")
        self.assertEqual(data[-8:-4], b"IEND")

    def test_opaque_black_and_transparent_are_encoded_distinctly(self):
        """Guards the float -> 8-bit step, which has been wrong before.

        A missing `/ 255.0` in the renderer once produced an all-white icon that
        still looked plausible in memory, so the values are checked after
        encoding rather than by reading the float array back.
        """
        transparent = numpy.zeros((1, 1, 4), dtype=float)
        white = numpy.ones((1, 1, 4), dtype=float)
        self.assertNotEqual(icon.encode_png(transparent), icon.encode_png(white))


class ArtworkParityTests(unittest.TestCase):
    """The committed ladder must be exactly what the artwork renders to.

    This is the check that catches "edited assets/icon.svg and forgot to
    regenerate". The two smallest rungs are used because they cover the whole
    pipeline (parse, rasterize, composite, encode) in a fraction of a second; the
    full ladder is compared by `./script/check.sh`.
    """

    def test_small_rungs_match_the_committed_pngs(self):
        primitives = icon.load_svg(icon.ARTWORK_PATH)
        for name in ("icon_16x16", "icon_16x16@2x"):
            with self.subTest(slot=name):
                committed = (ICONSET / f"{name}.png").read_bytes()
                self.assertEqual(icon.encode_png(icon.render(primitives, icon.SLOTS[name])),
                                 committed,
                                 f"{name}.png is stale; run python3 script/generate_icon.py")

    def test_committed_rungs_are_the_flattened_rendering(self):
        """A size is rendered once and reused, so 32px rungs must agree.

        16x16@2x and 32x32 are the same pixel count by design; if the cache or the
        SLOTS map ever drifted, two files that should be identical would not be.
        """
        self.assertEqual(icon.SLOTS["icon_16x16@2x"], icon.SLOTS["icon_32x32"])
        self.assertEqual((ICONSET / "icon_16x16@2x.png").read_bytes(),
                         (ICONSET / "icon_32x32.png").read_bytes())


class ArtworkValidationTests(unittest.TestCase):
    """The renderer only implements what the artwork uses, and must say so."""

    def write_svg(self, body, view_box="0 0 1024 1024"):
        handle = tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False)
        handle.write(f'<svg viewBox="{view_box}">{body}</svg>')
        handle.close()
        self.addCleanup(Path(handle.name).unlink)
        return Path(handle.name)

    def test_unsupported_element_is_rejected(self):
        with self.assertRaises(ValueError):
            icon.load_svg(self.write_svg('<circle cx="10" cy="10" r="5" fill="#ffffff"/>'))

    def test_horizontal_gradient_is_rejected(self):
        with self.assertRaises(ValueError):
            icon.load_svg(self.write_svg(
                '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="0">'
                '<stop offset="0" stop-color="#000000"/>'
                '<stop offset="1" stop-color="#ffffff"/>'
                "</linearGradient></defs>"
                '<rect x="0" y="0" width="10" height="10" fill="url(#g)"/>'))

    def test_unsupported_colour_is_rejected(self):
        with self.assertRaises(ValueError):
            icon.load_svg(self.write_svg('<rect x="0" y="0" width="4" height="4" fill="red"/>'))

    def test_unexpected_viewbox_is_rejected(self):
        with self.assertRaises(ValueError):
            icon.load_svg(self.write_svg('<rect width="4" height="4" fill="#ffffff"/>',
                                         view_box="0 0 10 10"))


class RasterizerTests(unittest.TestCase):
    def test_fill_covers_a_square_exactly(self):
        ring = numpy.array([[0.0, 0.0], [8.0, 0.0], [8.0, 8.0], [0.0, 8.0]])
        coverage = icon.fill_rings([ring], 8, 1.0, 1)
        self.assertAlmostEqual(coverage[4, 4], 1.0)
        self.assertAlmostEqual(coverage[0, 0], 1.0)

    def test_fill_uses_even_odd_so_an_inner_ring_holes_the_shape(self):
        outer = numpy.array([[0.0, 0.0], [8.0, 0.0], [8.0, 8.0], [0.0, 8.0]])
        inner = numpy.array([[2.0, 2.0], [6.0, 2.0], [6.0, 6.0], [2.0, 6.0]])
        coverage = icon.fill_rings([outer, inner], 8, 1.0, 1)
        self.assertAlmostEqual(coverage[4, 4], 0.0, msg="the hole is filled")
        self.assertAlmostEqual(coverage[1, 1], 1.0, msg="the ring is missing")

    def test_rings_with_fewer_than_three_points_are_ignored(self):
        """Not just an optimization: a two-point ring collapses the sample window."""
        coverage = icon.fill_rings([numpy.array([[0.0, 0.0], [1.0, 1.0]])], 8, 1.0, 1)
        self.assertEqual(float(coverage.sum()), 0.0)

    def test_stroke_is_the_band_within_half_the_width(self):
        line = numpy.array([[0.0, 4.0], [8.0, 4.0]])
        # A 2-wide stroke around y=4 covers y in [3, 5); the sample at y=4.5 is
        # inside it and one at y=6.5 is not.
        coverage = icon.stroke_coverage(line, 2.0, 8, 1.0, 1)
        self.assertAlmostEqual(coverage[4, 4], 1.0)
        self.assertAlmostEqual(coverage[6, 4], 0.0)

    def test_degenerate_segments_do_not_poison_the_distance(self):
        """Two coincident points contribute their own position, not NaN."""
        line = numpy.array([[4.0, 4.0], [4.0, 4.0], [8.0, 4.0]])
        coverage = icon.stroke_coverage(line, 2.0, 8, 1.0, 1)
        self.assertFalse(numpy.isnan(coverage).any())
        self.assertAlmostEqual(coverage[4, 4], 1.0)


class LibraryContractTests(unittest.TestCase):
    """`script/lib.sh` is shared by four scripts, so its contract is tested once."""

    def run_probe(self, body):
        """Run `body` with lib.sh sourced.

        A real file rather than `bash -c` so both helpers have the same shape; the
        name only matters to the tests that check who a failure is attributed to.
        """
        return self.run_script("probe.sh", body)

    def run_script(self, name, body):
        """Run `body` as a real script file called `name`.

        lib.sh attributes a failure to the file it was called from, so the caller
        has to exist as a file for that to be observable at all.
        """
        directory = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: subprocess.run(["/bin/rm", "-rf", str(directory)], check=False))
        script = directory / name
        script.write_text(textwrap.dedent(f"""\
            set -euo pipefail
            source "{LIB_SCRIPT}"
            {body}
            """))
        return subprocess.run(["/bin/bash", str(script)], text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)

    def test_version_validation_accepts_releases_and_rejects_smuggling(self):
        accepted = ["0.1.0", "1.2.3", "10.20.30"]
        rejected = ["v1.2.3", "1.2", "1.2.3.4", "01.2.3", "", "1.2.3;id"]
        # One statement per line: `a && b || c` chains do not stay attached to
        # their own value once several are joined by spaces.
        script = "\n".join(
            f'oneclick_is_version "{value}" && echo "accept:{value}" || echo "reject:{value}"'
            for value in accepted + rejected)
        result = self.run_probe(script)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.split(), [f"accept:{value}" for value in accepted]
                         + [f"reject:{value}" for value in rejected])

    def test_missing_environment_is_reported_all_at_once_with_status_two(self):
        result = self.run_probe(
            "ONECLICK_PRESENT=1 ONECLICK_EMPTY= "
            "oneclick_require_env ONECLICK_PRESENT ONECLICK_EMPTY ONECLICK_ABSENT")
        self.assertEqual(result.returncode, 2)
        self.assertIn("ONECLICK_EMPTY", result.stderr)
        self.assertIn("ONECLICK_ABSENT", result.stderr)
        self.assertNotIn("ONECLICK_PRESENT", result.stderr)

    def test_missing_environment_is_silent_when_everything_is_set(self):
        result = self.run_probe("ONECLICK_A=1 ONECLICK_B=2 oneclick_require_env ONECLICK_A ONECLICK_B")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")

    def test_failures_are_attributed_to_the_calling_script(self):
        """Not to lib.sh, which is one frame up for anything lib.sh itself raises.

        `oneclick_require_env` calls `oneclick_fail` from inside lib.sh, so
        `${BASH_SOURCE[1]}` would name lib.sh and every message would read as if
        the library had failed rather than the script that asked it to check.
        """
        result = self.run_script("my-script.sh", "oneclick_require_env ONECLICK_ABSENT")
        self.assertEqual(result.returncode, 2)
        self.assertTrue(result.stderr.startswith("my-script.sh: "), result.stderr)
        self.assertNotIn("lib.sh:", result.stderr)

    def test_direct_failures_use_the_callers_name_and_status_one(self):
        result = self.run_script("another-script.sh", 'fail() { oneclick_fail "$1"; }; fail boom')
        self.assertEqual(result.returncode, 1)
        self.assertTrue(result.stderr.startswith("another-script.sh: boom"), result.stderr)

    def test_usage_failures_exit_two(self):
        result = self.run_script("third-script.sh", "oneclick_fail_usage 'bad invocation'")
        self.assertEqual(result.returncode, 2)
        self.assertTrue(result.stderr.startswith("third-script.sh: bad invocation"), result.stderr)

    def test_root_is_derived_from_the_library_not_the_callers_directory(self):
        result = self.run_probe('cd /tmp && echo "$(oneclick_root)"')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(Path(result.stdout.strip()).resolve(), ROOT)


if __name__ == "__main__":
    unittest.main()
