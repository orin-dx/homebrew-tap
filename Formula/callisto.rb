class Callisto < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  license "FSL-1.1-MIT"

  on_macos do
    on_arm do
      url "https://github.com/orin-dx/callisto/releases/download/callisto%400.15.0/callisto-aarch64-apple-darwin.tar.gz"
      sha256 "dc8ceb79d2c2c5136d2231c451628bc6002c438ea644be8625057aa9fcb1ffd2"
    end

    on_intel do
      version "0.15.0"
      url "https://github.com/orin-dx/callisto/releases/download/callisto%400.15.0/callisto-x86_64-apple-darwin.tar.gz"
      sha256 "a31238c4d8289e4ef7f09415c0cd4d2ce25f052a67bf23abfe845c69b6718d01"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/orin-dx/callisto/releases/download/callisto%400.15.0/callisto-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "8b42beb3225455b98c7d270f5a4123a3275dfcfeea72a5e424f93e0400ed0578"
    end

    on_intel do
      version "0.15.0"
      url "https://github.com/orin-dx/callisto/releases/download/callisto%400.15.0/callisto-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "a5e6862aa33e8829d489f4811efe62dd45491792a4a67f029b8df4d641e35e3e"
    end
  end

  def install
    bin.install "callisto"
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
