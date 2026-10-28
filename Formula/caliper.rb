class Caliper < Formula
  desc "Fast React prop extraction for Storybook and component docs"
  homepage "https://orin-dx.com/tools/caliper/"
  url "https://github.com/orin-dx/caliper/archive/refs/tags/npm/caliper-docgen@0.7.0.tar.gz"
  sha256 "785a7951d5de24e29c2b61e637750033df4439fd1b9c234c3927730c385727fe"
  license "FSL-1.1-MIT"
  head "https://github.com/orin-dx/caliper.git", branch: "main"

  livecheck do
    url :stable
    regex(%r{^npm/caliper-docgen@v?(\d+(?:\.\d+)+)$}i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/caliper-0.7.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "750c223cefb9ddf88b3b412683a63fd49981c330fa5b91d801c5a58a82333e4c"
    sha256 cellar: :any,                 arm64_linux:  "36b9eca8bfb219cf55f9970b1a6570af1e270f24e58dc278de24097bfa870f66"
    sha256 cellar: :any,                 x86_64_linux: "a707a8c31567168fa815c7baa16f9b21fd127dd2b00f7bf40989596981a1f338"
  end

  depends_on "rust" => :build

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
