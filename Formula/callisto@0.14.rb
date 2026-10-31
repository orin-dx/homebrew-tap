class CallistoAT014 < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.14.2.tar.gz"
  sha256 "cf4784c0eb6357f8c2447a37f50735ce71275ff827a1eec631f8181b1f53864b"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(/^callisto@v?(0\.14\.\d+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto@0.14-0.14.2"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "e8efca7236c4a0b9278c423716ebcfab6442148bc1064830901001a89aac3b07"
    sha256 cellar: :any,                 arm64_linux:  "e35b211be0f1598e02b099ed729670ba571f9cf1458aa3a8081e8fdb702c8e47"
    sha256 cellar: :any,                 x86_64_linux: "fc9d004715ad5c912a8247f00b302606a608b99ebce3199882339e213d40b621"
  end

  keg_only :versioned_formula

  depends_on "rust" => :build

  on_macos do
    on_intel do
      disable! date:    "2026-10-27",
               because: "Intel Macs are not supported (Homebrew has no Intel macOS bottles for Rust)"
    end
  end

  def install
    system "cargo", "install", *std_cargo_args(path: "crates/callisto-cli")
    generate_completions_from_executable(bin/"callisto", "completions")
  end

  test do
    assert_match "callisto #{version}", shell_output("#{bin}/callisto --version")
    assert_path_exists bash_completion/"callisto"
    assert_path_exists zsh_completion/"_callisto"
    assert_path_exists fish_completion/"callisto.fish"
    (testpath/"package.json").write <<~JSON
      {"name":"homebrew-fixture","version":"0.1.0"}
    JSON
    system "git", "init", "-q"
    system bin/"callisto", "init", "--yes", "--versioning", "independent", "--no-workflow"
    assert_path_exists testpath/"callisto.toml"
    assert_path_exists testpath/".changeset/README.md"
  end
end
