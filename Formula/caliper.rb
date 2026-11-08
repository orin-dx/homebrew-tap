class Caliper < Formula
  desc "Fast React prop extraction for Storybook and component docs"
  homepage "https://orin-dx.com/tools/caliper/"
  url "https://github.com/orin-dx/caliper/archive/refs/tags/npm/caliper-docgen@0.10.0.tar.gz"
  sha256 "2a3e0ffbedd495ebf0055e9b78dd8f6fd4f378c8d1eb243f32dfc54539ee7a91"
  license "FSL-1.1-MIT"
  head "https://github.com/orin-dx/caliper.git", branch: "main"

  livecheck do
    url :stable
    regex(%r{^npm/caliper-docgen@v?(\d+(?:\.\d+)+)$}i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/caliper-0.10.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "55034b0d7c2b7f07d0cca1f85bac643155bc7f368105d5ca2fcc981e9ee4c660"
    sha256 cellar: :any,                 arm64_linux:  "cd82cd0508f5dd6377b618658225454b45711f7ab06377c8e566830db5621cad"
    sha256 cellar: :any,                 x86_64_linux: "b0f49f759cdf1b861e3736cdb4bdf3a2bdc15fba34dabfde11bd91420676637d"
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
