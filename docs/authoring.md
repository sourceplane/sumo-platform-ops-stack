# Authoring guide

## Add a composition

1. Create `compositions/<name>/compositions.yaml`.
2. Describe the contract in `spec.description`, `spec.inputSchema`, and `spec.jobs`.
3. Add at least one realistic fixture under `examples/` and one smoke or contract fixture under `tests/`, preferably excerpted or adapted from a consumer-style repo.
4. Run `./scripts/generate-readme.sh` to refresh the generated composition README summaries.
5. Run `./scripts/score.sh` and `./scripts/verify.sh`.

## Add a blueprint

1. Create `blueprints/<name>/blueprint.yaml`.
2. Document the composition set in `blueprints/<name>/README.md`.
3. Add example references or starter intent snippets if the blueprint introduces a new adoption path.

## Keep the catalog clean

- Prefer atomic compositions over variant explosions.
- Use blueprints for recommended assemblies.
- Keep example and test fixtures close enough to real repositories that they can guide consumers and feed CI trust signals.
- Keep the OCI consumption story pinned to released versions, not floating refs.
