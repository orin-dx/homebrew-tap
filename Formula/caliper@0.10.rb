class CaliperAT010 < Formula
  desc "Fast React prop extraction for Storybook and component docs"
  homepage "https://orin-dx.com/tools/caliper/"
  url "https://github.com/orin-dx/caliper/archive/refs/tags/npm/caliper-docgen@0.10.0.tar.gz"
  sha256 "2a3e0ffbedd495ebf0055e9b78dd8f6fd4f378c8d1eb243f32dfc54539ee7a91"
  license "FSL-1.1-MIT"

  livecheck do
    url :stable
    regex(%r{^npm/caliper-docgen@v?(0\.10\.\d+)$}i)
  end

  bottle do
    root_url "https://github.com/orin-dx/homebrew-tap/releases/download/caliper@0.10-0.10.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "1741c9e44c44cc8c9976cd78a57f5edfe866034213d117be74297b11e728c855"
    sha256 cellar: :any,                 arm64_linux:  "13553b3633576e3a3086462b9d0c56079208b979e7a489405a6babf95abf65e7"
    sha256 cellar: :any,                 x86_64_linux: "d37011b81ee0a8739345207dbb5ab8f7b3dcee55aa3f5a68c0ac5ba21525d555"
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
