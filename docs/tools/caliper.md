# Caliper with Homebrew

[← All tools](../../README.md) · [Caliper project](https://github.com/orin-dx/caliper)

Caliper reads React component source and reports props, defaults, and descriptions without building a full TypeScript program. The tap installs the standalone CLI as `caliper-docgen`.

```sh
brew install orin-dx/tap/caliper
caliper-docgen --version
```

Homebrew also installs Bash, zsh, and fish completions. If suggestions do not appear, check [Homebrew's shell completion setup](https://docs.brew.sh/Shell-Completion).

## Inspect your first component

Run these in a React project. Replace `Button` and `src` with your component name and source directory:

```sh
caliper-docgen inspect Button --src src
caliper-docgen extract --src src --out docgen.json
caliper-docgen check --src src
```

`inspect` shows one component as a table, `extract` writes the project result, and `check` fails CI on extraction errors. [Caliper's quick start](https://github.com/orin-dx/caliper#quick-start) covers watch mode, configuration, and loading types from installed packages.

## Storybook and Vite are project packages

The Homebrew formula gives you the CLI. For Storybook 11, add the [Storybook addon](https://github.com/orin-dx/caliper/tree/main/packages/storybook) to your project from npm. For Vite or Storybook 10, use the [Vite plugin](https://github.com/orin-dx/caliper/tree/main/packages/vite-plugin). Installing the CLI with Homebrew does not configure either integration. The [Caliper project README](https://github.com/orin-dx/caliper#storybook) has the current setup examples and supported behavior.

The experimental TypeScript 7.1 beta checker in Caliper's source is a CLI `extract` opt-in, not part of the Storybook addon or Vite plugin path. Published formulas can lag source work: check `caliper-docgen extract --help` for the flag in your installed version. The opt-in needs a compatible TypeScript beta in your project. See [Caliper's checker integration notes](https://github.com/orin-dx/caliper/blob/main/docs/type-checker-integration.md) for its scope and limits.

## Where this binary comes from

The formula downloads Caliper's platform packages from npm. The tap checks npm's integrity digest and the archive contents before it opens a formula PR; Homebrew checks the pinned SHA-256 when you install. See [how tap updates work](../automation.md) for the full path.

Report install or checksum trouble [in this tap](https://github.com/orin-dx/homebrew-tap/issues/new); report extraction or integration behavior [in Caliper](https://github.com/orin-dx/caliper/issues).
