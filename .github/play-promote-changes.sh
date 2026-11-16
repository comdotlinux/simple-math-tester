#!/usr/bin/env bash
# Lists the changes a promotion brings, one "* <pull request title>" line per commit
# on main: $1 the promoted tag (v1.2.3), $2 the notes-since input (a tag, or empty),
# $3 the version name on the target track before the promotion (1.2.0, or empty).
# The list starts at $2, else at v$3. Prints nothing (keep the notes the release
# has) when there is no start, the start is the promoted tag, the start tag is
# missing or not an ancestor of $1. Used by play-promote.yml; tested by
# play-promote.test.sh. Needs the tags and history (checkout fetch-depth 0).
set -euo pipefail
version="$1"
since="$2"
current="$3"
if [ -n "$since" ]; then
  if [[ ! "$since" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "::error::notes-since '$since' is not v1.2.3" >&2
    exit 1
  fi
  start="$since"
elif [ -n "$current" ]; then
  start="v$current"
else
  echo "::notice::No version on the target track and no notes-since: the release keeps its notes" >&2
  exit 0
fi
if [ "$start" = "$version" ]; then
  echo "::notice::$version is already on the target track: the release keeps its notes (set notes-since to rewrite them)" >&2
  exit 0
fi
if ! git rev-parse -q --verify "refs/tags/$start" > /dev/null; then
  echo "::warning::Tag $start not found: the release keeps its notes" >&2
  exit 0
fi
if ! git merge-base --is-ancestor "refs/tags/$start" "refs/tags/$version"; then
  echo "::warning::$start is not before $version: the release keeps its notes" >&2
  exit 0
fi
echo "::notice::Release notes cover $start..$version" >&2
# Pull requests merged with a merge commit keep their title in the body.
git log --first-parent --format='%s%x1f%b%x1e' "refs/tags/$start..refs/tags/$version" \
  | while IFS=$'\x1f' read -r -d $'\x1e' subject body; do
      subject="${subject#$'\n'}"
      if [[ "$subject" =~ ^Merge\ pull\ request\ (#[0-9]+)\  ]]; then
        title="$(printf '%s\n' "$body" | sed -n '/[^[:space:]]/{p;q}')"
        subject="${title:-$subject} (${BASH_REMATCH[1]})"
      fi
      printf '* %s\n' "$subject"
    done
