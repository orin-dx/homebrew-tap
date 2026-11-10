class CallistoAT018 < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.18.0.tar.gz"
  sha256 "afee1dccf862b383f0a7d3cc4a08bd5d7627df41ce3d57d9b8fca9be3f3fe994"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(/^callisto@v?(0\.18\.\d+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto@0.18-0.18.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "8f62571a7618360b5d831672d17cd8c75354916d3f2f84bf42695f771ca198ff"
    sha256 cellar: :any,                 arm64_linux:  "21556a619b7eba43e8f62136ac16153f83f9f5eda2cb526e5b57fc9c6519ab57"
    sha256 cellar: :any,                 x86_64_linux: "a2beac7998df4cd47ed1b1503c2fd96484608f5e8f85325df1a139bfa914505b"
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
