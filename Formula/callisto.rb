class Callisto < Formula
  desc "Dependency-aware versioning and releases for Cargo, npm, and PyPI workspaces"
  homepage "https://github.com/orin-dx/callisto"
  license "FSL-1.1-MIT"
  version "0.14.2"

  on_macos do
    on_arm do
      url "https://github.com/orin-dx/callisto/releases/download/callisto%400.14.2/callisto-aarch64-apple-darwin.tar.gz"
      sha256 "216b8b4fca2a6c4c8c66fa9e9a41887fd6b91d129783571111d701132a09a239"
    end

    on_intel do
      url "https://github.com/orin-dx/callisto/releases/download/callisto%400.14.2/callisto-x86_64-apple-darwin.tar.gz"
      sha256 "98188525eed1480bb7efb30ea144aaa7b89dad1da24e76c522f168ce8d7a2373"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/orin-dx/callisto/releases/download/callisto%400.14.2/callisto-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "91870b95e5386e19e078d408ea130dfeba39705cd815429aa67b34c71ed1af7b"
    end

    on_intel do
      url "https://github.com/orin-dx/callisto/releases/download/callisto%400.14.2/callisto-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "fa4c91c45135347a8492ff73c0c325b2a6fb6da5a6d02f85427e08a2953d1300"
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
