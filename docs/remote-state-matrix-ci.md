# Remote-state matrix CI

This example shows how a consumer repository can compile one `orun` plan and fan it out across a GitHub Actions matrix while using remote state for coordination.

It is adapted from the upstream `sourceplane/orun` remote-state examples:

- `examples/github-actions/remote-state-matrix.yml`
- `examples/remote-state-matrix/README.md`

## Required repository configuration

Set these GitHub Actions repository variables before enabling the workflow:

| Setting | Location | Value |
| --- | --- | --- |
| `ORUN_BACKEND_URL` | Settings → Variables → Actions | URL of your `orun-backend` instance |

The workflow also needs:

- `contents: read`
- `id-token: write`

`id-token: write` is required because the remote-state backend authenticates GitHub Actions runners with OIDC.

## Consumer repo assumptions

This workflow assumes the consumer repository:

1. Pins `orun` in `kiox.yaml`
2. Pins this catalog in `intent.yaml`
3. Keeps `component.yaml` files in the repo roots discovered by the intent

If you want remote state declared in the intent, use the same `execution.state` shape shown in the upstream `sourceplane/orun` examples.

## Example workflow

```yaml
name: remote-state-matrix

on:
  workflow_dispatch:
  pull_request:
  push:
    branches:
      - main

permissions:
  contents: read
  id-token: write

jobs:
  plan:
    name: Compile plan
    runs-on: ubuntu-latest
    outputs:
      plan_id: ${{ steps.plan.outputs.plan_id }}
      run_id: ${{ steps.plan.outputs.run_id }}
      jobs: ${{ steps.matrix.outputs.jobs }}
      first_job: ${{ steps.matrix.outputs.first_job }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: sourceplane/kiox-action@v2.1.2

      - name: Compile plan
        id: plan
        run: |
          kiox -- orun validate --intent intent.yaml
          kiox -- orun plan --intent intent.yaml --name remote-state-stack --all
          plan_id="$(kiox -- orun get plans -o json | jq -r '.[] | select(.Name == "remote-state-stack") | .Checksum')"
          run_id="gha-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}-${plan_id}"
          echo "plan_id=${plan_id}" >> "${GITHUB_OUTPUT}"
          echo "run_id=${run_id}" >> "${GITHUB_OUTPUT}"

      - name: Build job matrix
        id: matrix
        run: |
          jobs="$(kiox -- orun get jobs --plan '${{ steps.plan.outputs.plan_id }}' --all -o json \
            | jq -c '[.[] | {job: .id, env: .environment, component: .component}]')"
          first_job="$(printf '%s' "${jobs}" | jq -r '.[0].job')"
          echo "jobs=${jobs}" >> "${GITHUB_OUTPUT}"
          echo "first_job=${first_job}" >> "${GITHUB_OUTPUT}"

      - name: Upload compiled plan
        uses: actions/upload-artifact@v4
        with:
          name: orun-plan
          path: .orun/plans/
          if-no-files-found: error

  run-one-job-per-runner:
    name: "Run: ${{ matrix.job }}"
    needs: plan
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        include: ${{ fromJson(needs.plan.outputs.jobs) }}
    env:
      ORUN_BACKEND_URL: ${{ vars.ORUN_BACKEND_URL }}
      ORUN_REMOTE_STATE: "true"
      ORUN_EXEC_ID: ${{ needs.plan.outputs.run_id }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: sourceplane/kiox-action@v2.1.2

      - name: Download compiled plan
        uses: actions/download-artifact@v4
        with:
          name: orun-plan
          path: .orun/plans/

      - name: Run selected job through remote state
        run: |
          kiox -- orun run '${{ needs.plan.outputs.plan_id }}' \
            --job '${{ matrix.job }}' \
            --remote-state \
            --backend-url "${ORUN_BACKEND_URL}" \
            --gha \
            --verbose

  verify:
    name: Verify remote status and logs
    needs: [plan, run-one-job-per-runner]
    if: always()
    runs-on: ubuntu-latest
    env:
      ORUN_BACKEND_URL: ${{ vars.ORUN_BACKEND_URL }}
      ORUN_REMOTE_STATE: "true"
      ORUN_EXEC_ID: ${{ needs.plan.outputs.run_id }}
    steps:
      - uses: actions/checkout@v4

      - uses: sourceplane/kiox-action@v2.1.2

      - name: Download compiled plan
        uses: actions/download-artifact@v4
        with:
          name: orun-plan
          path: .orun/plans/

      - name: Verify remote status
        run: |
          kiox -- orun status \
            --remote-state \
            --backend-url "${ORUN_BACKEND_URL}" \
            --exec-id "${ORUN_EXEC_ID}" \
            --json

      - name: Verify remote logs
        run: |
          kiox -- orun logs \
            --remote-state \
            --backend-url "${ORUN_BACKEND_URL}" \
            --exec-id "${ORUN_EXEC_ID}" \
            --job '${{ needs.plan.outputs.first_job }}'
```

## What this pattern gives you

- One plan compiled once per workflow run
- A deterministic execution ID shared by every matrix runner
- Remote job claiming so two runners do not execute the same job
- Dependency-aware fan-out, where downstream jobs wait until upstream jobs complete
- Post-run inspection through `orun status --remote-state` and `orun logs --remote-state`

For small production repos, this can also replace a single serial `orun run` step in the deployment workflow described in [production-deploys.md](production-deploys.md).
