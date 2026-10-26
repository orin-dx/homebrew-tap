import unittest

from select_tools import select_tools
from update_formula import ROOT, list_tools


class SelectToolsTests(unittest.TestCase):
    def setUp(self):
        self.available = ["caliper", "callisto", "firkin"]

    def test_docs_change_needs_no_formula_runners(self):
        self.assertEqual(select_tools(["README.md", "docs/tools/caliper.md"], self.available), [])

    def test_formula_and_manifest_choose_each_changed_tool_once(self):
        self.assertEqual(
            select_tools(["Formula/caliper.rb", "tools/caliper.json", "Formula/callisto.rb"], self.available),
            ["caliper", "callisto"],
        )

    def test_updater_or_workflow_change_checks_every_tool(self):
        for path in ["scripts/update_formula.py", ".github/workflows/ci.yml"]:
            with self.subTest(path=path):
                self.assertEqual(select_tools([path], self.available), self.available)

    def test_deleted_manifest_cannot_silently_skip_formula_check(self):
        with self.assertRaisesRegex(ValueError, "no tool manifest"):
            select_tools(["tools/removed.json"], self.available)

    def test_every_packaged_tool_has_a_guide_and_catalog_link(self):
        readme = (ROOT / "README.md").read_text()
        for tool in list_tools(ROOT):
            with self.subTest(tool=tool):
                guide = f"docs/tools/{tool}.md"
                self.assertTrue((ROOT / guide).is_file())
                self.assertIn(f"({guide})", readme)


if __name__ == "__main__":
    unittest.main()
