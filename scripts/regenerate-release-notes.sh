#!/usr/bin/env bash
# Regenerate GitHub Release notes for expectedbehaviors Helm charts (workflow_dispatch).
# Requires: gh authenticated, charts already published.
# Usage: ./scripts/regenerate-release-notes.sh [--dry-run] [chart-name ...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
CHARTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) CHARTS+=("$1"); shift ;;
  esac
done

if [[ ${#CHARTS[@]} -eq 0 ]]; then
  CHARTS=(
    audiobookshelf bazarr cert-manager external-dns external-services gaps gotify
    ipmi-fan-control kavita kubernetes-replicator lidarr mealie mylar nginx oauth2-proxy
    ombi prowlarr purelb radarr readarr reloader seaweedfs sonarr tautulli tunnel-interface unpackerr
  )
fi

export GH_HOST="${GH_HOST:-github.com}"

for chart in "${CHARTS[@]}"; do
  repo="expectedbehaviors/${chart}"
  if ! tag=$(gh release view --repo "$repo" --json tagName -q '.tagName' 2>/dev/null); then
    echo "[SKIP] $chart — no release"
    continue
  fi
  echo "[RUN] $chart — regenerate notes for $tag"
  if [[ "$DRY_RUN" == true ]]; then
    echo "  dry-run: gh workflow run helm-chart-ci.yml --repo $repo --ref main -f release_tag=$tag"
    continue
  fi
  gh workflow run helm-chart-ci.yml --repo "$repo" --ref main -f "release_tag=${tag}"
done

echo "Done. Check Actions tab per repo for release-notes job."
