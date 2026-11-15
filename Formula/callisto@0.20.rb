class CallistoAT020 < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.20.0.tar.gz"
  sha256 "bd1c6fb7ad91dc847220b64f31dcffe5daaa6d4048c02223ec1e907f8cbfbf7d"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(/^callisto@v?(0\.20\.\d+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto@0.20-0.20.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "68fceee43e56533e1b797625b60fff98fb3a56ee257f2500acfa4192ed9e2b52"
    sha256 cellar: :any,                 arm64_linux:  "511e29a5d0e3405fa58b60bfe0eb0c8648fc7850370e5898ad659c0b37a305ee"
    sha256 cellar: :any,                 x86_64_linux: "479eacc6b2d6533a21e0062acdff555d5b7d6f745ef2fee69871b2bca56f4c97"
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
