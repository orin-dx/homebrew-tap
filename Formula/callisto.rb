class Callisto < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.20.0.tar.gz"
  sha256 "bd1c6fb7ad91dc847220b64f31dcffe5daaa6d4048c02223ec1e907f8cbfbf7d"
  license "FSL-1.1-MIT"
  head "https://github.com/orin-dx/callisto.git", branch: "main"

  livecheck do
    url :stable
    regex(/^callisto@v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto-0.20.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "5c97f1664c9ebb7e9588bb434e4c3bf3e4b1bd32f42022adfebd4bc6a808cb2c"
    sha256 cellar: :any,                 arm64_linux:  "03a875fb1bfb37597e6ab2a266b3a15d513fbbe7086626bc44d49dc8c6f814ae"
    sha256 cellar: :any,                 x86_64_linux: "51c1b3dea84707302f95bdf9b4e65431ef762b7516fe464c5e97f548593db499"
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
