class Callisto < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  url "https://github.com/orin-dx/callisto/archive/refs/tags/callisto%400.22.0.tar.gz"
  sha256 "5937b473070cfc28e9257f0a73564e94aff27d2a990016089f8a6edb73cbf645"
  license "FSL-1.1-MIT"
  head "https://github.com/orin-dx/callisto.git", branch: "main"

  livecheck do
    url :stable
    regex(/^callisto@v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto-0.21.1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "4e014aac5d68709969e7c318cf5a65bf8c85d9c5f99d9e0b7f0c65f3648877bc"
    sha256 cellar: :any,                 arm64_linux:  "b680cf5bdf2ea050305dd1e1ced90600d24714f258738dfb3759e180281952bf"
    sha256 cellar: :any,                 x86_64_linux: "f77366c20d8ea647b175130992ccb490f63edd15b897460f732fe00ac7118f28"
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
