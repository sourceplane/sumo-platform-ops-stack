#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

./scripts/generate-readme.sh --check
./scripts/score.sh --check

stack_version="$(awk '/^  version: /{print $2}' stack.yaml)"
test -n "$stack_version"

kiox -- orun publish "ghcr.io/sourceplane/sumo-platform-ops-stack:${stack_version}" \
  --dry-run \
  --root . \
  --version "$stack_version"
