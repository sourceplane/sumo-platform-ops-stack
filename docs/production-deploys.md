# Production deploys

This document explains how to configure reliable production deployments using stack-tectonic compositions on the production branch.

## The `--changed` trap

When using `orun run --changed` on production branch pushes (e.g. after a squash merge to `main`), the change detection compares the merge commit against its parent. Because a squash merge produces a single commit whose parent is the previous `main` HEAD, and the new commit already includes all changes, `--changed` may resolve to zero changed components:

```text
0 components x 3 envs -> 0 jobs
```

This produces a **green CI run with zero deployments** — a false positive that masks the absence of any live deployment.

## Recommended patterns

### Pattern 1: Run all production jobs on main (recommended for small repos)

Remove `--changed` from the production branch push step:

```yaml
- name: Execute
  env:
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
  run: kiox -- orun run
```

This ensures every deployable component runs its production job on every push to main. For repos with fewer than 10 components, this adds minimal overhead.

### Pattern 2: Changed-only with correct base ref

If the repo has many components and full runs are expensive, pass explicit base/head refs:

```yaml
- name: Execute
  env:
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
  run: kiox -- orun run --changed --base "${{ github.event.before }}" --head "${{ github.sha }}"
```

Using `github.event.before` as the base ensures the diff covers the actual changes introduced by the merge.

### Pattern 3: Separate deploy workflow on main

Keep `--changed` for PR validation but add a dedicated production deploy step:

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: sourceplane/kiox-action@v2.1.2
        with:
          version: v0.4.3
      - name: Deploy all production components
        env:
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        run: kiox -- orun run --env production
```

## Composition behavior

Stack-tectonic Cloudflare compositions (`cloudflare-worker-turbo`, `cloudflare-worker`, `cloudflare-pages-turbo`, `cloudflare-pages`) all follow the same deploy semantics:

| Condition | Behavior | CI annotation |
| --- | --- | --- |
| Environment = `dev` | Dry-run only | `DRY-RUN` |
| Environment != `production` or branch != `productionBranch` | Skip deploy | `SKIPPED` |
| Environment = `production` AND branch = `productionBranch` AND credentials present | Live deploy | `LIVE DEPLOY` → `DEPLOY SUCCESS` |
| Credentials missing on production deploy | Hard failure | Step fails with clear error |

## Verifying a deploy actually happened

After a production push, check CI logs for:
- `::notice::LIVE DEPLOY: Deploying <component> to Cloudflare`
- `::notice::DEPLOY SUCCESS: <component> deployed to Cloudflare`

If you see only `SKIPPED` or `DRY-RUN` annotations, the deploy did not run.

A green run with `0 components x 3 envs -> 0 jobs` means **no deployment occurred**. This is never evidence of a successful deploy.

## Consumer repo checklist

Before relying on production deploys:

1. Set `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` as GitHub repository secrets
2. Ensure your workflow passes these as environment variables to the `orun run` step
3. Choose one of the patterns above for your production branch push behavior
4. Replace `PLACEHOLDER` database IDs in `wrangler.jsonc` with real resource IDs
5. If using D1, configure `migrationCommand` in your `component.yaml` inputs
6. Optionally add `smokeCommand` to verify the live endpoint after deploy
