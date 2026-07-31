"""Render the upstream chart pinned in argocd/*.yaml against this repo's values files.

Values-only repos carry no Chart.yaml, so `helm lint` and `helm template` on the repo
root cannot work. The equivalent proof for them is: resolve the chart and version that
Argo CD is pinned to, then template it with the values this repo actually supplies.

Manifests are read through `yq` rather than PyYAML so the action depends only on tools
the runner image already ships.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

ARGOCD_PATH = Path(os.environ.get("ARGOCD_PATH") or "argocd")
VALUES_PATH = Path(os.environ.get("VALUES_PATH") or ".")
RELEASE_NAME = os.environ.get("RELEASE_NAME") or "release"


def run(command):
    print(f"\t$ {' '.join(command)}", flush=True)
    subprocess.run(command, check=True)


def read_manifest(path):
    result = subprocess.run(
        ["yq", "-o=json", "-I=0", ".", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    document = json.loads(result.stdout)
    if not isinstance(document, dict):
        sys.exit(f"{path}: expected a mapping at the top level, got {type(document).__name__}")
    return document


def manifest_paths():
    if not ARGOCD_PATH.is_dir():
        sys.exit(f"values-only validation needs {ARGOCD_PATH}/ but that directory does not exist")
    paths = sorted(p for p in ARGOCD_PATH.iterdir() if p.suffix in (".yml", ".yaml"))
    if not paths:
        sys.exit(f"no Argo CD app manifests found in {ARGOCD_PATH}/")
    return paths


def resolve_values_files(document, manifest_path):
    """Map helmValueFiles entries such as $values/values.yaml onto local paths."""
    entries = document.get("helmValueFiles") or document.get("gitValueFiles") or ["values.yaml"]
    resolved = []
    for entry in entries:
        text = str(entry)
        relative = text.split("/", 1)[-1] if text.startswith("$") else text
        candidate = VALUES_PATH / relative
        if not candidate.is_file():
            sys.exit(f"{manifest_path}: values file {candidate} is referenced but not present in the repo")
        resolved.append(candidate)
    return resolved


rendered_any = False
for manifest_path in manifest_paths():
    document = read_manifest(manifest_path)
    # `chart` names the Argo CD Application. It usually matches the published chart
    # name as well, but where the two differ `helmChart` carries the real chart name.
    chart = document.get("helmChart") or document.get("chart")
    repo_url = document.get("helmRepoURL")
    revision = document.get("helmChartRevision")

    if not repo_url or not revision:
        print(f"\t{manifest_path}: git-only app (no helmRepoURL/helmChartRevision), nothing to render", flush=True)
        continue
    if not chart:
        sys.exit(f"{manifest_path}: helmRepoURL is set but neither helmChart nor chart is set")

    values_files = resolve_values_files(document, manifest_path)
    repo_alias = f"validate-{chart}"

    print(f"\n\t{manifest_path}: rendering {chart} {revision} from {repo_url}", flush=True)
    run(["helm", "repo", "add", repo_alias, repo_url])
    run(["helm", "repo", "update", repo_alias])

    command = ["helm", "template", RELEASE_NAME, f"{repo_alias}/{chart}", "--version", str(revision)]
    for values_file in values_files:
        command.extend(["-f", str(values_file)])
    run(command)
    rendered_any = True

if not rendered_any:
    sys.exit(
        "no Argo CD app manifest pinned a published chart, so nothing was validated. "
        "Set values_only: false on the caller, or add helmRepoURL/helmChartRevision to the manifest."
    )

print("\nvalues-only validation: PASSED", flush=True)
