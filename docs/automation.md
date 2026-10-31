# How tap updates work

The tap follows tagged releases. It does not decide when Callisto or Caliper publishes, and a release workflow does not write a formula directly. The three workflows are the ones `brew tap-new` generates, with a few additions noted below.

## The path from release to bottles

1. **Detect.** The **brew bump** workflow (`autobump.yml`) runs daily, or on demand. It runs `brew bump --open-pr`, which asks each formula's `livecheck` block for the newest stable tag and opens a PR that changes the source `url` and `sha256`. Versioned formulae such as `callisto@0.15` follow patch releases of their own line only, because their `livecheck` regex is pinned to it. Before it bumps, the workflow checks whether a tool is crossing into a new breaking line (a new minor before 1.0, a new major after). If so, and no `tool@line` formula exists yet, it opens a snapshot PR that keeps the old line installable. The source repositories need no tap-specific workflow or secret.
2. **Test.** **brew test-bot** (`tests.yml`) styles and audits the tap, then builds, tests, and bottles each changed formula on macOS ARM and Linux ARM and x86-64. A final step fails the job if a changed formula produced no bottle, because test-bot can skip a formula and still pass. Intel macOS is unsupported: Homebrew publishes no Intel bottles, so `rust` cannot be installed there without a source build, and the formulae use `disable!` to stop with a clear message. Bottles are uploaded as workflow artifacts.
3. **Merge.** The release was already reviewed in the parent repository, so the updater App's PRs do not wait for a second approval. The **merge release bumps** workflow (`automerge.yml`) merges one when the three platform checks passed on its head commit and every guard in `.github/scripts/tap_automation.py` holds: the PR comes from the App on a branch in this repository, it changes only `Formula/*.rb`, only the source `url` and `sha256` change (or it adds the exact snapshot the script generates), the URL stays in the same upstream repository, the version goes up, and a bump into a new line waits until the old line's formula is on `main`. A PR that fails a guard stays open for a human to review. The workflow runs after test-bot, after every push to `main` (a merged snapshot unblocks its bump), and every six hours. If a PR sits unmerged for a day, it opens an issue. Human-authored and Dependabot PRs still need a maintainer's review.
4. **Publish.** When the PR merges, **brew pr-pull** (`publish.yml`) runs on its own. It runs `brew pr-pull --no-cherry-pick`, which downloads the bottles built for that PR, uploads them, and adds the `bottle do` block to the formula. Because the PR is already merged, the workflow passes brew the commit the PR merged onto, so brew can tell which formulae changed, and runs with `--clean` so it never amends a commit already on `main`. It then attests build provenance and pushes the bottle commit to `main`. If the upload fails only because the release already has those assets, as when a retired line's formula is restored with its published bottles, it warns and publishes nothing; `main`'s bottle block still points at the released assets, and the install check below fails if they are not usable. Only merged PRs from this repository that change `Formula/` trigger it, and it runs the base branch's workflow code, so a PR cannot alter what runs with the App token. Afterwards it installs each published formula on macOS ARM and Linux ARM and x86-64 and fails unless Homebrew pours a bottle. If publishing or that check fails, it opens an issue.

The URL comes from the formula and the tag from `livecheck`; `brew bump` computes the checksum itself.

## One-time GitHub setup

### Create the App

Pull requests opened with the default `GITHUB_TOKEN` do not trigger other workflows, so the bump workflow uses a short-lived GitHub App token instead. The publish workflow uses the same App to push the bottle commit to `main`, and the merge workflow uses it to merge the App's own PRs. Create an organization-owned GitHub App called something like `orin-dx-homebrew-updater`. Disable its webhook. Give it only **Contents: read and write** and **Pull requests: read and write**, then install it on **only `orin-dx/homebrew-tap`**.

Generate one private key and record the App's client ID. Keep the PEM out of Git and terminal output. Store them as an Actions variable and secret that only `homebrew-tap` can read. Repository-level is simplest:

```sh
gh variable set TAP_APP_CLIENT_ID -R orin-dx/homebrew-tap
gh secret set TAP_APP_PRIVATE_KEY -R orin-dx/homebrew-tap < path/to/downloaded-key.pem
```

An organization-level variable and secret work too if their repository access is limited to `homebrew-tap`; this tap uses that form. The variable command prompts for the client ID. The secret command reads the PEM from stdin; delete the downloaded file after storing it. No other repository needs the key, and because the App bypasses the `main` ruleset, no other repository should be able to read it.

### Protect `main`

Add a repository ruleset for `main`: require a PR, one approval, dismiss stale approvals after new pushes, and require the three **brew test-bot** jobs: `macOS ARM`, `Linux x86-64`, and `Linux ARM`. Add the App to the ruleset's bypass list with **Always allow**. That bypass is how the publish workflow pushes the bottle commit, which Homebrew's bottle model needs on `main` after the PR merges, and how the merge workflow merges the App's PRs without a second approval. The bypass also skips the required checks, so the merge workflow waits for them itself and refuses to merge anything that fails its guards. The App's token is minted only in the bump, merge, and publish workflows, and the publish workflow runs only for merged PRs from this repository. Repository admins and the maintainer account are also on the bypass list for human-authored maintenance. Leave automatic merge off.

### Bottle storage

Bottles are stored as assets on GitHub Releases in this repository, one release per formula version (for example `caliper-0.7.0`). `test-bot` writes that `root_url` into each bottle, and `brew pr-upload` creates the release and uploads the assets with the App token's Contents write permission. No package permissions are needed.

## Run or recover an update

Run **brew bump** from the tap's Actions tab, or use the CLI:

```sh
gh workflow run autobump.yml -R orin-dx/homebrew-tap
gh workflow run automerge.yml -R orin-dx/homebrew-tap
gh workflow run publish.yml -R orin-dx/homebrew-tap -f pull_request=<number>
```

Merging and publishing run on their own. The second command checks the App's open PRs again; its log says why each one is waiting or was skipped, which is the first place to look when a bump PR does not merge. The third command re-runs it for an already merged PR whose publish run failed; the PR's test-bot artifacts must still exist (GitHub keeps them for 90 days by default). If a bump PR already exists for a version, `brew bump` skips it. To rotate the App key, replace `TAP_APP_PRIVATE_KEY` wherever it is stored and revoke the old key in the App's settings.

See [Contributing](../CONTRIBUTING.md) for formula changes and [Security](../SECURITY.md) for private reporting.
