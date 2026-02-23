#!/usr/bin/env bash
# Create initial GitHub releases for each Helm chart that does not yet have a release.
# Uses gh CLI; you will be prompted for credentials (e.g. 1Password for GitHub).
# Run from the repository root. Requires: gh, jq (for gh api).
#
# Usage: ./homelab/github-actions/scripts/create-initial-releases.sh [--dry-run]

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
cd "$REPO_ROOT"
DRY_RUN=false
[[ "${1:-}" = "--dry-run" ]] && DRY_RUN=true

# Chart list: tag_prefix | path to Chart.yaml (from repo root) | optional description override (or "" to use Chart description)
CHARTS=(
  "harbor|homelab/helm/harbor/Chart.yaml|"
  "kubernetes-dashboard|homelab/helm/kubernetes-dashboard/Chart.yaml|"
  "immich|homelab/helm/immich/Chart.yaml|"
  "longhorn|homelab/helm/longhorn/Chart.yaml|"
  "nextcloud|homelab/helm/nextcloud/helm/Chart.yaml|"
  "oauth2-proxy|homelab/helm/oauth2-proxy/Chart.yaml|"
  "plex|homelab/helm/plex/Chart.yaml|"
  "audiobookshelf|homelab/helm/audiobookshelf/Chart.yaml|"
  "atlantis|homelab/helm/atlantis/helm/Chart.yaml|"
  "postgresql|homelab/helm/postgresql/operator/Chart.yaml|"
  "redis|homelab/helm/redis/operator/Chart.yaml|"
  "plex-autoskip|homelab/helm/plex-autoskip/Chart.yaml|"
  "unpackerr|homelab/helm/unpackerr/Chart.yaml|"
)

get_version_from_chart() {
  local chart_path="$1"
  if [[ ! -f "$chart_path" ]]; then
    echo "" && return
  fi
  local v
  v=$(awk '/^version:/ { gsub(/^[ \t"]+|[ \t"]+$/, "", $2); gsub(/^v/, "", $2); print $2 }' "$chart_path")
  echo "${v}"
}

get_description_from_chart() {
  local chart_path="$1"
  if [[ ! -f "$chart_path" ]]; then
    echo "Helm chart release."
    return
  fi
  local d
  d=$(awk '/^description:/ { $1=""; gsub(/^[ \t"]+|[ \t"]+$/, ""); print; exit }' "$chart_path")
  if [[ -n "${d:-}" ]]; then
    echo "$d"
  else
    echo "Helm chart release."
  fi
}

echo "Using repo root: $REPO_ROOT"
echo "Ensure gh is authenticated (e.g. gh auth login, or 1Password for gh)."
echo ""

for entry in "${CHARTS[@]}"; do
  IFS='|' read -r tag_prefix chart_path desc_override <<< "$entry"
  if [[ ! -f "$chart_path" ]]; then
    echo "[SKIP] $tag_prefix: Chart not found at $chart_path"
    continue
  fi
  version=$(get_version_from_chart "$chart_path")
  if [[ -z "$version" ]]; then
    echo "[SKIP] $tag_prefix: No version in $chart_path"
    continue
  fi
  tag="${tag_prefix}-v${version}"
  if gh release view "$tag" &>/dev/null; then
    echo "[OK] $tag — release already exists"
    continue
  fi
  if [[ -n "${desc_override:-}" ]]; then
    notes="$desc_override"
  else
    notes=$(get_description_from_chart "$chart_path")
  fi
  uncommitted_note=""
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    uncommitted_note=$'\n\n*Release created with uncommitted changes in the working tree (current state).*'
  fi
  notes="## $tag

$notes
${uncommitted_note}

*Initial release from current chart state. Future releases will be created automatically on merge to main (see homelab/github-actions/README.md).*"
  echo "[CREATE] $tag"
  if [[ "$DRY_RUN" = true ]]; then
    echo "  (dry-run) would run: gh release create $tag --notes \"...\" --latest"
    continue
  fi
  gh release create "$tag" --notes "$notes" --latest
  echo "  Created."
done

echo ""
echo "Done. Run release-notes workflows from the Actions tab to fill in OpenAI-summarized notes, or merge a PR and let automation run."
