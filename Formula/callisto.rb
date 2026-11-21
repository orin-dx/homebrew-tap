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
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/callisto-0.22.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "65619be35680f769b75e81080ea1bf0d7e647018bdb21382c900b7de8d2669e7"
    sha256 cellar: :any,                 arm64_linux:  "990609d643c2d7beecbdb37d972f1d78fa12bb6c48373a6cb3403af72969db14"
    sha256 cellar: :any,                 x86_64_linux: "c710a3b5ff048d52716b320e81ca5528d02624e29deb7753fa48832dbcd54ab4"
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
