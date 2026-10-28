<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/brand/hero-dark.png">
    <img src="assets/brand/hero-light.png" alt="Orin DX Homebrew tap" width="240">
  </picture>
</p>

<h1 align="center">Security policy</h1>

## Report privately

If an issue could affect someone's machine or the tap's release process, please don't open a public issue first. Use GitHub's **Report a vulnerability** option in this repository's Security tab, or email **security@orin-dx.com**.

Tell us which formula or workflow is affected, what an attacker could do, and how to reproduce it if you can. Please don't include live credentials. Expect an acknowledgment within five business days. We'll share progress during triage and credit you when a fix ships unless you'd prefer otherwise.

## What belongs here

This tap is executable packaging code. Homebrew evaluates a formula before installing its binary, so a compromised formula or update workflow can harm users even when the CLI itself is sound.

- **Install path:** a formula or bottle that runs unexpected code, installs the wrong binary, crosses an architecture boundary, or bypasses its pinned checksum.
- **Update path:** a forged release signal or tag that makes the bump workflow open a PR for an unexpected source URL; a workflow flaw that turns release data into code execution; a way to publish bottles that were not built by this tap's CI.
- **Credentials and review:** exposure of the GitHub App key or token, an untrusted PR reaching those credentials, or a way to make the App write to `main` outside the publish workflow's bottle commit.

If the bug is in Callisto's or Caliper's CLI rather than its packaging, report it to that project's security contact. If a published bottle or source tag itself looks compromised, report it here too so we can stop distributing it.

## What the checks cover

Formula URLs are versioned source tarballs and carry SHA-256 values. `brew bump` computes the checksum of the tarball it downloads; the tap does not compare it against a second published digest. CI builds the formula from source, runs `brew audit`, and runs the formula's tests on each macOS and Linux target, then produces the bottles. Bottles are published only by the `brew pr-pull` workflow, after a formula PR merges, with build provenance attestations. The GitHub App is installed only on this tap and is on the `main` ruleset's bypass list so the publish workflow can push the bottle commit; the bypass is not limited to that commit, so the workflows that mint its token (`autobump.yml` and `publish.yml`) are part of the trust boundary and need maintainer review like a formula. A maintainer approves every formula PR.

Those checks do not prove that the upstream repository, its maintainers' accounts, or its source are safe. A credible upstream compromise is in scope for a private report even if every checksum matches.

## Supported versions

Security fixes go to `main` and the latest formula for each tool. We do not backport tap fixes to older formula revisions. Callisto and Caliper each define support for their own releases in their repositories.
