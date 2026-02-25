# Release on merge

Creates a version tag and GitHub Release on push to `main`. Version bump is **patch** by default; optional **auto** mode uses commit keywords and/or diff size.

## Version bump modes

| `version_bump` | Behavior |
|----------------|----------|
| `patch` (default) | Always bump patch (e.g. 1.0.0 → 1.0.1). |
| `minor` | Always bump minor (1.0.0 → 1.1.0). |
| `major` | Always bump major (1.0.0 → 2.0.0). |
| `auto` | Inspect commits since last tag: **major** if any `major_keywords` match, else **minor** if any `minor_keywords` match or if `diff_minor_threshold` is met, else **patch**. |

## Auto mode inputs (when `version_bump: auto`)

- **major_keywords** — Comma-separated substrings in merge commit messages (e.g. `BREAKING CHANGE`, `breaking:`). First match wins.
- **minor_keywords** — Same for minor (e.g. `feat:`, `minor:`, `feature:`).
- **diff_minor_threshold** — If no keyword matches and (insertions + deletions) since last tag ≥ this value, bump minor. Set to `0` to disable. Example: `200` for “larger change = minor”.

## Example (workflow)

```yaml
- uses: expectedbehaviors/github-actions/.github/actions/release-on-merge@main
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    tag_prefix: "v"
    initial_version: "1.0.0"
    version_bump: "auto"
    minor_keywords: "feat:,minor:,feature:"
    major_keywords: "BREAKING CHANGE,breaking:"
    diff_minor_threshold: "150"
```

Existing workflows that omit `version_bump` keep current behavior (patch).
