# Helm chart CI — reusable workflows

Homelab Helm charts share the same release pattern. Use these **reusable workflows** from `expectedbehaviors/github-actions` instead of duplicating inline `helm lint` steps.

## Call order

| Stage | When | Reusable workflow |
|-------|------|-------------------|
| **Validate** | `pull_request` to `main` (chart paths) | `helm-chart-validate.yml` |
| **Release** | `push` to `main` (chart paths) | `helm-chart-release-on-merge.yml` |
| **Publish** | `release: published` or `workflow_run` after release | `helm-chart-publish.yml` |
| **Release notes** | `release: published` or `workflow_run` after release | `helm-chart-release-notes.yml` |

Composite building blocks (called in order by the workflows above):

1. `helm-lint` — install Helm, add repos, `helm dependency update`, `helm lint`
2. `helm-template` — `helm template` render proof
3. `helm-chart-validate` — orchestrates **lint → template**
4. `release-on-merge` — tag + GitHub Release
5. `helm-publish` — package `.tgz`, sync `Chart.yaml`, `gh-pages` index
6. `release-notes` — OpenAI summary from merged PR

## Standard path filters

```yaml
paths:
  - 'Chart.yaml'
  - 'Chart.lock'
  - 'values.yaml'
  - 'values/**'
  - 'README.md'
  - '.helmignore'
  - 'templates/**'
```

Do **not** include `.github/workflows/**` in path filters unless you intentionally want workflow edits to trigger releases (most charts exclude it).

## Release-only chart (no gh-pages publish)

`release-on-merge.yml`:

```yaml
name: Release gaps chart on merge to main

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

concurrency: release-gaps

jobs:
  validate:
    if: github.event_name == 'pull_request'
    uses: expectedbehaviors/github-actions/.github/workflows/helm-chart-validate.yml@main
    with:
      chart_path: .
      helm_repositories: |
        bjw-s=https://bjw-s-labs.github.io/helm-charts
        expectedbehaviors-op=https://expectedbehaviors.github.io/OnePasswordItem-helm

  release:
    if: github.event_name == 'push'
    uses: expectedbehaviors/github-actions/.github/workflows/helm-chart-release-on-merge.yml@main
    secrets: inherit
    with:
      chart_path: .
      helm_repositories: |
        bjw-s=https://bjw-s-labs.github.io/helm-charts
        expectedbehaviors-op=https://expectedbehaviors.github.io/OnePasswordItem-helm
      tag_prefix: gaps-v
```

`release-notes.yml` (separate file, triggered by release):

```yaml
name: Release notes gaps

on:
  release:
    types: [published]
  workflow_run:
    workflows: ["Release gaps chart on merge to main"]
    types: [completed]
    branches: [main]
  workflow_dispatch:
    inputs:
      release_tag:
        description: 'Release tag (e.g. gaps-v1.0.0). Default: latest.'
        required: false

jobs:
  release-notes:
    if: github.event_name == 'release' || github.event_name == 'workflow_dispatch' || (github.event_name == 'workflow_run' && github.event.workflow_run.conclusion == 'success')
    uses: expectedbehaviors/github-actions/.github/workflows/helm-chart-release-notes.yml@main
    secrets: inherit
    with:
      release_tag: ${{ github.event.inputs.release_tag }}
```

## Publishing chart (gh-pages + tarball)

Add `helm-publish.yml` calling `helm-chart-publish.yml` with `chart_name`, `tag_version_prefix`, and optional `values_image_tag_key`.

The `workflow_run.workflows` name must match the `name:` field of your release-on-merge workflow exactly.

## Charts with `deploy/helm` path

Set `chart_path: deploy/helm` (or `deploy/helm/radarr` for core submodules) in all `with:` blocks.

## `workflow_dispatch` baseline version

Pass through `initial_version` on the release reusable workflow:

```yaml
initial_version: ${{ github.event.inputs.baseline_version || '' }}
```
