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
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/caliper-0.8.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "4348271a30e36c8983f9ad2d536db272dbfb3013d59b56ea05e9c8bbaab652ae"
    sha256 cellar: :any,                 arm64_linux:  "e014a97e59f1a87ee225b0419336516ef2d4f55d86b45f3a6a5158dc33c4f824"
    sha256 cellar: :any,                 x86_64_linux: "354763ab30bc484d4c6303607413bf2370f96e3c46e9891a643e3cea60c980be"
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
