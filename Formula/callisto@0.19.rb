class CallistoAT019 < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.19.0.tar.gz"
  sha256 "160ef3374cff1b560aebb29e00155dfec628e2fe99d87095eb415c3d7c2f9c4f"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(/^callisto@v?(0\.19\.\d+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto@0.19-0.19.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "f2eff361086b2591fd845bdff03df6ef63e2adb8791e944608a23e035dfb820e"
    sha256 cellar: :any,                 arm64_linux:  "0d0ce49dc639d1804535e39b021f40f93ecba8a43fd990f54b05988bc636325e"
    sha256 cellar: :any,                 x86_64_linux: "0385717c999594b47a3dd4e349e3c9f8afdfe599dbfc89e108c1f1f2e6609d03"
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
