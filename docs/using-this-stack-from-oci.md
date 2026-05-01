# Using this stack from OCI

This repository is meant to be consumed from other repositories as a versioned OCI-hosted Orun stack. The goal is simple:

- keep `component.yaml` ownership local to the consumer repo
- keep execution contracts centralized and versioned in this catalog
- let `intent.yaml` pin which catalog release the repo uses

## What this stack publishes

The published OCI artifact contains the composition contracts under `compositions/` plus the surrounding catalog metadata that explains how to use them.

Today the exported composition types are:

- `cloudflare-pages`
- `cloudflare-pages-turbo`
- `cloudflare-pages-terraform`
- `cloudflare-pages-turbo-terraform`
- `cloudflare-worker`
- `cloudflare-worker-turbo`
- `terraform`
- `helm-chart`
- `helm-values`
- `turbo-package`
- `workspace`

## The split to keep in mind

There are two separate things to pin in a consumer repo:

1. `kiox.yaml` pins the `orun` runtime image.
2. `intent.yaml` pins the composition catalog release.

That separation matters because upgrading the CLI and upgrading the stack contracts are different lifecycle decisions.

## Minimal `intent.yaml`

Use an OCI composition source in the consumer repository:

```yaml
apiVersion: sourceplane.io/v1
kind: Intent
metadata:
  name: my-platform

compositions:
  sources:
    - name: stack-tectonic
      kind: oci
      ref: oci://ghcr.io/sourceplane/stack-tectonic:0.11.0

discovery:
  roots:
    - apps
    - infra
    - deploy

environments:
  development: {}
  production: {}
```

The important line is the OCI source:

```yaml
ref: oci://ghcr.io/sourceplane/stack-tectonic:0.11.0
```

Pin a released version instead of `latest` so plans stay reproducible.

## Local component ownership

The consuming repository should keep `component.yaml` files next to the code or infrastructure they own.

Example:

```yaml
apiVersion: sourceplane.io/v1
kind: Component
metadata:
  name: marketing-site

spec:
  type: cloudflare-pages
  domain: edge
  subscribe:
    environments: [development, production]
  inputs:
    siteDir: .
    installCommand: pnpm install --frozen-lockfile
    buildCommand: pnpm run build
    outputDir: dist
    projectName: marketing-site
    nodeVersion: "20"
    productionBranch: main
```

The component stays repo-local. Only the execution contract for `cloudflare-pages` comes from the OCI package.

## Recommended adoption path

1. Start with atomic compositions like `terraform`, `cloudflare-pages`, or `workspace`.
2. Adopt monorepo-aware types like `turbo-package` or `cloudflare-pages-turbo` when the repo needs them.
3. Use the blueprints in this repo as guidance for multi-composition rollouts.

## Upgrade flow

1. Update the OCI ref in `intent.yaml`.
2. Lock or re-resolve composition sources if the consumer workflow uses source locking.
3. Run `orun validate` and `orun plan`.
4. Promote the catalog upgrade through environments like any other platform change.

## Why this repo now uses a catalog structure

The old flat layout worked for a small prototype, but it would become noisy as the stack grows. The current layout separates:

- `compositions/` for atomic contracts
- `blueprints/` for recommended assemblies
- `examples/` for starter consumer intents
- `registry/` for generated catalog metadata
- `docs/` for consumer and contributor guidance

That makes the stack easier to search, test, score, version, and eventually sync into a broader registry experience.
