<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/brand/hero-dark.png">
    <img src="assets/brand/hero-light.png" alt="Orin DX Homebrew tap" width="240">
  </picture>
</p>

<h1 align="center">Contributing</h1>

Thanks for helping make these tools easy to install. A good formula change lets someone see exactly which release will run on each platform.

## Start with the right place

| You found… | Go to… |
| --- | --- |
| An install failure, wrong archive, or bad checksum | [Open an issue in this tap](https://github.com/orin-dx/homebrew-tap/issues/new) or send a formula PR. |
| A bug in a tool after it starts | [Callisto](https://github.com/orin-dx/callisto/issues) or [Caliper](https://github.com/orin-dx/caliper/issues). |
| A way to compromise installs, release updates, or credentials | [Report it privately](SECURITY.md). |

## Update an existing formula

The updater reads [`tools/callisto.json`](tools/callisto.json) or [`tools/caliper.json`](tools/caliper.json), checks each published archive, and edits the matching formula. Run it from the repository root:

The scripts use only Python's standard library and require Python 3.9 or newer.

```sh
python3 scripts/update_formula.py --tool callisto --latest
python3 scripts/update_formula.py --tool caliper --latest
```

For a specific published release, use `--tag callisto@0.14.2` or `--tag npm/caliper-docgen@0.5.0` with the version you mean to package. The updater refuses a downgrade and leaves the formula alone if verification fails.

Read the diff before opening a PR. The four URLs should point to one version, and every SHA-256 should match the archive it names. Check the binaries' linked libraries and minimum system versions when reviewing a new release; update the tool guide if its runtime requirements change. If a release changed its archive layout, update its manifest in the same PR and explain why.

### Check the change

```sh
python3 -m unittest discover -s scripts -p 'test_*.py'
brew audit --strict --online --formula orin-dx/tap/<tool>
brew install orin-dx/tap/<tool>
brew test orin-dx/tap/<tool>
```

Run the Homebrew commands from a checkout installed as the `orin-dx/tap` tap; `brew --repository orin-dx/tap` shows that checkout. Homebrew may ask you to trust the formula before loading it. Read its Ruby first. The PR workflow repeats the audit, install, and smoke test on macOS and Linux, for both architectures.

In your PR, link the upstream release, name the platforms you checked locally, and call out anything the smoke test cannot establish. CI checks the changed formula on all four runners; shared updater changes and a weekly run check every formula. A local pass on one machine is not a claim that every target works.

## Add another tool

Start when the CLI has versioned, publicly downloadable archives for Apple Silicon and Intel macOS plus ARM64 and x86-64 GNU/Linux. Each archive needs a stable executable name and a published digest we can verify. The tool must have a license we can name in the formula.

1. Add `Formula/<tool>.rb` with one URL and SHA-256 per platform, a `test do` block that exercises a real CLI workflow, and the upstream license. Declare only Homebrew packages the binaries actually need; macOS system libraries and a Linux distribution's glibc are not Homebrew formula dependencies.
2. Add `tools/<tool>.json` with the URL template, publisher (`github-release` or `npm-platform`), expected archive members, and executable path. Use the existing manifests as examples.
3. Add one row to the [README tool list](README.md#pick-a-tool) and a short `docs/tools/<tool>.md` guide. Show the installed command, one useful first workflow, integration boundaries, and links to the project's full docs. Keep release and support details in the source project.
4. Run the updater tests and Homebrew audit, install, and test. CI discovers the new manifest and adds it to its platform matrix.
5. After the tap PR lands, have the tool's trusted release workflow call the [shared notification action](https://github.com/orin-dx/actions/tree/main/notify-homebrew-tap) with its tool name and published tag. The daily check also finds new releases.

The release event supplies a name and tag, never a URL or checksum. Keep that boundary when extending the updater. Don't add a remote shell installer or give secrets to pull-request jobs.

## Review and merge

Formula updates land by PR. A maintainer reviews the release and archive changes, waits for **Required tap checks**, and approves the update. The App can create a branch and PR; it cannot bypass the `main` ruleset or merge its own change. The [automation guide](docs/automation.md) explains the credentials and recovery path.
