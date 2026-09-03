#!/usr/bin/env bash
#
# Package the current git checkout (minus .distignore entries) and publish
# it to a WordPress plugin SVN repository's trunk + a version tag.
#
# Required env vars:
#   SVN_URL       Base URL of the plugin's SVN repo (trunk/tags/assets live under it).
#                 e.g. https://plugins.svn.wordpress.org/git-cd-testing
#                 or   file:///tmp/local-wp-svn/git-cd-testing  (local testing)
#   VERSION       Version to tag, e.g. 1.0.0
#
# Optional env vars:
#   SVN_USERNAME, SVN_PASSWORD   Credentials (omit for a local file:// repo)
#   PLUGIN_DIR                   Source directory to package (default: repo root)

set -euo pipefail

: "${SVN_URL:?SVN_URL is required}"
: "${VERSION:?VERSION is required}"

PLUGIN_DIR="${PLUGIN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SVN_AUTH=()
if [[ -n "${SVN_USERNAME:-}" ]]; then
  SVN_AUTH=(--username "$SVN_USERNAME" --password "$SVN_PASSWORD" --no-auth-cache --non-interactive)
fi

WORK_DIR="$(mktemp -d)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR" "$BUILD_DIR"' EXIT

echo "==> Checking out SVN working copy from $SVN_URL"
svn checkout "${SVN_AUTH[@]}" "$SVN_URL" "$WORK_DIR" --depth immediates
mkdir -p "$WORK_DIR/trunk" "$WORK_DIR/tags" "$WORK_DIR/assets"
svn update "${SVN_AUTH[@]}" "$WORK_DIR/trunk" --set-depth infinity
svn update "${SVN_AUTH[@]}" "$WORK_DIR/assets" --set-depth infinity
svn update "${SVN_AUTH[@]}" "$WORK_DIR/tags" --set-depth infinity

echo "==> Building clean plugin copy (applying .distignore)"
RSYNC_EXCLUDES=()
if [[ -f "$PLUGIN_DIR/.distignore" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    RSYNC_EXCLUDES+=(--exclude "$line")
  done < "$PLUGIN_DIR/.distignore"
fi
rsync -av "${RSYNC_EXCLUDES[@]}" "$PLUGIN_DIR/" "$BUILD_DIR/" >/dev/null

echo "==> Syncing into trunk/"
rsync -av --delete --exclude ".svn" "$BUILD_DIR/" "$WORK_DIR/trunk/" >/dev/null

echo "==> Staging trunk changes"
svn add --force "$WORK_DIR/trunk" -q --auto-props --parents --depth infinity
svn status "$WORK_DIR/trunk" | { grep '^!' || true; } | awk '{print $2}' | xargs -r svn delete -q

if [[ -d "$WORK_DIR/tags/$VERSION" ]]; then
  echo "==> Tag $VERSION already exists, skipping tag creation"
else
  echo "==> Creating tag $VERSION from trunk"
  svn copy "$WORK_DIR/trunk" "$WORK_DIR/tags/$VERSION"
fi

if svn status "$WORK_DIR" | grep -q .; then
  echo "==> Committing release $VERSION"
  svn commit "${SVN_AUTH[@]}" "$WORK_DIR" -m "Release $VERSION"
else
  echo "==> Nothing changed, nothing to commit"
fi

echo "==> Done"
