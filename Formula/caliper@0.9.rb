class CaliperAT09 < Formula
  desc "Fast React prop extraction for Storybook and component docs"
  homepage "https://orin-dx.com/tools/caliper/"
  url "https://github.com/orin-dx/caliper/archive/refs/tags/npm/caliper-docgen@0.9.0.tar.gz"
  sha256 "5e5c520ca60a6d860afd9d942b7224d6583d3b349989686588db4b7059889762"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(%r{^npm/caliper-docgen@v?(0\.9\.\d+)$}i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/caliper@0.9-0.9.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "705f623921d6e7d52947d6f782ee7ae881266d546631403c3290f71a92a4a44a"
    sha256 cellar: :any,                 arm64_linux:  "8bbb72dfbddbd94e85c7a4aad9152130a05ca6726b0921d48ea09a8ac3811e03"
    sha256 cellar: :any,                 x86_64_linux: "9115d6e4080ef110af15078c0d6f5dba088c1a7f2943603dba97aa5485508106"
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
