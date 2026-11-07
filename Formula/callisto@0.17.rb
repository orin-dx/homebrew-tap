class CallistoAT017 < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.17.0.tar.gz"
  sha256 "3e4b4ded8fca0238e8adb6a5e85183ae2b35dcfe7d6922198f2052cfe80ba77c"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(/^callisto@v?(0\.17\.\d+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto@0.17-0.17.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "9c9c8cfd6eb5de41d66d3eb6d82a47bf6b2a9383d5b254d6adb85ae0431d6af7"
    sha256 cellar: :any,                 arm64_linux:  "0b0f42d3588ad11befca8035bfc13e5349a4955ecb93f7a59d0f246e95c109f6"
    sha256 cellar: :any,                 x86_64_linux: "a867a1bfe2ad5df0c9e6b2d7b0aa803668f95f477956461f00a3c38454779d17"
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
