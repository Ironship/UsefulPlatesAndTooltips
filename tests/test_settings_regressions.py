"""Reproduce the reported /upt tab, resource preview, shield and Hunter cases offline."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent
fixture = {"__file__": str(ROOT / "tests/test_bit.py")}
exec(compile((ROOT / "tests/test_bit.py").read_text(encoding="utf-8").split(
    'print("-- every module on")', 1)[0], "fixture", "exec"), fixture)


def ready(saved=""):
    rt, g, bit, _ = fixture["load"](saved)
    g.Fire("ADDON_LOADED", "UsefulPlatesAndTooltips")
    g.Fire("PLAYER_LOGIN")
    return rt, g, bit


def click(button):
    button.scripts.OnClick(button)


class SettingsRegressions(unittest.TestCase):
    def test_dot_tabs_fit_after_native_buttons_expand(self):
        rt, g, bit = ready()
        bit.OpenSettings("DoTInfo")
        area = bit._pages.DoTInfo.content.settingsArea
        buttons = [f for f in area.children.values() if f.template == "PanelTopTabButtonTemplate"]
        self.assertEqual([b.GetText(b) for b in buttons],
                         ["Kill icon", "Marker", "Effects", "Text", "Nameplates", "Behavior"])
        # Native OnShow imposes a minimum width after the addon anchors the tabs.
        for button in buttons:
            button.SetWidth(button, max(90, button.width))
        available = bit.tabs.DoTInfo.width - 290 - 40
        positions = {}
        for button in buttons:
            point = button.points[len(button.points)]
            if point[1] == "TOPLEFT":
                self.assertTrue(g.Same(point[2], area))
                x, y = point[4], point[5]
            else:
                self.assertEqual((point[1], point[3]), ("LEFT", "RIGHT"))
                previous_x, previous_y, previous_width = positions[point[2].GetText(point[2])]
                x, y = previous_x + previous_width + point[4], previous_y + point[5]
            positions[button.GetText(button)] = (x, y, button.width)
            self.assertGreaterEqual(x - 3, 0)
            self.assertLessEqual(x + button.width + 9, available, button.GetText(button))
            click(button)
            self.assertTrue(button.nativeSelected)
            self.assertEqual(sum(bool(b.nativeSelected) for b in buttons), 1)
        row_bottom = min(y - 26 for _, y, _ in positions.values())
        contents = [f for f in area.children.values() if f.kind == "Frame"]
        self.assertEqual(len(contents), 6)
        for content in contents:
            self.assertLessEqual(content.points[1][5], row_bottom - 6)

    def test_selected_tab_label_moves_outward(self):
        rt, g, bit = ready()
        for page in ("__together", "ResourceDing", "DoTInfo", "StatsInfo", "Range", "ShieldsInfo", "HunterRangeFinder"):
            bit.OpenSettings(page)
        buttons = [f for f in g.AllFrames.values() if f.template == "PanelTopTabButtonTemplate"]
        self.assertGreater(len(buttons), 20)
        for button in buttons:
            label = button.caption if button.caption is not None else button.text
            self.assertTrue(g.Same(label, button.GetFontString(button)), "visible label bypasses native tab state")
            self.assertGreater(button.LeftActive.height, button.Left.height, "selected tab rim must project outward")
            height = button.LeftActive.height
            bit.UI.SkinTabButton(button, label)
            self.assertEqual(button.LeftActive.height, height, "reskinning must not keep enlarging the tab")
            bit.UI.TabSelected(button, True)
            selected_y = label.points[len(label.points)][5]
            bit.UI.TabSelected(button, False)
            idle_y = label.points[len(label.points)][5]
            self.assertGreater(selected_y, idle_y, "selected top tab must protrude upward")
            self.assertEqual(idle_y, 0)

    def test_combo_and_shards_previews_are_exclusive_and_controls_follow_tab(self):
        rt, g, bit = ready()
        bit.OpenSettings("ResourceDing")
        rd = bit.modules.ResourceDing
        panel = rd.settingsPanel
        tabs = {t.button.text.text: t for t in panel.tabs.values()}
        self.assertIn("Combo", tabs)
        self.assertNotIn("Dots", tabs)
        scene = next(f for f in g.AllFrames.values() if f.dotsRow is not None)
        rd.db.dotOffset, rd.db.shardOffset = -30, -45
        for name in ("Shards", "Combo", "Shards", "Combo"):
            click(tabs[name].button)
            shards = name == "Shards"
            self.assertEqual(bool(scene.dotsRow.shown), not shards)
            self.assertEqual(bool(scene.shardsRow.shown), shards)
            self.assertEqual("soul shards" in scene.caption.text, shards)
            self.assertEqual("combo points" in scene.caption.text, not shards)
            rows = {f.label.text: f for f in scene.parent.children.values() if f.label is not None}
            self.assertEqual(rows["Soul shards" if shards else "Combo points"].widget.value, 5)
            before_dot, before_shard = rd.db.dotOffset, rd.db.shardOffset
            rows["Offset"].widget.scripts.OnValueChanged(rows["Offset"].widget, -55 if shards else -25)
            self.assertEqual(rd.db.shardOffset, -55 if shards else before_shard)
            self.assertEqual(rd.db.dotOffset, before_dot if shards else -25)
            self.assertTrue(rd.db.dots and rd.db.shardDiamonds, "preview selection changed gameplay switches")
        rd.db.shardDiamonds = False
        click(tabs["Shards"].button)
        self.assertFalse(scene.dotsRow.shown or scene.shardsRow.shown)
        rd.db.shardDiamonds = True
        click(panel.resetButton)
        self.assertEqual(rd.db.shardOffset, -60)
        click(tabs["Combo"].button)
        click(panel.resetButton)
        self.assertEqual(rd.db.dotOffset, -60)

    def test_fresh_offsets_and_saved_custom_offsets(self):
        for saved, expected in (("", (-60, -60, -60)), (
            "UsefulPlatesAndTooltipsDB={modules={HunterRangeFinder={plateOffset=-27,plateScheme=2}}};"
            "UsefulPlatesAndTooltips_ResourceDingDB={dotOffset=-31,shardOffset=12}", (-27, -31, 12))):
            rt, g, bit = ready(saved)
            self.assertEqual(bit.Plate.ReadOffsets(), expected)
            rd = bit.modules.ResourceDing
            self.assertEqual((rd.db.dotOffset, rd.db.shardOffset), expected[1:])

    def test_hunter_defaults_match_screenshot_and_reset(self):
        rt, g, bit = ready()
        expected = dict(opacity=1, shape="dots", border=0, thickness=17, gap=21,
                        length=12, scale=0.9, fontSize=12, outline="OUTLINE")
        for action in (lambda: None, lambda: bit.Style.Reset("HunterRangeFinder")):
            action()
            style = bit.Style.Resolve("HunterRangeFinder")
            self.assertEqual({key: style[key] for key in expected}, expected)
        bit.Style.Set("HunterRangeFinder", "gap", 13)
        self.assertEqual(bit.Style.Resolve("HunterRangeFinder").gap, 13)

    def test_shield_juicy_is_translucent_reverse_stripes(self):
        rt, g, bit = ready()
        bit.OpenSettings("ShieldsInfo")
        juicy = next(f for f in g.AllFrames.values() if f.kind == "Button" and f.GetText(f) == "Juicy"
                     and g.Same(f.parent, bit._pages.ShieldsInfo.content))
        click(juicy)
        settings = bit.DB().modules.ShieldsInfo
        self.assertEqual(settings.fillTexture, "stripes")
        self.assertGreater(settings.overlayAlpha, 0)
        self.assertLessEqual(settings.overlayAlpha, 0.6)
        scene = next(f for f in g.AllFrames.values() if f.kits is not None)
        fill = scene.overlay.GetStatusBarTexture(scene.overlay)
        self.assertTrue(fill.horizTile and fill.vertTile)
        self.assertTrue(fill.texture.endswith("Stripes.tga"))
        for module, shift in (("ShieldsInfo", 1), ("DoTInfo", -1)):
            raw = (ROOT / "Modules" / module / "Textures/Stripes.tga").read_bytes()
            self.assertEqual((raw[2], raw[16], raw[17] & 32), (2, 32, 32))
            width = int.from_bytes(raw[12:14], "little")
            alpha = lambda x, y: raw[18 + 4 * (y * width + x % width) + 3]
            self.assertTrue(any(alpha(x, 0) > 128 for x in range(width)))
            for y in range(1, 8):
                self.assertEqual([alpha(x, y) for x in range(width)],
                                 [alpha(x - shift, y - 1) for x in range(width)], module)


if __name__ == "__main__":
    unittest.main(verbosity=2)
