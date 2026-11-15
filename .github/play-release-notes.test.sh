#!/usr/bin/env bash
# Checks play-release-notes.jq and play-release-notes-languages.jq.
# Run: bash .github/play-release-notes.test.sh
set -euo pipefail
filter="$(dirname "$0")/play-release-notes.jq"
failures=0

check() { # name, input, expected
  local actual
  actual="$(jq -nr --arg notes "$2" -f "$filter")"
  if [ "$actual" != "$3" ]; then
    printf 'FAIL %s\n--- expected\n%s\n--- actual\n%s\n' "$1" "$3" "$actual"
    failures=$((failures + 1))
  fi
}

check 'plain lines stay' $'First test release.\n- Hints and a sprint.' \
  $'First test release.\n- Hints and a sprint.'

check 'markdown and generated notes become plain text' \
  $'## What\'s Changed\r\n* **Bigger** confetti by @someone in https://github.com/o/r/pull/31\r\n* See [the docs](https://x.y/z) and `code`\r\n\r\n<!-- note -->\r\n**Full Changelog**: https://github.com/o/r/compare/v1.0.0...v1.0.1' \
  $'What\'s Changed\n- Bigger confetti\n- See the docs and code'

check 'bot authors are removed too' \
  $'* Bump jq by @dependabot[bot] in https://github.com/o/r/pull/40' \
  '- Bump jq'

check 'empty input gives empty notes' '' ''

long="$(printf 'x%.0s' {1..300})"
check 'stops before the line that passes 500' $'short line\n'"$long"$'\n'"$long"$'\nlast' \
  $'short line\n'"$long"

check 'a line exactly at 500 fits' "$(printf 'y%.0s' {1..500})" "$(printf 'y%.0s' {1..500})"

umlauts="$(printf 'ä%.0s' {1..499})"
check 'counts characters, not bytes' "$umlauts"$'\nab' "$umlauts"

languages="$(dirname "$0")/play-release-notes-languages.jq"

notes() { # name, DeepSeek answer, listed languages, expected releaseNotes JSON
  local actual
  actual="$(jq -nc --arg english '- New' --slurpfile answer <(printf '%s' "$2") --argjson listed "$3" -f "$languages")"
  if [ "$actual" != "$4" ]; then
    printf 'FAIL %s\n--- expected\n%s\n--- actual\n%s\n' "$1" "$4" "$actual"
    failures=$((failures + 1))
  fi
}

notes 'listed translations are added, English stays first' \
  '{"en-US":"ignored","de-DE":" - Neu\r\n","fr-FR":"- Nouveau"}' '["fr-FR","en-US","de-DE"]' \
  '[{"language":"en-US","text":"- New"},{"language":"fr-FR","text":"- Nouveau"},{"language":"de-DE","text":"- Neu"}]'
notes 'unlisted languages are left out' '{"pl-PL":"- Nowe"}' '["en-US"]' \
  '[{"language":"en-US","text":"- New"}]'
notes 'empty, non-text, too long and non-Western digit translations are left out' \
  "{\"de-DE\":\" \",\"ro\":12,\"hi-IN\":\"स्तर १\",\"fr-FR\":\"$(printf 'é%.0s' {1..501})\",\"ta-IN\":\"$(printf 'é%.0s' {1..500})\"}" \
  '["de-DE","ro","hi-IN","fr-FR","ta-IN"]' \
  "[{\"language\":\"en-US\",\"text\":\"- New\"},{\"language\":\"ta-IN\",\"text\":\"$(printf 'é%.0s' {1..500})\"}]"
notes 'no answer gives English only' '' '["de-DE"]' '[{"language":"en-US","text":"- New"}]'
notes 'an answer that is not an object gives English only' '"text"' '["de-DE"]' \
  '[{"language":"en-US","text":"- New"}]'

if [ "$failures" -gt 0 ]; then
  echo "$failures release notes check(s) failed"
  exit 1
fi
echo "Release notes filter: all checks passed"
