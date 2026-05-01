# Concepts

## Stack catalog

This repository is a catalog, not an application repo. It publishes versioned execution contracts that other repositories consume through OCI.

## Compositions

`compositions/` contains atomic Orun `Composition` contracts. These are the stable type-level building blocks exported by the stack package.

## Blueprints

`blueprints/` groups recommended multi-composition patterns for common adoption paths. Blueprints are human-facing catalog assets that explain how multiple compositions fit together.

## Examples

`examples/` contains starter intents that show how a consumer repo can reference the OCI package and structure discovery roots.

## Registry index

`registry/index.json` is generated catalog metadata for future search, score, and registry sync workflows.

## Trust model

The stack separates verification into:

- contract validation
- docs hygiene
- score generation
- tagged release publication

That split keeps discovery and trust signals visible without coupling them to a single flat workflow.
