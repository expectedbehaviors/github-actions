# Reusable GitHub Actions

Shared composite actions for CI/CD: publishing (Docker, Helm), release automation, and release notes. Use from any repo with minimal inputs.

## Usage

Reference by repo and path. Prefer a fixed ref (tag or SHA) for reproducibility:

```yaml
uses: owner/github-actions/.github/actions/<action-name>@v1   # or @main, @sha-...
with:
  # action inputs
```

Secrets (e.g. `DOCKERHUB_USERNAME`, `OPENAI_API_KEY`) are defined in the **calling** repo; the actions run in that context and receive them automatically.

---

## Actions

### release-on-merge

Bump patch version from the latest `v*` tag and create a GitHub Release (tag + release). Use in a workflow that runs on push to `main` (with path filters as needed).

**Caller job:** `checkout` with `fetch-depth: 0`, `permissions: contents: write`.

**Inputs**

| Input        | Required | Default | Description |
|-------------|----------|---------|-------------|
| `tag_prefix` | No       | `v`     | Prefix for version tags (e.g. `v` → `v0.1.0`). |

**Outputs**

| Output | Description |
|--------|-------------|
| `tag`  | The new tag created (e.g. `v0.1.1`). |

**Example**

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
- uses: owner/github-actions/.github/actions/release-on-merge@v1
  id: release
# steps.release.outputs.tag
```

---

### docker-publish

Build a multi-platform image with Docker Buildx and push to Docker Hub. Uses GHA cache. Tag is derived from the event: release ref, manual `image_tag` input, or `sha-<short-sha>`.

**Caller job:** `checkout`. Secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`.

**Inputs**

| Input            | Required | Default                    | Description |
|------------------|----------|----------------------------|-------------|
| `image_name`     | Yes      | —                          | Image name (e.g. `my-app`). |
| `repo_prefix`    | Yes      | —                          | Registry/repo prefix (e.g. Docker Hub username). |
| `dockerfile_path`| No       | `./docker/Dockerfile`      | Path to Dockerfile. |
| `context`        | No       | `.`                        | Build context. |
| `platforms`      | No       | `linux/amd64,linux/arm64`  | Comma-separated platforms. |
| `image_tag`      | No       | —                          | Override tag (e.g. for workflow_dispatch). |

**Outputs**

| Output | Description |
|--------|-------------|
| `tag`  | Image tag that was pushed. |

**Example**

```yaml
- uses: actions/checkout@v4
- uses: owner/github-actions/.github/actions/docker-publish@v1
  with:
    image_name: organizr-tab-controller
    repo_prefix: expectedbehaviors
    dockerfile_path: ./docker/Dockerfile
    platforms: linux/amd64,linux/arm64
```

---

### helm-publish

Resolve version from the current GitHub Release (or latest), package the Helm chart with that version, set the image tag in `values.yaml` at a given path, and upload the tarball to the same release.

**Caller job:** `checkout`, `permissions: contents: write`. Uses `GITHUB_TOKEN`.

**Inputs**

| Input                  | Required | Default                         | Description |
|------------------------|----------|---------------------------------|-------------|
| `chart_path`           | No       | `helm`                          | Path to chart directory. |
| `chart_name`           | Yes      | —                               | Chart name (used for tarball, e.g. `my-chart`). |
| `values_image_tag_key` | Yes      | —                               | Dot path in values for image tag (e.g. `organizr-tab-controller.controllers.main.containers.main.image.tag`). First segment can contain hyphens. |
| `helm_repo_name`       | No       | `bjw-s`                         | Helm repo name for `helm dependency update`. |
| `helm_repo_url`        | No       | `https://bjw-s-labs.github.io/helm-charts` | Helm repo URL. |
| `release_tag`          | No       | —                               | Override release tag (e.g. for workflow_dispatch). |

**Outputs**

| Output         | Description |
|----------------|-------------|
| `tag`          | Release tag used. |
| `version`      | Version (tag without prefix). |
| `chart_tarball`| Tarball filename. |

**Example**

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
- uses: owner/github-actions/.github/actions/helm-publish@v1
  with:
    chart_path: helm
    chart_name: organizr-tab-controller
    values_image_tag_key: organizr-tab-controller.controllers.main.containers.main.image.tag
```

---

### release-notes

Resolve the release tag (from event or input), find the merged PR for that release, summarize the PR body with OpenAI into 2–4 bullet points, and set the GitHub Release body to that summary.

**Caller job:** `checkout`, `permissions: contents: write`. Secrets: `OPENAI_API_KEY` (required), `GITHUB_TOKEN`.

**Inputs**

| Input         | Required | Default        | Description |
|---------------|----------|----------------|-------------|
| `release_tag` | No       | —              | Override release tag (e.g. for workflow_dispatch). |
| `openai_model`| No       | `gpt-4o-mini`  | OpenAI model for summarization. |

**Outputs**

| Output   | Description |
|----------|-------------|
| `tag`    | Release tag updated. |
| `summary`| Summarized release notes text. |

**Example**

```yaml
- uses: actions/checkout@v4
- uses: owner/github-actions/.github/actions/release-notes@v1
  with:
    release_tag: ''   # optional override
```

---

## Versioning

Pin by tag (e.g. `@v1`) or SHA for stable builds. Use `@main` for latest; avoid in production.

## License

See repository license.
