# sumo-platform-ops-stack

Versioned OCI-hosted platform compositions for Sourceplane repos.

This repository is the source of truth for the packaged Orun stack consumed by platform repositories such as `example-platform-repo`. It publishes the composition package to GHCR and keeps execution contracts versioned independently from the application and infrastructure repos that use them.

## Package layout

The repository root is the composition package root:

- `stack.yaml` defines the exported stack metadata and OCI registry target
- `<type>/compositions.yaml` defines one `Composition` contract per component type
- `.github/workflows/ci.yml` validates the package on pull requests and pushes to `main`
- `.github/workflows/release.yml` publishes tagged releases to `ghcr.io/sourceplane/sumo-platform-ops-stack`

## Exported composition types

- `terraform`
- `helm-values`
- `helm-chart`
- `cloudflare-worker`
- `cloudflare-worker-turbo`
- `cloudflare-pages`
- `cloudflare-pages-turbo`
- `cloudflare-pages-terraform`
- `cloudflare-pages-turbo-terraform`
- `turbo-package`
- `workspace`

## Releasing

1. Update `stack.yaml` with the next package version.
2. Merge the change to `main`.
3. Push a matching git tag in the form `vX.Y.Z`.

The release workflow validates that the git tag matches `stack.yaml`, then publishes the package to:

`oci://ghcr.io/sourceplane/sumo-platform-ops-stack:<version>`
