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
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "54945104d08a9309f55ae12b720995a0845799b502179ecb6fd79473212a2c5b"
    sha256 cellar: :any,                 arm64_linux:  "79fba932a73548448490301bf3a9f167eed11ccb4da2f0d0841d067b12fda998"
    sha256 cellar: :any,                 x86_64_linux: "8464fc95c3ac9f19135d4c440db03065e56cf249d0e166d3a43ef9535a5da761"
  end

  keg_only :versioned_formula

  depends_on "rust" => :build

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
