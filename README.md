# Stack Tectonic

Versioned OCI catalog for reusable Orun compositions, blueprints, examples, and release metadata.

This repository is the source of truth for the stack published to:

`oci://ghcr.io/sourceplane/stack-tectonic:<version>`

## Use the OCI package in `intent.yaml`

Pin the catalog as a composition source in the consumer repository:

```yaml
compositions:
  sources:
    - name: stack-tectonic
      kind: oci
      ref: oci://ghcr.io/sourceplane/stack-tectonic:0.11.0
```

Keep the `orun` runtime pinned separately in `kiox.yaml`, then plan or run against that intent. The full consumer workflow is in [docs/using-this-stack-from-oci.md](docs/using-this-stack-from-oci.md).

## Catalog layout

```text
stack-tectonic/
├── stack.yaml
├── README.md
├── docs/
├── blueprints/
├── compositions/
├── examples/
├── scripts/
├── registry/
└── .github/workflows/
```

## Compositions

| Composition | Category | Purpose |
| --- | --- | --- |
| `cloudflare-pages` | hosting | Direct-upload Cloudflare Pages delivery |
| `cloudflare-pages-turbo` | hosting | Pages delivery from pnpm and Turbo monorepos |
| `cloudflare-pages-terraform` | platform | Terraform-managed Cloudflare Pages projects |
| `cloudflare-pages-turbo-terraform` | platform | Monorepo Pages delivery plus Terraform reconciliation |
| `cloudflare-worker` | edge | Cloudflare Worker validation and deploy jobs |
| `cloudflare-worker-turbo` | edge | Worker delivery from pnpm and Turbo monorepos |
| `terraform` | infrastructure | Terraform fmt, init, and validate jobs |
| `helm-chart` | kubernetes | Helm chart verification |
| `helm-values` | kubernetes | Helm values validation |
| `turbo-package` | developer-experience | Shared package verification in Turbo workspaces |
| `workspace` | developer-experience | Workspace-backed provider smoke jobs |

Every composition now lives under `compositions/<name>/` so docs, examples, tests, and future registry metadata can grow beside the contract instead of around a flat root.

## Blueprints

| Blueprint | Uses | Focus |
| --- | --- | --- |
| `nextjs-cloudflare` | `workspace`, `turbo-package`, `cloudflare-pages-turbo`, `cloudflare-pages-terraform` | Edge-hosted Next.js monorepos with Terraform-managed Pages |
| `edge-worker-platform` | `workspace`, `terraform`, `cloudflare-worker`, `helm-values` | Worker-first delivery with infra and environment overlays |

## Trust signals

- `scripts/verify-composition.sh` enforces that every exported composition keeps real examples and smoke fixtures beside its contract.
- `scripts/verify.sh` validates generated docs and scores, checks every composition fixture, and runs the stack OCI dry-run publish path.
- `scripts/score.sh` generates `registry/index.json` with maturity scores and grades.
- Composition fixtures are excerpted or adapted from `example-platform-repo` so the catalog documents real repo shapes instead of synthetic placeholders.
- GitHub workflows split per-composition fixture checks, full catalog verification, docs checks, scorecard generation, and releases into separate pipelines.

## Docs

- [Getting started](docs/getting-started.md)
- [Core concepts](docs/concepts.md)
- [Authoring guide](docs/authoring.md)
- [Verification model](docs/verification.md)
- [Production deploys](docs/production-deploys.md)
- [Remote-state matrix CI](docs/remote-state-matrix-ci.md)
- [Roadmap](docs/roadmap.md)
- [Using this stack from OCI](docs/using-this-stack-from-oci.md)

## Release flow

1. Update `stack.yaml`.
2. Run `./scripts/verify.sh`.
3. Merge to `main`.
4. Push a matching tag like `v0.11.0`.

The release workflow publishes the OCI package, creates the GitHub release, and uploads the generated registry index.
