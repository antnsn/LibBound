"""Tests for crop_shots.py's CurseForge gallery. Run from the repo root:
  python3 tests/test_crop_shots.py
"""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
import crop_shots as cs  # noqa: E402

from PIL import Image  # noqa: E402


class GalleryOrder(unittest.TestCase):
    def test_overview_first_then_each_page_with_its_frames(self):
        shots = ["options-poisons", "options-reagents", "options-travel", "options-extras", "frames-unlocked", "travel"]
        docs = {
            "poisons.md": ["frames/mhpoint.png", "frames/ohpoint.png", "options-poisons.png"],
            "reagents.md": ["frames/rgpoint.png", "options-reagents.png"],
            "travel.md": ["travel.png", "options-travel.png"],
            "buff-key.md": ["options-extras.png"],
            "well-fed.md": ["frames/wrpoint.png", "frames/wfpoint.png", "options-extras.png"],
            "frames.md": ["frames-unlocked.png"],
        }
        self.assertEqual(cs.gallery_order(shots, docs), [
            "frames-unlocked.png",
            "options-poisons.png", "frames/mhpoint.png", "frames/ohpoint.png",
            "options-reagents.png", "frames/rgpoint.png",
            "options-travel.png", "travel.png",
            "options-extras.png", "frames/wrpoint.png", "frames/wfpoint.png",
        ])

    def test_unused_frames_are_left_out_and_lone_shots_kept(self):
        shots = ["options-skin", "frames-unlocked", "minimap"]
        docs = {"skins.md": ["options-skin.png"]}
        self.assertEqual(cs.gallery_order(shots, docs), ["frames-unlocked.png", "options-skin.png", "minimap.png"])

    def test_doc_refs_are_read_from_markdown(self):
        text = "![a]({{ '/screenshots/frames/mhpoint.png' | relative_url }})\n![b](../screenshots/options-x.png)"
        self.assertEqual(cs.doc_images(text), ["frames/mhpoint.png", "options-x.png"])


class GallerySize(unittest.TestCase):
    def test_numbered_files_and_big_ones_become_jpeg_under_the_limit(self):
        with tempfile.TemporaryDirectory() as d:
            shots, out = os.path.join(d, "shots"), os.path.join(d, "cf")
            os.makedirs(os.path.join(shots, "frames"))
            Image.effect_noise((1400, 1400), 100).convert("RGB").save(os.path.join(shots, "big.png"))
            Image.new("RGB", (40, 20)).save(os.path.join(shots, "frames", "small.png"))
            os.makedirs(out)
            open(os.path.join(out, "9_old.png"), "w").close()  # an earlier run's file goes
            names = cs.write_gallery(shots, ["big.png", "frames/small.png"], out, limit=1024 * 1024)
            self.assertEqual(names, ["1_big.jpg", "2_small.png"])
            self.assertEqual(sorted(os.listdir(out)), ["1_big.jpg", "2_small.png"])
            self.assertLess(os.path.getsize(os.path.join(out, "1_big.jpg")), 1024 * 1024)

    def test_too_big_even_as_jpeg_is_scaled_down(self):
        with tempfile.TemporaryDirectory() as d:
            Image.effect_noise((1200, 1200), 100).convert("RGB").save(os.path.join(d, "noise.png"))
            out = os.path.join(d, "cf")
            names = cs.write_gallery(d, ["noise.png"], out, limit=150 * 1024)  # noise at q45 is ~400 KB
            self.assertLessEqual(os.path.getsize(os.path.join(out, names[0])), 150 * 1024)


if __name__ == "__main__":
    unittest.main()
