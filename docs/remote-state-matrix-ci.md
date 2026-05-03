# Remote-state matrix CI

This guide shows an **opt-in advanced** GitHub Actions pattern for consumer repositories that need backend-coordinated matrix execution. It compiles one `orun` plan, uploads `.orun/plans/`, fans jobs out across a matrix, and verifies the shared remote state afterward.

It is adapted from the upstream `sourceplane/orun` remote-state references:

- `examples/github-actions/remote-state-matrix.yml`
- `examples/remote-state-matrix/README.md`
- `.github/workflows/remote-state-conformance.yml`

Do **not** make this your default pull-request lane just because the workflow exists. Keep it in a dedicated workflow and enable it only when the repository already has a real `orun-backend`, OIDC configured, and a reason to distribute execution across runners.

## Required repository configuration

Set these GitHub Actions repository variables before enabling the workflow:

| Setting | Location | Value |
| --- | --- | --- |
| `ORUN_BACKEND_URL` | Settings -> Variables -> Actions | URL of your `orun-backend` instance |
| `REMOTE_STATE_MATRIX_CI` | Settings -> Variables -> Actions | Optional `true` switch if you later decide to auto-run this workflow on push or PR |

The workflow permissions must include:

```yaml
permissions:
  contents: read
  id-token: write
```

`id-token: write` is mandatory because current Orun remote-state flows authenticate GitHub Actions runners with OIDC. Do not hard-code backend URLs, tokens, Cloudflare credentials, or production-only settings in the workflow file.

## Consumer repo assumptions

This pattern assumes the consumer repository pins the runtime and stack separately:

### `kiox.yaml`

```yaml
apiVersion: kiox.io/v1
kind: Workspace
metadata:
  name: my-platform
providers:
  orun:
    source: ghcr.io/sourceplane/orun:v1.12.0
```

### `intent.yaml`

```yaml
compositions:
  sources:
    - name: stack-tectonic
      kind: oci
      ref: oci://ghcr.io/sourceplane/stack-tectonic:0.12.0
```

This guide keeps remote state opt-in at the workflow layer by passing `--remote-state` and `--backend-url` explicitly. That keeps normal local `orun validate`, `orun plan`, and `orun run` behavior local unless you intentionally opt into backend-backed execution.

## Copyable workflow

Start with a dedicated manual workflow. If you later want push or pull-request automation, add those triggers behind a repo-level gate such as `vars.REMOTE_STATE_MATRIX_CI == 'true'`.

```yaml
name: remote-state-matrix

on:
  workflow_dispatch:

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
            --exec-id "${ORUN_EXEC_ID}" \
            --gha \
            --verbose

  verify:
    name: Verify remote status and logs
    needs: [plan, run-one-job-per-runner]
    if: always()
    runs-on: ubuntu-latest
    env:
      ORUN_BACKEND_URL: ${{ vars.ORUN_BACKEND_URL }}
      ORUN_EXEC_ID: ${{ needs.plan.outputs.run_id }}
    steps:
      - uses: actions/checkout@v4

      - uses: sourceplane/kiox-action@v2.1.2

      - name: Download compiled plan
        uses: actions/download-artifact@v4
        with:
          name: orun-plan
          path: .orun/plans/

      - name: Capture remote status
        id: status
        run: |
          status_json="$(kiox -- orun status \
            --remote-state \
            --backend-url "${ORUN_BACKEND_URL}" \
            --exec-id "${ORUN_EXEC_ID}" \
            --json)"
          echo "${status_json}" | jq .
          {
            echo 'status_json<<EOF'
            echo "${status_json}"
            echo 'EOF'
          } >> "${GITHUB_OUTPUT}"

      - name: Capture remote logs
        run: |
          kiox -- orun logs \
            --remote-state \
            --backend-url "${ORUN_BACKEND_URL}" \
            --exec-id "${ORUN_EXEC_ID}" \
            --job '${{ needs.plan.outputs.first_job }}'

      - name: Fail if remote state reports failed or incomplete jobs
        env:
          STATUS_JSON: ${{ steps.status.outputs.status_json }}
        run: |
          failed="$(printf '%s' "${STATUS_JSON}" | jq '(.state.jobs // {}) | to_entries | map(select(.value.status == "failed")) | length')"
          incomplete="$(printf '%s' "${STATUS_JSON}" | jq '(.state.jobs // {}) | to_entries | map(select(.value.status != "completed")) | length')"
          total="$(printf '%s' "${STATUS_JSON}" | jq '(.state.jobs // {}) | to_entries | length')"
          completed="$(printf '%s' "${STATUS_JSON}" | jq '(.state.jobs // {}) | to_entries | map(select(.value.status == "completed")) | length')"

          if [ "${failed}" -gt 0 ]; then
            echo "::error::${failed} remote-state job(s) failed"
            exit 1
          fi

          if [ "${incomplete}" -gt 0 ]; then
            echo "::error::${incomplete} remote-state job(s) did not reach completed status"
            exit 1
          fi

          echo "Remote state verification: ${completed}/${total} jobs completed successfully."
```

## Optional guarded automatic trigger

If this workflow becomes a useful recurring lane, add `push` and `pull_request` triggers and gate the `plan` job instead of running it for every PR by default:

```yaml
if: github.event_name == 'workflow_dispatch' || vars.REMOTE_STATE_MATRIX_CI == 'true'
```

That keeps remote-state matrix CI intentionally enabled instead of silently becoming a default branch or PR requirement.

## What this pattern gives you

- one plan compiled once per workflow run
- `.orun/plans/` shared to matrix runners instead of recompiling
- a deterministic `ORUN_EXEC_ID` shared by every runner
- remote job claiming so two runners do not execute the same job
- dependency-aware fan-out where downstream jobs wait until upstream jobs complete
- explicit post-run `orun status --remote-state` and `orun logs --remote-state` inspection
- a hard workflow failure when remote state reports failed or incomplete jobs

## What this guide intentionally omits

The upstream Orun examples also cover duplicate-claim and environment-fanout conformance cases. Those are intentionally omitted here because Stack Tectonic consumer guidance should stay focused on the smallest copyable workflow that proves one-plan matrix coordination.

If you are validating backend semantics rather than adopting the pattern in an application repo, start from the upstream Orun examples instead of this simplified consumer guide.
