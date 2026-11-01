class CaliperAT07 < Formula
  desc "Fast React prop extraction for Storybook and component docs"
  homepage "https://orin-dx.com/tools/caliper/"
  url "https://github.com/orin-dx/caliper/archive/refs/tags/npm/caliper-docgen@0.7.0.tar.gz"
  sha256 "785a7951d5de24e29c2b61e637750033df4439fd1b9c234c3927730c385727fe"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(%r{^npm/caliper-docgen@v?(0\.7\.\d+)$}i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/caliper@0.7-0.7.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "c8a6d4b5ee48cc20109c15a307298031f632765712412007d9c0ef4dda4ab000"
    sha256 cellar: :any,                 arm64_linux:  "687b6f4d2082e8e71bf040dc6bbf7bd505ebc08bde116d976e1a4c0adf9fe3bc"
    sha256 cellar: :any,                 x86_64_linux: "19432aee6ae73c195f1da2e2001d705e949ebe73fbdb8bc23032d83357c58b75"
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
