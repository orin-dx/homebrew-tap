<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/brand/hero-dark.png">
    <img src="assets/brand/hero-light.png" alt="Orin DX Homebrew tap" width="240">
  </picture>
</p>

<h1 align="center">Contributing</h1>

Thanks for helping make these tools easy to install. A good formula change lets someone see exactly which release will be built and bottled on each platform.

## Start with the right place

| You found… | Go to… |
| --- | --- |
| An install failure, wrong version, or bad checksum | [Open an issue in this tap](https://github.com/orin-dx/homebrew-tap/issues/new) or send a formula PR. |
| A bug in a tool after it starts | [Callisto](https://github.com/orin-dx/callisto/issues) or [Caliper](https://github.com/orin-dx/caliper/issues). |
| A way to compromise installs, release updates, or credentials | [Report it privately](SECURITY.md). |

## Update an existing formula

Updates are normally automatic. The **brew bump** workflow runs `brew bump --open-pr`, which reads each formula's `livecheck` block and opens a PR when a new release is tagged. To do the same by hand:

```sh
brew livecheck --tap orin-dx/tap
brew bump-formula-pr --no-fork --url=<source tarball URL> orin-dx/tap/<tool>
```

Read the diff before approving. The source URL should point at the release tag, and `brew fetch` should reproduce the SHA-256. Check the upstream changelog for new build requirements.

### When a new minor version ships

Before merging a PR that moves a formula to a new minor version (for example `0.14.x` to `0.15.0`), keep the old line installable:

1. Copy `Formula/<tool>.rb` to `Formula/<tool>@<old minor>.rb`, such as `callisto@0.14.rb`.
2. Rename the class (`CallistoAT014`), add `keg_only :versioned_formula`, and pin its `livecheck` regex to the old minor (`/^callisto@v?(0\.14\.\d+)$/i`).
3. Delete the versioned formula for the line before it. The tap keeps only the previous minor line.

Do this in the same PR, or open it first. Homebrew bumps versioned formulae like any other.

### Check the change

```sh
brew style orin-dx/tap
brew audit --strict --online --formula orin-dx/tap/<tool>
brew install --build-from-source orin-dx/tap/<tool>
brew test orin-dx/tap/<tool>
```

Run these from a checkout installed as the `orin-dx/tap` tap; `brew --repository orin-dx/tap` shows that checkout. Homebrew may ask you to trust a formula before loading it. Read its Ruby first. The PR workflow runs `brew test-bot` on macOS ARM and on Linux ARM and x86-64, and uploads the bottles it builds as artifacts. Intel macOS is not tested or supported; the formulae disable themselves there.

In your PR, link the upstream release, name the platforms you checked locally, and call out anything the smoke test cannot establish. A local pass on one machine is not a claim that every target works.

## Add another tool

Start when the tool is open source with a tagged source release that builds with a stock toolchain from a committed lockfile, ideally with a `completions` subcommand. The tool must have a license we can name in the formula.

1. Add `Formula/<tool>.rb` with the source tarball URL and SHA-256, a `livecheck` block matching the tool's tag format, a build dependency, an `install` method, a `test do` block that exercises a real CLI workflow, and the upstream license. Copy `callisto.rb` as a starting point.
2. Run the checks above.
3. Add one row to the [README tool list](README.md#pick-a-tool) and a short `docs/tools/<tool>.md` guide. Show the installed command, one useful first workflow, integration boundaries, and links to the project's full docs. Keep release and support details in the source project.
The daily bump run picks up new releases on its own; the tool's repository needs no tap-specific workflow or secret. Don't add a remote shell installer or give secrets to pull-request jobs.

## Review and merge

Formula updates land by PR. A maintainer reviews the release and source change, waits for the four platform checks, approves the PR, and merges it with the normal merge button. The **brew pr-pull** workflow then publishes the bottles automatically: it downloads the PR's CI bottles, uploads them, and pushes a bottle commit to `main`. Until that run finishes, a few minutes at most, installs of the new version build from source. The App's workflows only open PRs and push that bottle commit, but because the App bypasses the `main` ruleset, changes to `.github/workflows/` deserve the same review as a formula change. The [automation guide](docs/automation.md) explains the credentials, the bypass, and the recovery path.
