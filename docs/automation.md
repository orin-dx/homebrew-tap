# How tap updates work

The tap follows tagged releases. It does not decide when Callisto or Caliper publishes, and a release workflow does not write a formula directly. The three workflows are the ones `brew tap-new` generates, with a few additions noted below.

## The path from release to bottles

1. **Detect.** The **brew bump** workflow (`autobump.yml`) runs daily, or on demand. It runs `brew bump --open-pr`, which asks each formula's `livecheck` block for the newest stable tag and opens a PR that changes the source `url` and `sha256`. The source repositories need no tap-specific workflow or secret.
2. **Test.** **brew test-bot** (`tests.yml`) styles and audits the tap, then builds, tests, and bottles each changed formula on macOS ARM and Intel and Linux ARM and x86-64. Bottles are uploaded as workflow artifacts.
3. **Review.** A maintainer reads the PR, including any new build or runtime requirements, and approves it once the test-bot jobs pass.
4. **Publish.** The maintainer runs **brew pr-pull** (`publish.yml`) with the PR number. It uploads the bottles, adds the `bottle do` block to the formula, attests build provenance, and pushes to `main`.

The URL comes from the formula and the tag from `livecheck`; `brew bump` computes the checksum itself.

## One-time GitHub setup

### Create the App

Pull requests opened with the default `GITHUB_TOKEN` do not trigger other workflows, so the bump workflow uses a short-lived GitHub App token instead. Create an organization-owned GitHub App called something like `orin-dx-homebrew-updater`. Disable its webhook. Give it only **Contents: read and write** and **Pull requests: read and write**, then install it on **only `orin-dx/homebrew-tap`**.

Generate one private key and record the App's client ID. Keep the PEM out of Git and terminal output. Store them as a repository Actions variable and secret on `homebrew-tap` only:

```sh
gh variable set TAP_APP_CLIENT_ID -R orin-dx/homebrew-tap
gh secret set TAP_APP_PRIVATE_KEY -R orin-dx/homebrew-tap < path/to/downloaded-key.pem
```

The variable command prompts for the client ID. The secret command reads the PEM from stdin; delete the downloaded file after storing it. No other repository needs the key.

### Protect `main`

Add a repository ruleset for `main`: require a PR, one approval, dismiss stale approvals after new pushes, and require the four **brew test-bot** jobs: `macOS ARM`, `macOS Intel`, `Linux x86-64`, and `Linux ARM`. Do not give the App a bypass. The sole maintainer can use an admin PR-only bypass for human-authored maintenance. Leave automatic merge off. The publish workflow pushes bottle commits to `main`, so its actor needs to be allowed by the ruleset.

### Bottle storage

`brew pr-pull` uploads bottles to GitHub Packages for this repository by default. If the first publish run fails on package permissions, grant the workflow package write access or use a release-asset `root_url`. This has not been exercised yet.

## Run or recover an update

Run **brew bump** from the tap's Actions tab, or use the CLI:

```sh
gh workflow run autobump.yml -R orin-dx/homebrew-tap
gh workflow run publish.yml -R orin-dx/homebrew-tap -f pull_request=<number>
```

If a bump PR already exists for a version, `brew bump` skips it. To rotate the App key, replace `TAP_APP_PRIVATE_KEY` in the selected organization secret and revoke the old key in the App's settings.

See [Contributing](../CONTRIBUTING.md) for formula changes and [Security](../SECURITY.md) for private reporting.
