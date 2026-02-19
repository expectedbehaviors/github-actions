# Reusable GitHub Actions

Shared composite actions for CI/CD: publishing (Docker, Helm), release automation, and release notes. Use from any repo with minimal inputs.

## Usage

Reference by repo and path. Prefer a fixed ref (tag or SHA) for reproducibility:

```yaml
uses: owner/github-actions/.github/actions/<action-name>@v1   # or @main, @sha-...
with:
  # action inputs
```

Secrets must be **passed as inputs** from the calling workflow (e.g. `github_token: ${{ secrets.GITHUB_TOKEN }}`). Composite actions from another repo do not automatically receive the caller's secrets.

---

## Actions

### release-on-merge

Bump patch version from the latest `v*` tag and create a GitHub Release (tag + release). Use in a workflow that runs on push to `main` (with path filters as needed).

**Caller job:** `checkout` with `fetch-depth: 0`, `permissions: contents: write`.

**Inputs**

| Input         | Required | Default | Description |
|---------------|----------|---------|-------------|
| `github_token` | Yes     | —       | GitHub token for gh CLI (pass `secrets.GITHUB_TOKEN`). |
| `tag_prefix`  | No       | `v`     | Prefix for version tags (e.g. `v` → `v0.1.0`). |

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
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

---

### docker-publish

Build a multi-platform image with Docker Buildx and push to Docker Hub. Uses GHA cache. Tag is derived from the event: release ref, manual `image_tag` input, or `sha-<short-sha>`.

**Caller job:** `checkout`. Pass `docker_username` and `docker_token` from your repo secrets.

**Inputs**

| Input            | Required | Default                    | Description |
|------------------|----------|----------------------------|-------------|
| `image_name`     | Yes      | —                          | Image name (e.g. `my-app`). |
| `repo_prefix`    | Yes      | —                          | Registry/repo prefix (e.g. Docker Hub username). |
| `docker_username`| Yes      | —                          | Docker Hub username (pass `secrets.DOCKERHUB_USERNAME`). |
| `docker_token`   | Yes      | —                          | Docker Hub token (pass `secrets.DOCKERHUB_TOKEN`). |
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
    docker_username: ${{ secrets.DOCKERHUB_USERNAME }}
    docker_token: ${{ secrets.DOCKERHUB_TOKEN }}
```

---

### helm-publish

Resolve version from the current GitHub Release (or latest), package the Helm chart with that version, set the image tag in `values.yaml` at a given path, and upload the tarball to the same release. By default also enables GitHub Pages (branch `gh-pages`) when needed and publishes the chart index there so the Helm repo is available at `https://<owner>.github.io/<repo>`.

**Caller job:** `checkout`, `permissions: contents: write`. Pass `github_token`.

**Inputs**

| Input                  | Required | Default                         | Description |
|------------------------|----------|---------------------------------|-------------|
| `github_token`         | Yes      | —                               | GitHub token for gh CLI (pass `secrets.GITHUB_TOKEN`). |
| `chart_path`           | No       | `helm`                          | Path to chart directory. |
| `chart_name`           | Yes      | —                               | Chart name (used for tarball, e.g. `my-chart`). |
| `values_image_tag_key` | Yes      | —                               | Dot path in values for image tag (e.g. `organizr-tab-controller.controllers.main.containers.main.image.tag`). First segment can contain hyphens. |
| `helm_repo_name`       | No       | `bjw-s`                         | Helm repo name for `helm dependency update`. |
| `helm_repo_url`        | No       | `https://bjw-s-labs.github.io/helm-charts` | Helm repo URL. |
| `release_tag`          | No       | —                               | Override release tag (e.g. for workflow_dispatch). |
| `publish_to_pages`     | No       | **`true`**                     | Enable GitHub Pages (gh-pages) when needed and publish chart index. Set to `false` to skip. |

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
    github_token: ${{ secrets.GITHUB_TOKEN }}
    chart_name: organizr-tab-controller
    values_image_tag_key: organizr-tab-controller.controllers.main.containers.main.image.tag
```

---

### release-notes

Resolve the release tag (from event or input), find the merged PR for that release, summarize the PR body with OpenAI into 2–4 bullet points, and set the GitHub Release body to that summary.

**Caller job:** `checkout`, `permissions: contents: write`. Pass `openai_api_key` and `github_token`.

**Inputs**

| Input            | Required | Default        | Description |
|------------------|----------|----------------|-------------|
| `openai_api_key` | Yes      | —              | OpenAI API key (pass `secrets.OPENAI_API_KEY`). |
| `github_token`  | Yes      | —              | GitHub token for gh CLI (pass `secrets.GITHUB_TOKEN`). |
| `release_tag`    | No       | —              | Override release tag (e.g. for workflow_dispatch). |
| `openai_model`   | No       | `gpt-4o-mini`  | OpenAI model for summarization. |

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
    openai_api_key: ${{ secrets.OPENAI_API_KEY }}
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

---

### rewrite-commit-authors

Rewrite every commit in the repository to use new author and committer name/email (e.g. to purge PII from history). Uses `git-filter-repo`; rewrites history and optionally force-pushes to the remote. **Destructive:** all commit hashes change; clones and open PRs will be invalid.

**Caller job:** `checkout` with **`fetch-depth: 0`** (full history), `permissions: contents: write`. Pass `github_token`.

**Inputs**

| Input             | Required | Default | Description |
|-------------------|----------|---------|-------------|
| `github_token`   | Yes      | —       | GitHub token for re-adding remote and push (pass `secrets.GITHUB_TOKEN`). |
| `author_name`    | Yes      | —       | New author name for every commit (e.g. `Expected Behaviors`). |
| `author_email`   | Yes      | —       | New author email for every commit (e.g. `noreply@example.github.io`). |
| `committer_name` | No       | (same as author) | New committer name. |
| `committer_email`| No       | (same as author) | New committer email. |
| `branch`         | No       | `main`  | Branch to rewrite and push. |
| `push`           | No       | `true`  | If `true`, re-add origin and force-push after rewrite. |

**Example (reusable workflow in another repo — no inputs; author = whoever runs it)**

```yaml
jobs:
  call-rewrite:
    uses: expectedbehaviors/github-actions/.github/workflows/rewrite-commit-authors.yml@main
    secrets: inherit
```

**Example (calling the composite action directly with explicit author)**

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
- uses: owner/github-actions/.github/actions/rewrite-commit-authors@v1
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    author_name: 'Expected Behaviors'
    author_email: 'noreply@expectedbehaviors.github.io'
```

**Adding to all Expected Behaviors org repos (no PII in history)**

Goal: every org repo can run "Rewrite commit authors" so anyone can scrub commit author/committer PII from history. Author is set to whoever runs the workflow (GitHub username + noreply email).

1. **Roles:** The **reusable workflow** (`.github/workflows/rewrite-commit-authors.yml`) is the callee—other repos call it and it runs in their context. It does checkout, sets author from `github.actor`, then calls the **composite action** (`.github/actions/rewrite-commit-authors/`), which contains the actual rewrite logic. Each repo only needs a small caller workflow (snippet below) that triggers the reusable workflow.

2. **Automated sync (recommended):** A workflow in this repo syncs the caller to all org repos. Run it manually or on a schedule.
   - **Workflow:** [.github/workflows/sync-rewrite-commit-authors-to-org.yml](.github/workflows/sync-rewrite-commit-authors-to-org.yml) — **Actions → "Sync rewrite-commit-authors to org repos" → Run workflow.**
   - **Required secret:** `ORG_REPO_TOKEN` — a PAT (or fine-grained token) with **repo** scope for the org, so the workflow can push to other repos. Add it in **Settings → Secrets and variables → Actions** in this repo. Without it, the sync job fails with a clear error.
   - **How to create the token:**
     - **Classic PAT:** GitHub → **Settings** (your profile) → **Developer settings** → **Personal access tokens** → **Tokens (classic)** → **Generate new token**. Name it (e.g. `github-actions-org-sync`). Under scopes, check **repo** (full control of private repositories). Generate and copy the token once (it won’t be shown again). In the **github-actions** repo: **Settings → Secrets and variables → Actions** → **New repository secret** → Name: `ORG_REPO_TOKEN`, Value: paste the token.
     - **Fine-grained PAT (narrower):** **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**. Repository access: **Only select repositories** → choose the org repos you want the sync to touch, or **All repositories** for the org. Permissions: **Contents** = Read and write. Generate, copy, then add as `ORG_REPO_TOKEN` in the repo secrets.
   - **Inputs:** `org` (default `expectedbehaviors`), `dry_run` (if true, only list repos and report; no push). On schedule (weekly Monday 02:00 UTC), the default org is used.
   - After the first successful run, every org repo will have `.github/workflows/rewrite-commit-authors.yml` and can run "Rewrite commit authors (PII purge)" from the Actions tab.

3. **Per-repo file (manual):** In a single org repo, add `.github/workflows/rewrite-commit-authors.yml` with:
   ```yaml
   name: Rewrite commit authors (PII purge)
   on:
     workflow_dispatch:
   jobs:
     call-rewrite:
       uses: expectedbehaviors/github-actions/.github/workflows/rewrite-commit-authors.yml@main
       secrets: inherit
   ```

---

## Versioning

Pin by tag (e.g. `@v1`) or SHA for stable builds. Use `@main` for latest; avoid in production.

## License

See repository license.
