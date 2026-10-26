# How tap updates work

The tap follows published CLI releases. It does not decide when Callisto or Caliper publishes, and a release workflow does not write a formula directly.

## The path from release to PR

1. A trusted release workflow sends `tool_released` with a tool name and tag. The tap also checks for new stable versions every day, so a missed event does not strand a release.
2. [`scripts/update_formula.py`](../scripts/update_formula.py) reads the tool's committed manifest. It fetches publisher metadata and every platform archive, verifies the published digest, checks archive contents and executable mode, then writes four SHA-256 values to the formula.
3. The tap creates a short-lived GitHub App token scoped to this repository and opens a branch and PR. It does not overwrite an existing update branch or downgrade a formula.
4. **Required tap checks** runs updater tests, then audits, installs, and exercises the changed formula on macOS ARM/Intel and Linux ARM/x86-64. Shared updater changes and a weekly run check every formula. A maintainer reviews and approves the PR, including any new runtime library or minimum OS requirements.

The event cannot choose a download URL or checksum. Both come from the manifest on `main` and the publisher's versioned release. The SHA-256 in a merged formula is the digest Homebrew checks on every later install.

## One-time GitHub setup

### Create the App

Create an organization-owned GitHub App called something like `orin-dx-homebrew-updater`. Disable its webhook. Give it only **Contents: read and write** and **Pull requests: read and write**, then install it on **only `orin-dx/homebrew-tap`**. The notification needs Contents write for GitHub's `repository_dispatch` endpoint; the tap also needs Pull requests write to open the review PR.

Generate one private key and record the App's client ID. Keep the PEM out of Git and terminal output. Store them as an organization Actions variable and secret, each visible only to `homebrew-tap`, `callisto`, and `caliper`:

```sh
gh variable set TAP_APP_CLIENT_ID --org orin-dx --repos homebrew-tap,callisto,caliper
gh secret set TAP_APP_PRIVATE_KEY --org orin-dx --repos homebrew-tap,callisto,caliper < path/to/downloaded-key.pem
```

The variable command prompts for the client ID. The secret command reads the PEM from stdin; delete the downloaded file after storing it. Add Firkin to the selected repositories only when its release notifier exists. The App never needs access to the source repositories themselves.

### Protect `main`

After the first tap commit lands, add a repository ruleset for `main`: require a PR, one approval, dismiss stale approvals after new pushes, and require **Required tap checks**. Do not give the App a bypass. The sole maintainer can use an admin PR-only bypass for human-authored maintenance; bot formula PRs still need that maintainer's approval. Leave automatic merge off.

The tap workflow's default `GITHUB_TOKEN` is read-only. Its App token is minted only after all archives pass verification and only for `homebrew-tap`. Source repositories use the same shared [notification action](https://github.com/orin-dx/actions/tree/main/notify-homebrew-tap) after a successful release, with their receipt proving a CLI was published. They have no formula-editing code.

## Run or recover an update

Run **Update formula** in the tap's Actions tab or use the CLI:

```sh
gh workflow run update-formula.yml -R orin-dx/homebrew-tap -f tool=caliper
gh workflow run update-formula.yml -R orin-dx/homebrew-tap -f tool=callisto -f tag=callisto@0.14.2
```

Without App credentials, verification still runs but the workflow cannot open a changed-formula PR. You can run the updater locally and submit a human PR instead. If an update branch already exists, inspect its PR and branch before retrying; the workflow refuses to force-push over it. To rotate the App key, replace `TAP_APP_PRIVATE_KEY` in the selected organization secret and revoke the old key in the App's settings.

See [Contributing](../CONTRIBUTING.md) for formula changes and [Security](../SECURITY.md) for private reporting.
