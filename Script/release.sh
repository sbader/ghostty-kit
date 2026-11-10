#!/bin/bash
# Publishes the release for the pushed Ghostty.ref and Ghostty.build through
# release.yml and waits for it.

set -euo pipefail

cd "$(dirname "$0")/.."

REPO=sbader/ghostty-kit
TAG=$(./Script/storage-tag.sh)

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "[!] $TAG is already released; bump Ghostty.build to rebuild"
    exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
git fetch -q origin "$BRANCH"
if [ -n "$(git status --porcelain)" ] || [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$BRANCH")" ]; then
    echo "[!] commit and push before releasing"
    exit 1
fi

# Watches the run this dispatch created, not an older one.
SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
gh workflow run release.yml --repo "$REPO" --ref "$BRANCH"
RUN_ID=
for _ in $(seq 30); do
    RUN_ID=$(gh run list --repo "$REPO" --workflow release.yml --event workflow_dispatch --limit 5 \
        --json databaseId,createdAt --jq "[.[] | select(.createdAt >= \"$SINCE\")][0].databaseId // empty")
    [ -n "$RUN_ID" ] && break
    sleep 2
done
if [ -z "$RUN_ID" ]; then
    echo "[!] no release.yml run appeared"
    exit 1
fi
echo "[*] https://github.com/$REPO/actions/runs/$RUN_ID"
gh run watch "$RUN_ID" --repo "$REPO" --exit-status
gh release view "$TAG" --repo "$REPO" >/dev/null
echo "[*] released $TAG"
