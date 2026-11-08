class CallistoAT016 < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.16.0.tar.gz"
  sha256 "1fd6ba5de9bdf110ec8c629f3910da67e930a2268194b2a1945cc5d466afc6ed"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(/^callisto@v?(0\.16\.\d+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto@0.16-0.16.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "8c951cdbb8f3043073bd4713ec7d1991eaffb29bfd355f6cba18a11ec9ab28f0"
    sha256 cellar: :any,                 arm64_linux:  "9c16a022cd0a7eef10dad76879b137fe3d422163ba76a41fb604ce70c38b949e"
    sha256 cellar: :any,                 x86_64_linux: "783ddbd337e30a4eecfb2fe414e2c2cda24e46c11acbf51c5d1968aa0b99172d"
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
