class Caliper < Formula
  desc "Fast React prop extraction for Storybook and component docs"
  homepage "https://orin-dx.com/tools/caliper/"
  license "FSL-1.1-MIT"

  on_macos do
    on_arm do
      url "https://registry.npmjs.org/caliper-docgen-darwin-arm64/-/caliper-docgen-darwin-arm64-0.5.0.tgz"
      sha256 "e4905fdd3a98abe96845b74abd8c6ba61682db9a95a8419cb212e91bcaf146fd"
    end

    on_intel do
      url "https://registry.npmjs.org/caliper-docgen-darwin-x64/-/caliper-docgen-darwin-x64-0.5.0.tgz"
      sha256 "c167213a83e912897dc98ad0b929055365f7c21c1a679b9e84db35e4cfcd2d2f"
    end
  end

  on_linux do
    on_arm do
      url "https://registry.npmjs.org/caliper-docgen-linux-arm64-gnu/-/caliper-docgen-linux-arm64-gnu-0.5.0.tgz"
      sha256 "9c6741cbe3177ce80d54d0363f918c237985888caa79ebe53af6f9b8cda35b65"
    end

    on_intel do
      url "https://registry.npmjs.org/caliper-docgen-linux-x64-gnu/-/caliper-docgen-linux-x64-gnu-0.5.0.tgz"
      sha256 "28ee22beea046251d0d80fcadd8e7748eeea38fb498bbbd5e39abc03a31e9506"
    end
  end

  def install
    bin.install "package/caliper-docgen"
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
