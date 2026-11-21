class CallistoAT021 < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.21.1.tar.gz"
  sha256 "fc8a940f68908e4770cf1b15c2c48b764c15178bc3f6f17b4bac27f88d6bb444"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(/^callisto@v?(0\.21\.\d+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto@0.21-0.21.1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "0ddca162320273093d40fcffe4888a5f078047bbf068f84d519dca00cbf83e8f"
    sha256 cellar: :any,                 arm64_linux:  "17d9f516d4ad65a31ccc985f179f53a4efc90fa558c307b48555e177b5b97215"
    sha256 cellar: :any,                 x86_64_linux: "c5ee64a092fd0c4ac82d1a94a14adac22b54f33fa887f841e88c8ee48e7fc662"
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
