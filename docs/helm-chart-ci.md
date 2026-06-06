# Helm chart CI — one caller, one reusable workflow

Homelab charts share the same pipeline. **Do not duplicate** `release-on-merge`, `helm-publish`, and `release-notes` across three workflow files.

Use **one file** in each chart repo that calls **`helm-chart-ci.yml`** in `expectedbehaviors/github-actions`.

## Pipeline (inside reusable workflow)

| Stage | Composite / action | When |
|-------|-------------------|------|
| Validate | `helm-chart-validate` → `helm-lint` → `helm-template` | `pull_request`, `push` |
| Release | `release-on-merge` | `push` to `main` (after validate) |
| Publish | `helm-publish` | `release: published`, `workflow_dispatch` (after caller creates a Release on push to `main`) |
| Release notes | `release-notes` | same as publish (when enabled) |

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
