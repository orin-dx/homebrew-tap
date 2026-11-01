import unittest

import tap_automation as t

OLD_SHA = "a" * 64
NEW_SHA = "b" * 64
CALLISTO = "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%40{}.tar.gz"
CALIPER = "https://github.com/orin-dx/caliper/archive/refs/tags/npm/caliper-docgen@{}.tar.gz"

FORMULA = """class Callisto < Formula
  desc "Example"
  url "{url}"
  sha256 "{sha}"
  license "MIT"
  head "https://github.com/orin-dx/callisto.git", branch: "main"

  livecheck do
    url :stable
    regex(/^callisto@v?(\\d+(?:\\.\\d+)+)$/i)
  end

  bottle do
    root_url "https://example.com"
    rebuild 1
    sha256 cellar: :any, arm64_linux: "{sha}"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install"
  end
end
"""


def formula(version, url=CALLISTO):
    return FORMULA.format(url=url.format(version), sha=OLD_SHA)


def bump_patch(old, new, old_sha=OLD_SHA, new_sha=NEW_SHA):
    return (
        "@@ -1,5 +1,5 @@\n class Callisto < Formula\n"
        f'-  url "{old}"\n-  sha256 "{old_sha}"\n+  url "{new}"\n+  sha256 "{new_sha}"\n   license "MIT"'
    )


def modified(patch, name="Formula/callisto.rb"):
    return [{"filename": name, "status": "modified", "patch": patch}]


class Versions(unittest.TestCase):
    def test_encoded_at_does_not_run_into_the_version(self):
        self.assertEqual(t.source_version(CALLISTO.format("0.15.0")), "0.15.0")
        self.assertEqual(t.formula_version(formula("0.16.2")), "0.16.2")

    def test_scoped_npm_style_tag(self):
        self.assertEqual(t.source_version(CALIPER.format("0.7.0")), "0.7.0")

    def test_breaking_lines(self):
        self.assertEqual(t.breaking_line("0.15.3"), "0.15")
        self.assertEqual(t.breaking_line("0.16.0"), "0.16")
        self.assertEqual(t.breaking_line("1.4.2"), "1")
        self.assertEqual(t.breaking_line("2.0.0"), "2")

    def test_rejects_other_hosts(self):
        self.assertIsNone(t.source_version("https://example.com/archive/refs/tags/v1.2.3.tar.gz"))


class MergeMethod(unittest.TestCase):
    def test_uses_the_method_the_repository_allows(self):
        self.assertEqual(t.merge_method({"allow_squash_merge": True, "allow_merge_commit": True}), "squash")
        self.assertEqual(t.merge_method({"allow_squash_merge": False, "allow_merge_commit": True}), "merge")
        self.assertEqual(t.merge_method({"allow_squash_merge": False, "allow_merge_commit": False}), "rebase")
        self.assertEqual(t.merge_method({}), "rebase")


class Snapshot(unittest.TestCase):
    def test_pre_1_0_snapshot(self):
        text = t.make_snapshot(formula("0.15.0"))
        self.assertIn("class CallistoAT015 < Formula", text)
        self.assertIn(r"regex(/^callisto@v?(0\.15\.\d+)$/i)", text)
        self.assertNotIn("bottle do", text)
        self.assertNotIn("head ", text)
        self.assertIn("  end\n\n  keg_only :versioned_formula\n\n  depends_on", text)

    def test_major_line_snapshot(self):
        text = t.make_snapshot(formula("2.3.1"))
        self.assertIn("class CallistoAT2 < Formula", text)
        self.assertIn(r"regex(/^callisto@v?(2(?:\.\d+)+)$/i)", text)

    def test_npm_style_regex_is_pinned(self):
        source = formula("0.7.0", CALIPER).replace(
            r"regex(/^callisto@v?(\d+(?:\.\d+)+)$/i)", r"regex(%r{^npm/caliper-docgen@v?(\d+(?:\.\d+)+)$}i)"
        )
        self.assertIn(r"(0\.7\.\d+)", t.make_snapshot(source))

    def test_unexpected_livecheck_shape_is_an_error(self):
        with self.assertRaises(ValueError):
            t.make_snapshot(formula("0.15.0").replace(r"(\d+(?:\.\d+)+)", "(.+)"))


class Bump(unittest.TestCase):
    def check(self, files, on_main=()):
        return t.check_bump(files, lambda path: path in on_main)

    def test_patch_bump_in_the_same_line_merges(self):
        patch = bump_patch(CALLISTO.format("0.16.0"), CALLISTO.format("0.16.1"))
        self.assertIsNone(self.check(modified(patch)))

    def test_new_line_waits_for_the_snapshot(self):
        patch = bump_patch(CALLISTO.format("0.15.0"), CALLISTO.format("0.16.0"))
        self.assertIn("callisto@0.15.rb is not on main", self.check(modified(patch)))
        self.assertIsNone(self.check(modified(patch), on_main={"Formula/callisto@0.15.rb"}))

    def test_other_changes_are_rejected(self):
        patch = bump_patch(CALLISTO.format("0.16.0"), CALLISTO.format("0.16.1")) + '\n+  depends_on "curl"'
        self.assertIn("more than the source url", self.check(modified(patch)))

    def test_other_repository_is_rejected(self):
        new = "https://github.com/someone/else/archive/refs/tags/callisto%400.16.1.tar.gz"
        patch = bump_patch(CALLISTO.format("0.16.0"), new)
        self.assertIn("same GitHub source repository", self.check(modified(patch)))

    def test_downgrade_is_rejected(self):
        patch = bump_patch(CALLISTO.format("0.16.1"), CALLISTO.format("0.16.0"))
        self.assertIn("newer version", self.check(modified(patch)))

    def test_missing_sha_is_rejected(self):
        patch = bump_patch(CALLISTO.format("0.16.0"), CALLISTO.format("0.16.1")).replace(f"+  sha256 \"{NEW_SHA}\"\n", "")
        self.assertIn("exactly one url and one sha256", self.check(modified(patch)))

    def test_added_or_non_formula_files_are_rejected(self):
        patch = bump_patch(CALLISTO.format("0.16.0"), CALLISTO.format("0.16.1"))
        self.assertIn("not a modified formula", self.check([{"filename": "Formula/x.rb", "status": "added", "patch": patch}]))
        self.assertIn("not a modified formula", self.check(modified(patch, name=".github/workflows/publish.yml")))

    def test_versioned_formula_stays_in_its_line(self):
        patch = bump_patch(CALLISTO.format("0.15.2"), CALLISTO.format("0.16.0"))
        self.assertIn("own line", self.check(modified(patch, name="Formula/callisto@0.15.rb")))
        patch = bump_patch(CALLISTO.format("0.15.2"), CALLISTO.format("0.15.3"))
        self.assertIsNone(self.check(modified(patch, name="Formula/callisto@0.15.rb")))


class SnapshotPullRequest(unittest.TestCase):
    base = formula("0.15.0")

    def check(self, files, head_text):
        return t.check_snapshot(files, head_text, lambda path: self.base if path == "Formula/callisto.rb" else None)

    def added(self, name="Formula/callisto@0.15.rb"):
        return [{"filename": name, "status": "added"}]

    def test_generated_snapshot_merges(self):
        self.assertIsNone(self.check(self.added(), t.make_snapshot(self.base)))

    def test_edited_snapshot_is_rejected(self):
        self.assertIn("differs from the generated", self.check(self.added(), t.make_snapshot(self.base) + "# extra\n"))

    def test_wrong_line_name_is_rejected(self):
        self.assertIn("not the line main is on", self.check(self.added("Formula/callisto@0.14.rb"), t.make_snapshot(self.base)))

    def test_more_than_one_file_is_rejected(self):
        files = self.added() + self.added("Formula/other@1.rb")
        self.assertIn("exactly one file", self.check(files, ""))


if __name__ == "__main__":
    unittest.main()
