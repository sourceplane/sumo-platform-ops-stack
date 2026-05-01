# Authoring guide

## Add a composition

1. Create `compositions/<name>/compositions.yaml`.
2. Describe the contract in `spec.description`, `spec.inputSchema`, and `spec.jobs`.
3. Run `./scripts/generate-readme.sh` to scaffold the local README, examples, and tests placeholders.
4. Run `./scripts/score.sh` and `./scripts/verify.sh`.

## Add a blueprint

1. Create `blueprints/<name>/blueprint.yaml`.
2. Document the composition set in `blueprints/<name>/README.md`.
3. Add example references or starter intent snippets if the blueprint introduces a new adoption path.

## Keep the catalog clean

- Prefer atomic compositions over variant explosions.
- Use blueprints for recommended assemblies.
- Add runnable example assets to improve the generated maturity score.
- Keep the OCI consumption story pinned to released versions, not floating refs.
