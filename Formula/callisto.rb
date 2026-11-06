class Callisto < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.17.0.tar.gz"
  sha256 "3e4b4ded8fca0238e8adb6a5e85183ae2b35dcfe7d6922198f2052cfe80ba77c"
  license "FSL-1.1-MIT"
  head "https://github.com/orin-dx/callisto.git", branch: "main"

  livecheck do
    url :stable
    regex(/^callisto@v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto-0.17.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "36a9ce298fbe674e73000dd4da49e6410c8895fdf85eeba22e87b5f9597f0426"
    sha256 cellar: :any,                 arm64_linux:  "2e5ab2091c6f5141b7a789e1b9984a41e60b76f5fe7e7d1a9373102e8cd8b3b8"
    sha256 cellar: :any,                 x86_64_linux: "672cba2f4d0dce3e469339b547a7560001631a0495f14b8c78953f64a8d39284"
  end

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
