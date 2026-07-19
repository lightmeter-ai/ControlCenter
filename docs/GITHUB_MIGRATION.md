# GitHub migration and GitLab retirement

GitHub repository: <https://github.com/lightmeter-ai/ControlCenter>

GitLab compatibility archive: <https://gitlab.com/lightmeter/controlcenter>

GitHub is the authoritative repository and the only CI/CD writer. GitLab CI is
fail-closed through `.gitlab-ci.yml`, and the GitLab project should be archived
after the final parity checks. Do not configure GitLab schedules, release jobs,
container publishers, or bidirectional repository mirrors.

## Automation ownership

| Capability | GitHub owner | Publication target |
| --- | --- | --- |
| Pull-request and branch CI | `.github/workflows/ci.yml` | Check results and coverage artifacts |
| SAST and dependency review | `.github/workflows/security.yml` | GitHub code scanning and check results |
| Versioned releases | `.github/workflows/release.yml` | GitHub Releases, Docker Hub, and GHCR |
| Dormant nightly capability | `.github/workflows/nightly.yml` | Docker Hub and GHCR, manual only |

The release and nightly workflows need these GitHub Actions secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

The security workflow uses the `SONAR_TOKEN` Actions secret and the
`SONAR_HOST_URL` repository variable. The token copied from GitLab during the
2026-07-19 migration was already expired at the source. The workflow validates
the credential before doing the expensive Sonar work: a missing or expired
legacy credential produces an explicit warning and skips SonarCloud, while a
transport or API failure still fails the job. Replace `SONAR_TOKEN` with a new
SonarQube Cloud token to restore the scan; once enabled, scanner failures are
blocking.

`GITHUB_TOKEN` supplies GitHub Release and GHCR authorization. Repository
workflow-token defaults must stay read-only; only publishing jobs receive
`contents: write` or `packages: write`.

## Historical state

Branches, tags, and commit history were mirrored before cutover and must remain
at exact SHA parity for all GitLab refs that still exist. Historical GitLab
release binaries and checksums are copied to the corresponding GitHub Releases.
Docker Hub remains the compatibility registry for existing users; GHCR is the
GitHub-native registry for new automation.

The historical migration produced 53 GitHub Releases. Twenty-two versions have
recoverable Linux AMD64 binaries and checksums, for 44 uploaded assets; each
available checksum was verified before upload. The remaining historical asset
links targeted the retired Bintray service and are retained only in release
provenance, not presented as downloadable files.

`ci/migrate_gitlab_releases.sh` is the idempotent release migration utility. It
runs read-only by default. Review its complete dry-run output before setting
`APPLY_RELEASE_MIGRATION=true`; during an applied run it accepts binary assets
only from this project's GitLab generic-package path and verifies each available
SHA-256 manifest before reporting success.

The private repository
[`lightmeter-ai/ControlCenter-GitLab-Archive`](https://github.com/lightmeter-ai/ControlCenter-GitLab-Archive)
holds the deletion-readiness project export. The 2026-07-19 export is
191,185,633 bytes with 724 archive entries and SHA-256
`204497ceae80ca56989159cdeab44f79e120cf9825a6b95cdebb1688f0108319`.
GitHub reports the same digest for the uploaded release asset. Keep that
repository private because the export includes confidential project records.

The GitLab container registry held 55 tags at migration time. Docker Hub
already held 52 matching tag names and was missing only `0.0.2`, `0.0.3`, and
`0.0.4`. `.github/workflows/migrate-images.yml` uses pinned `crane` tooling and
`ci/migrate_gitlab_images.sh` to copy missing tags to Docker Hub and all tags to
GHCR. It refuses to overwrite a target tag whose manifest digest differs from
GitLab and verifies every copied digest before reporting success.

GitLab issues, merge requests, discussions, labels, milestones, uploads, and
other project metadata must be retained in a private export before any account
deletion. Confidential issue content must never be copied to this public
repository. Public historical links may continue pointing to the archived
GitLab project while that compatibility surface exists.

## Legacy Go module path

The module path remains `gitlab.com/lightmeter/controlcenter` for compatibility
with published versions and downstream Go consumers. This does not make GitLab
the source of truth, but it does mean the public GitLab project is currently a
compatibility endpoint for fresh Go module resolution.

Deleting a personal GitLab account is safe only after confirming that the
project and group are not solely owned by that account and that no mirror,
webhook, deploy token, runner, package, or variable is tied to it. Deleting the
GitLab project or group is a separate breaking change: first migrate the module
path and every downstream consumer to the GitHub path, publish a compatible
version, and verify clean module downloads without GitLab.

At migration time, the GitLab group and project had two active owners, so the
current authenticated account was not the sole owner. Recheck this immediately
before account deletion because membership can change.

## Final deletion-readiness gate

Before deleting the old account, record evidence for every item below:

- GitHub `master`, `develop`, and all retained release tags match their intended
  GitLab source SHAs.
- Required GitHub checks pass on the latest reviewed commit.
- A renewed `SONAR_TOKEN` passes the workflow credential preflight and the
  SonarCloud scan, or SonarCloud retirement is explicitly approved and its
  workflow/configuration is removed.
- A clean Docker build succeeds without pulling from `registry.gitlab.com`.
- A manual dry-run proves the release workflow's validation and asset layout.
- GitHub Releases contain every recoverable historical binary and checksum.
- Docker Hub retains compatibility tags and GHCR contains the GitHub-published
  tags required for future releases.
- GitLab pipelines and schedules cannot run; remote mirrors and webhooks are
  removed; variables are deleted only after their GitHub replacements work.
- All live and documented image consumers use Docker Hub or GHCR rather than
  the GitLab registry.
- A private, integrity-checked GitLab project export exists and its restore
  instructions have been tested without exposing confidential records.
- Remaining GitLab ownership is group/service-account based, or the legacy Go
  module path and every consumer have been migrated away from GitLab.
