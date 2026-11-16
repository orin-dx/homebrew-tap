class Callisto < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.21.1.tar.gz"
  sha256 "fc8a940f68908e4770cf1b15c2c48b764c15178bc3f6f17b4bac27f88d6bb444"
  license "FSL-1.1-MIT"
  head "https://github.com/orin-dx/callisto.git", branch: "main"

  livecheck do
    url :stable
    regex(/^callisto@v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto-0.21.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "19ab12daa990f6ee25e7011e3245fae08c6691d109887847927848ff089693cf"
    sha256 cellar: :any,                 arm64_linux:  "9e2d3d51c911787715f77af9582b64b8cf88220da124c9c10cf8d6695ea35340"
    sha256 cellar: :any,                 x86_64_linux: "bb88214da526fe77b85fc5851c9e6bfb23efec1e5218174ccb8715b46ca691c8"
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
