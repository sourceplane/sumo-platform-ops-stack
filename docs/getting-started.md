# Getting started

`stack-tectonic` is a versioned Orun stack catalog. Consumer repositories pin it as an OCI composition source, then declare local `component.yaml` manifests that use the exported composition types.

## 1. Pin the runtime

Use `kiox.yaml` to pin the `orun` CLI version you want in the consuming repository.

## 2. Pin the catalog

Declare this stack in `intent.yaml`:

```yaml
compositions:
  sources:
    - name: stack-tectonic
      kind: oci
      ref: oci://ghcr.io/sourceplane/stack-tectonic:0.11.0
```

## 3. Discover local components

Point `discovery.roots` at the application, infra, and deploy directories that own `component.yaml` files.

## 4. Plan and apply

Run `orun validate`, `orun plan`, or `orun run` against that intent. The stack stays versioned independently from the consuming repository.

For the full repo-consumer workflow, see [using-this-stack-from-oci.md](using-this-stack-from-oci.md).
