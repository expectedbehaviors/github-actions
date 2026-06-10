# Helm chart CI — one caller, one reusable workflow

Homelab charts share the same pipeline. **Do not duplicate** `release-on-merge`, `helm-publish`, and `release-notes` across three workflow files.

Use **one file** in each chart repo that calls **`helm-chart-ci.yml`** in `expectedbehaviors/github-actions`.

## Pipeline (inside reusable workflow)

| Stage | Composite / action | When |
|-------|-------------------|------|
| Validate | `helm-chart-validate` → `helm-lint` → `helm-template` | `pull_request`, `push` |
| Release | `release-on-merge` | `push` to `main` (after validate) |
| Publish | `helm-publish` | `push` to `main` (after release), `release: published`, `workflow_dispatch` |
| Release notes | `release-notes` | same as publish (when enabled) |

Publish runs in the same workflow run as `release-on-merge` on `push`: releases created with the automatic `GITHUB_TOKEN` do **not** trigger new workflow runs, so the `release: published` trigger alone never fires after a merge. The `push` condition chains publish off the release job directly (`needs: release` guarantees the tag exists; the version resolves from the latest GitHub Release).

Terraform, Docker, and other non-Helm actions are **not** part of this workflow.

## Standard path filters

GitHub Actions does **not** support YAML anchors/aliases (`&anchor` / `*alias`) in workflow files — a workflow using them fails to parse with "Anchors are not currently supported." Repeat the `paths` list under both `push` and `pull_request`:

```yaml
paths:
  - 'Chart.yaml'
  - 'values.yaml'
  - 'values/**'
  - 'README.md'
  - '.helmignore'
  - 'templates/**'
```

## Publishing chart (mealie example)

Replace `release-on-merge.yml`, `helm-publish.yml`, and `release-notes.yml` with **only** `.github/workflows/helm-chart-ci.yml`:

```yaml
name: Helm chart CI

on:
  push:
    branches: [main]
    paths:
      - 'Chart.yaml'
      - 'values.yaml'
      - 'values/**'
      - 'README.md'
      - '.helmignore'
      - 'templates/**'
  pull_request:
    branches: [main]
    paths:
      - 'Chart.yaml'
      - 'values.yaml'
      - 'values/**'
      - 'README.md'
      - '.helmignore'
      - 'templates/**'
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      baseline_version:
        description: 'First release version when no tags exist (e.g. 1.0.0)'
        required: false
      release_tag:
        description: 'Release tag override for publish/notes (e.g. mealie-v1.0.0)'
        required: false

concurrency: helm-chart-mealie

jobs:
  ci:
    permissions:
      contents: write
      pull-requests: read
    uses: expectedbehaviors/github-actions/.github/workflows/helm-chart-ci.yml@main
    secrets: inherit
    with:
      chart_path: .
      chart_name: mealie
      tag_prefix: mealie-v
      helm_repositories: |
        bjw-s=https://bjw-s-labs.github.io/helm-charts
        onepassworditem=https://expectedbehaviors.github.io/OnePasswordItem-helm
      helm_repo_name: bjw-s
      helm_repo_url: https://bjw-s-labs.github.io/helm-charts
      helm_repo_name_2: onepassworditem
      helm_repo_url_2: https://expectedbehaviors.github.io/OnePasswordItem-helm
      publish_enabled: true
      release_notes_enabled: true
      initial_version: ${{ github.event.inputs.baseline_version || '' }}
      release_tag: ${{ github.event.inputs.release_tag || '' }}
```

Delete the old three workflow files after adding this one.

**Do not** add `workflow_run` that references this workflow's own `name:` — GitHub rejects it ("cannot listen to itself"). Publish and release-notes run on `release: published` after the release job creates a GitHub Release.

## Release-only chart (no gh-pages publish)

Set `publish_enabled: false`. Release and release notes still run when configured.

```yaml
with:
  tag_prefix: gaps-v
  publish_enabled: false
  release_notes_enabled: true
  helm_repositories: |
    bjw-s=https://bjw-s-labs.github.io/helm-charts
```

## Charts under `deploy/helm`

Set `chart_path: deploy/helm` in `with:`.

## Chart.yaml version sync (publish)

After uploading the release tarball, `helm-publish` tries to commit `Chart.yaml` with the released `version` / `appVersion` and push to the default branch. On repos with branch protection (PR required), that push is **best-effort**: publish still succeeds and emits a workflow warning. Bump `Chart.yaml` in a follow-up PR if git drifts from the release tag.

## First release (`workflow_dispatch`)

Charts with no GitHub Release yet must bootstrap via **Actions → Helm chart CI → Run workflow** with `baseline_version` (e.g. `1.0.0`). That runs `release-on-merge` first (creates tag + Release), then publish and release-notes. Republish an existing tag with `release_tag` only (omit `baseline_version`).

## Required secrets

| Secret | When |
|--------|------|
| `GITHUB_TOKEN` | Always (automatic in reusable workflows — **do not** declare in `workflow_call.secrets`) |
| `OPENAI_API_KEY` | When `release_notes_enabled: true` (declare in `workflow_call.secrets`; pass via `secrets: inherit` or explicit mapping) |

Caller example:

```yaml
jobs:
  ci:
    permissions:
      contents: write
      pull-requests: read
    uses: expectedbehaviors/github-actions/.github/workflows/helm-chart-ci.yml@main
    secrets: inherit   # passes OPENAI_API_KEY; GITHUB_TOKEN is automatic
```

Caller `permissions` must meet or exceed what the reusable workflow jobs need, or GitHub fails with `startup_failure` before any job runs.

## Release notes format

The `release-notes` action writes **user-facing** notes for chart operators:

- **What's changed** — summarized from the merged PR and commits (not raw PR review templates)
- **Install and upgrade** — `helm repo add`, `helm upgrade --install` with version and README link

Pass `chart_name` and `tag_prefix` via the reusable workflow (already wired from callers). Optional per-chart `prompt_instruction` for extra guidance.

Regenerate notes for an existing release via **Actions → Helm chart CI → Run workflow** on the chart repo, or:

```bash
gh workflow run helm-chart-ci.yml --repo expectedbehaviors/<chart> --ref main -f release_tag=<chart>-vX.Y.Z
```
