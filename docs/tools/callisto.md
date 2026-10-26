# Callisto with Homebrew

[← All tools](../../README.md) · [Callisto project](https://github.com/orin-dx/callisto)

Callisto helps a workspace decide what to version, records the reason for each change, then coordinates releases through the package registries you already use. The tap installs its published CLI binary as `callisto`.

```sh
brew install orin-dx/tap/callisto
callisto --version
```

Homebrew also installs Bash, zsh, and fish completions. If suggestions do not appear, check [Homebrew's shell completion setup](https://docs.brew.sh/Shell-Completion).

## See a version plan

Start in a Git workspace that has a package to release. This example creates Callisto's config and changeset directory, records one pending change, and shows the plan:

```sh
callisto init --yes --versioning independent --no-workflow
callisto add --package cargo/my-crate:minor --summary "Add authentication middleware"
callisto status
```

Replace `cargo/my-crate` with your package. `init` writes files in the current repository; review and commit those files as part of your normal workflow. `status` does not publish anything. Before publishing, follow [Callisto's complete quick start](https://github.com/orin-dx/callisto#quick-start) and [release guide](https://github.com/orin-dx/callisto/blob/main/docs/releasing.md) for registry credentials, version commits, and dry runs.

## Where this binary comes from

The formula downloads Callisto's versioned archives from [GitHub Releases](https://github.com/orin-dx/callisto/releases). The tap verifies the publisher's digest and archive contents before it opens a formula PR; Homebrew checks the pinned SHA-256 when you install. See [how tap updates work](../automation.md) for the full path.

For another installation channel, Callisto also documents [proto and Cargo installs](https://github.com/orin-dx/callisto#install). Report install or checksum trouble [in this tap](https://github.com/orin-dx/homebrew-tap/issues/new); report CLI behavior [in Callisto](https://github.com/orin-dx/callisto/issues).
