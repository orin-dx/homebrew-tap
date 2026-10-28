class CallistoAT015 < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.15.0.tar.gz"
  sha256 "ffe5b85b83214aa3cd5d4dca5f22ceddc265fc96e617eaf928063e8b7310f70f"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(/^callisto@v?(0\.15\.\d+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto@0.15-0.15.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "84de289d55504cb0f8431510da2f6d278228afdcfe0dabba6c1d585d8aff22e6"
    sha256 cellar: :any,                 arm64_linux:  "157bbabc84bd8e47d78eb089f71353b6b97b782ebf391bdfe1a314e1edbf49d3"
    sha256 cellar: :any,                 x86_64_linux: "8f568164a51231ae1ae293379ebcd244aed7313a841bde581710caa6164eaca8"
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
