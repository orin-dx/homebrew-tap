class Caliper < Formula
  desc "Fast React prop extraction for Storybook and component docs"
  homepage "https://orin-dx.com/tools/caliper/"
  url "https://github.com/orin-dx/caliper/archive/refs/tags/npm/caliper-docgen@0.8.0.tar.gz"
  sha256 "50e37f454b8c5609e8b0cab55bb86649b27a1b6b37cd8e875faf35e5bf71b2db"
  license "FSL-1.1-MIT"
  head "https://github.com/orin-dx/caliper.git", branch: "main"

  livecheck do
    url :stable
    regex(%r{^npm/caliper-docgen@v?(\d+(?:\.\d+)+)$}i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/caliper-0.7.0"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "5352752bf1ed6884e01be9dea8dfc180e7d30a4bea2e4327b1a14e5e4d9f5ba4"
    sha256 cellar: :any,                 arm64_linux:  "bd3ffa9856e4ec80190396ab5bf4c86a4a36b04d246e54e4d2df6403f8bba698"
    sha256 cellar: :any,                 x86_64_linux: "39af67fc8e9d750c4f639a578733ecfeb3fe3e4c2162f633f5b4ea2696dad8d8"
  end

  depends_on "rust" => :build

  on_macos do
    on_intel do
      disable! date:    "2026-10-27",
               because: "Intel Macs are not supported (Homebrew has no Intel macOS bottles for Rust)"
    end
  end

  def install
    system "cargo", "install", *std_cargo_args(path: "crates/cli")
    generate_completions_from_executable(bin/"caliper-docgen", "completions")
  end

  test do
    assert_match "caliper-docgen #{version}", shell_output("#{bin}/caliper-docgen --version")
    assert_path_exists bash_completion/"caliper-docgen"
    assert_path_exists zsh_completion/"_caliper-docgen"
    assert_path_exists fish_completion/"caliper-docgen.fish"
    (testpath/"src").mkpath
    (testpath/"src/Button.tsx").write <<~TSX
      export interface ButtonProps {
        /** Text shown on the button. */
        label: string
      }
      export function Button(props: ButtonProps) { return null }
    TSX
    output = shell_output("#{bin}/caliper-docgen inspect Button --src src")
    assert_match "Button", output
    assert_match "label", output
    assert_match "string", output
  end
end
