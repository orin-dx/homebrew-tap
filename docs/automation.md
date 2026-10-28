# How tap updates work

The tap follows tagged releases. It does not decide when Callisto or Caliper publishes, and a release workflow does not write a formula directly. The three workflows are the ones `brew tap-new` generates, with a few additions noted below.

## The path from release to bottles

1. **Detect.** The **brew bump** workflow (`autobump.yml`) runs daily, or on demand. It runs `brew bump --open-pr`, which asks each formula's `livecheck` block for the newest stable tag and opens a PR that changes the source `url` and `sha256`. Versioned formulae such as `callisto@0.15` follow patch releases of their own line only, because their `livecheck` regex is pinned to it. The source repositories need no tap-specific workflow or secret.
2. **Test.** **brew test-bot** (`tests.yml`) styles and audits the tap, then builds, tests, and bottles each changed formula on macOS ARM and Linux ARM and x86-64. Intel macOS is unsupported: Homebrew publishes no Intel bottles, so `rust` cannot be installed there without a source build, and the formulae use `disable!` to stop with a clear message. Bottles are uploaded as workflow artifacts.
3. **Review.** A maintainer reads the PR, including any new build or runtime requirements, and approves it once the test-bot jobs pass.
4. **Publish.** When the PR merges, **brew pr-pull** (`publish.yml`) runs on its own. It runs `brew pr-pull --no-cherry-pick`, which downloads the bottles built for that PR, uploads them, and adds the `bottle do` block to the formula. Because the PR is already merged, the workflow passes brew the commit the PR merged onto, so brew can tell which formulae changed, and runs with `--clean` so it never amends a commit already on `main`. It then attests build provenance and pushes the bottle commit to `main`. Only merged PRs from this repository that change `Formula/` trigger it, and it runs the base branch's workflow code, so a PR cannot alter what runs with the App token.

The URL comes from the formula and the tag from `livecheck`; `brew bump` computes the checksum itself.

## One-time GitHub setup

### Create the App

Pull requests opened with the default `GITHUB_TOKEN` do not trigger other workflows, so the bump workflow uses a short-lived GitHub App token instead. The publish workflow uses the same App to push the bottle commit to `main`. Create an organization-owned GitHub App called something like `orin-dx-homebrew-updater`. Disable its webhook. Give it only **Contents: read and write** and **Pull requests: read and write**, then install it on **only `orin-dx/homebrew-tap`**.

Generate one private key and record the App's client ID. Keep the PEM out of Git and terminal output. Store them as an Actions variable and secret that only `homebrew-tap` can read. Repository-level is simplest:

```sh
gh variable set TAP_APP_CLIENT_ID -R orin-dx/homebrew-tap
gh secret set TAP_APP_PRIVATE_KEY -R orin-dx/homebrew-tap < path/to/downloaded-key.pem
```

An organization-level variable and secret work too if their repository access is limited to `homebrew-tap`; this tap uses that form. The variable command prompts for the client ID. The secret command reads the PEM from stdin; delete the downloaded file after storing it. No other repository needs the key, and because the App bypasses the `main` ruleset, no other repository should be able to read it.

### Protect `main`

Add a repository ruleset for `main`: require a PR, one approval, dismiss stale approvals after new pushes, and require the three **brew test-bot** jobs: `macOS ARM`, `Linux x86-64`, and `Linux ARM`. Add the App to the ruleset's bypass list with **Always allow**. That bypass is how the publish workflow pushes the bottle commit, which Homebrew's bottle model needs on `main` after the PR merges. It is the only direct write to `main`; the App's token is minted only in the bump and publish workflows, and the publish workflow runs only for merged PRs from this repository. Repository admins and the maintainer account are also on the bypass list for human-authored maintenance. Leave automatic merge off.

### Bottle storage

Bottles are stored as assets on GitHub Releases in this repository, one release per formula version (for example `caliper-0.7.0`). `test-bot` writes that `root_url` into each bottle, and `brew pr-upload` creates the release and uploads the assets with the App token's Contents write permission. No package permissions are needed.

## Run or recover an update

Run **brew bump** from the tap's Actions tab, or use the CLI:

```sh
gh workflow run autobump.yml -R orin-dx/homebrew-tap
gh workflow run publish.yml -R orin-dx/homebrew-tap -f pull_request=<number>
```

Publishing runs on merge. The second command re-runs it for an already merged PR whose publish run failed; the PR's test-bot artifacts must still exist (GitHub keeps them for 90 days by default). If a bump PR already exists for a version, `brew bump` skips it. To rotate the App key, replace `TAP_APP_PRIVATE_KEY` wherever it is stored and revoke the old key in the App's settings.

See [Contributing](../CONTRIBUTING.md) for formula changes and [Security](../SECURITY.md) for private reporting.
