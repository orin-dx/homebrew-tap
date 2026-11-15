class Caliper < Formula
  desc "Fast React prop extraction for Storybook and component docs"
  homepage "https://orin-dx.com/tools/caliper/"
  url "https://github.com/orin-dx/caliper/archive/refs/tags/npm/caliper-docgen@0.11.0.tar.gz"
  sha256 "082b07b9b7a2aa64dbbec13c8213354bf0e572ec64924e4fccffe4ddff11b98a"
  license "FSL-1.1-MIT"
  head "https://github.com/orin-dx/caliper.git", branch: "main"

  livecheck do
    url :stable
    regex(%r{^npm/caliper-docgen@v?(\d+(?:\.\d+)+)$}i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/caliper-0.11.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "80da5954c58a7744c4e1a0a5f646440eb232be13c41e28581d00f6f12067d4e3"
    sha256 cellar: :any,                 arm64_linux:  "a02c0bf44bb5e5654375ed463e6219cb2bb888ac58d8585f193747ba72dadca8"
    sha256 cellar: :any,                 x86_64_linux: "9b6e2f10a4bc973165fef41861fac3d90ad6d62c5e2f2c8ff9e55d84c9a60906"
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
