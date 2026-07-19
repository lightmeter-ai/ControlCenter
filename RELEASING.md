<!--
SPDX-FileCopyrightText: 2021 Lightmeter <hello@lightmeter.io>
SPDX-License-Identifier: AGPL-3.0-only
-->

# How to release

GitHub is the source of truth for repository and release automation. GitLab CI
is deliberately disabled and must not be used to publish releases or images.

Control Center uses semantic versioning. A release is identified by the tag
`release/<VERSION>` and publishes:

- a GitHub release containing the Linux AMD64 binary and SHA-256 checksum;
- `docker.io/lightmeter/controlcenter:<VERSION>` and `latest`;
- `ghcr.io/lightmeter-ai/controlcenter:<VERSION>` and `latest`.

To release:

1. Update `VERSION.txt`.
2. Add the plain-text release notes at `release_notes/<VERSION>`.
3. Open and merge a pull request. The required `GitHub migration guards`,
   `Go tests`, and `Release image build` checks must pass.
4. Create and push the annotated `release/<VERSION>` tag from the reviewed
   commit:

   ```sh
   version=$(cat VERSION.txt)
   git tag -a "release/$version" -m "Release $version"
   git push github "release/$version"
   ```

5. Verify the `Release` GitHub Actions workflow. It validates that the tag,
   version file, release notes, and checked-out commit agree before publishing.
6. Verify the binary checksum and both container registries from a clean
   client. Do not treat a green workflow alone as release proof.

The workflow can be re-run for an existing tag through `workflow_dispatch`.
Enter the exact `release/<VERSION>` tag; it will update the GitHub release
assets and image tags idempotently.

The historical `nightly-master` and `nightly-develop` schedules were already
disabled on GitLab. GitHub preserves them as a manual `Nightly image` workflow
without silently reactivating scheduled publication.
