#!/usr/bin/env bash
# Checks play-promote-inputs.sh, play-promote.jq, play-track-version.jq and
# play-promote-changes.sh. Run: bash .github/play-promote.test.sh
set -euo pipefail
dir="$(dirname "$0")"
failures=0

fail() { printf 'FAIL %s\n--- expected\n%s\n--- actual\n%s\n' "$1" "$2" "$3"; failures=$((failures + 1)); }

inputs() { # name, version, rollout, expected output ('' = must fail)
  local actual status=0
  actual="$(bash "$dir/play-promote-inputs.sh" "$2" "$3" 2>&1)" || status=$?
  if [ -z "$4" ]; then
    if [ "$status" -eq 0 ]; then fail "$1" '(exit 1)' "$actual"; fi
  elif [ "$status" -ne 0 ] || [ "$actual" != "$4" ]; then
    fail "$1" "$4" "$actual"
  fi
}

inputs 'valid version and rollout' v1.1.0 100 1.1.0
inputs 'smallest rollout' v10.20.30 1 10.20.30
inputs 'leading zero is decimal' v1.1.0 08 1.1.0
inputs 'no v' 1.1.0 100 ''
inputs 'two parts' v1.1 100 ''
inputs 'trailing text' 'v1.1.0; echo hi' 100 ''
inputs 'zero rollout' v1.1.0 0 ''
inputs 'over 100' v1.1.0 101 ''
inputs 'fraction' v1.1.0 50.5 ''
inputs 'empty rollout' v1.1.0 '' ''

track='{"track":"internal","releases":[
  {"name":"1.0.0 (181)","versionCodes":["181"],"status":"completed"},
  {"name":"1.1.0 (311)","versionCodes":["311"],"status":"completed",
   "releaseNotes":[{"language":"en-US","text":"- Bigger confetti"}]},
  {"name":"1.1.0 (312)","versionCodes":["312"],"status":"completed",
   "releaseNotes":[{"language":"en-US","text":"- Newest build"},{"language":"de-DE","text":"- Neuester Build"}]},
  {"name":"1.1.01 (400)","versionCodes":["400"],"status":"completed"}]}'

lookup() { # name, version name, track, rollout, expected JSON ('' = must fail)
  local actual status=0
  actual="$(jq -c --arg name "$2" --arg track "$3" --arg rollout "$4" -f "$dir/play-promote.jq" <<< "$track" 2>&1)" \
    || status=$?
  if [ -z "$5" ]; then
    if [ "$status" -eq 0 ]; then fail "$1" '(error)' "$actual"; fi
  elif [ "$status" -ne 0 ] || [ "$actual" != "$5" ]; then
    fail "$1" "$5" "$actual"
  fi
}

lookup 'full rollout, release without notes' 1.0.0 alpha 100 \
  '{"track":"alpha","releases":[{"name":"1.0.0 (181)","versionCodes":["181"],"status":"completed"}]}'
lookup 'newest build of a version, staged, notes in every language' 1.1.0 production 20 \
  '{"track":"production","releases":[{"name":"1.1.0 (312)","versionCodes":["312"],"status":"inProgress","userFraction":0.2,"releaseNotes":[{"language":"en-US","text":"- Newest build"},{"language":"de-DE","text":"- Neuester Build"}]}]}'
lookup 'missing version fails' 2.0.0 alpha 100 ''
lookup '1.1.0 does not match 1.1.01' 1.1.01 alpha 100 \
  '{"track":"alpha","releases":[{"name":"1.1.01 (400)","versionCodes":["400"],"status":"completed"}]}'
lookup 'partial version does not match' 1.1 alpha 100 ''

track='{"track":"internal"}'
lookup 'track without releases fails' 1.0.0 alpha 100 ''

current() { # name, track JSON, expected version name
  local actual
  actual="$(jq -r -f "$dir/play-track-version.jq" <<< "$2" 2>&1)" || true
  if [ "$actual" != "$3" ]; then fail "$1" "$3" "$actual"; fi
}

current 'newest completed release' '{"releases":[
  {"name":"1.1.4 (50)","versionCodes":["50"],"status":"completed"},
  {"name":"1.2.0 (60)","versionCodes":["60"],"status":"inProgress"},
  {"name":"1.0.0 (10)","versionCodes":["10"],"status":"completed"},
  {"name":"Hand upload","versionCodes":["99"],"status":"completed"}]}' 1.1.4
current 'staged rollout only' '{"releases":[{"name":"1.2.0 (60)","versionCodes":["60"],"status":"inProgress"}]}' 1.2.0
current 'drafts and halted releases do not count' '{"releases":[
  {"name":"1.2.0 (60)","versionCodes":["60"],"status":"draft"},
  {"name":"1.1.0 (40)","versionCodes":["40"],"status":"halted"}]}' ''
current 'empty track' '{"track":"alpha"}' ''

# play-promote-changes.sh on a scratch repository: v1.0.0, a squashed PR, a merged PR, v1.1.0.
repo="$(mktemp -d)"
changes_script="$(cd "$dir" && pwd)/play-promote-changes.sh"
(
  cd "$repo"
  git init -q -b main
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m 'first'
  git tag v1.0.0
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m 'feat: bigger confetti (#5)'
  git checkout -q -b topic
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m 'wip'
  git checkout -q main
  git -c user.name=t -c user.email=t@t merge -q --no-ff topic \
    -m 'Merge pull request #6 from o/topic' -m 'Add Ukrainian'
  git tag v1.1.0
  git tag v0.9.0 topic
)

changes() { # name, version, notes-since, track version name, expected output ('fail' = must fail)
  local actual status=0
  actual="$(cd "$repo" && bash "$changes_script" "$2" "$3" "$4" 2>/dev/null)" || status=$?
  if [ "$5" = fail ]; then
    if [ "$status" -eq 0 ]; then fail "$1" '(exit 1)' "$actual"; fi
  elif [ "$status" -ne 0 ] || [ "$actual" != "$5" ]; then
    fail "$1" "$5" "$actual"
  fi
}

changes 'from the track version, merge commits by their title' v1.1.0 '' 1.0.0 \
  $'* Add Ukrainian (#6)\n* feat: bigger confetti (#5)'
changes 'notes-since wins over the track version' v1.1.0 v1.0.0 1.1.0 \
  $'* Add Ukrainian (#6)\n* feat: bigger confetti (#5)'
changes 'same version on the track keeps the notes' v1.1.0 '' 1.1.0 ''
changes 'nothing on the track keeps the notes' v1.1.0 '' '' ''
changes 'missing start tag keeps the notes' v1.1.0 '' 0.1.0 ''
changes 'start not before the version keeps the notes' v1.0.0 v1.1.0 '' ''
changes 'start off the main line keeps the notes' v1.0.0 v0.9.0 '' ''
changes 'notes-since that is not a tag name fails' v1.1.0 'v1.0.0; echo hi' '' fail

if [ "$failures" -gt 0 ]; then
  echo "$failures promote check(s) failed"
  exit 1
fi
echo "Promote checks: all passed"
