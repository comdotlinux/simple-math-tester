#!/usr/bin/env bash
# Writes Play release notes from a list of changes: $1 the changes (GitHub's
# automatic notes, or one "* <title>" line per pull request), $2 the output folder.
# Writes $2/play-notes.txt (English, plain, 500 characters at most) and
# $2/ai-answer.json (translations by Play language code, {} when there are none).
# DeepSeek writes a 2 to 5 line summary of the changes; without DEEPSEEK_API_KEY,
# or when the call fails, the changes themselves are used. Either way
# play-release-notes.jq makes them plain, whole lines, 500 characters at most. A
# second call translates a DeepSeek summary into every language of play/listing/.
# A missing translation never fails. Used by play-bundle.yml and play-promote.yml;
# the caller sends the valid translations with play-release-notes-languages.jq.
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
changes="$1"
out="$2"
model="${DEEPSEEK_MODEL:-deepseek-flash}"
source="$changes"
if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
  jq -n --arg model "$model" --rawfile notes "$changes" '{
    model: $model, stream: false, temperature: 0.3, max_tokens: 300,
    # Thinking is on by default and spends max_tokens before any answer.
    thinking: {type: "disabled"},
    messages: [
      {role: "system", content: "You write Google Play release notes for Simple Math Tester, a math practice app for children. You get the merged pull requests of a release. Write 2 to 5 short lines in plain English for parents and children, each starting with \"- \", about changes they can see or feel. Leave out tests, CI, build, docs and refactoring. No Markdown, links, names or version numbers. At most 450 characters in total. If nothing is visible to users, write exactly: - Small fixes and improvements."},
      {role: "user", content: $notes}
    ]}' > "$out/ai-request.json"
  if curl -sS --fail-with-body --max-time 60 https://api.deepseek.com/chat/completions \
      -H "Authorization: Bearer $DEEPSEEK_API_KEY" -H 'Content-Type: application/json' \
      --data @"$out/ai-request.json" > "$out/ai-response.json" \
    && jq -er '.choices[0].message.content | select(length > 0)' "$out/ai-response.json" \
      > "$out/ai-notes.txt"; then
    source="$out/ai-notes.txt"
  else
    reason="$(jq -r '.error.message // .choices[0].finish_reason // empty' "$out/ai-response.json" 2>/dev/null || true)"
    echo "::warning::DeepSeek summary failed (${reason:-no response}); Play gets the list of changes"
  fi
fi
jq -nr --rawfile notes "$source" -f "$dir/play-release-notes.jq" > "$out/play-notes.txt"
echo "Play release notes:"
cat "$out/play-notes.txt"
# Translations of the summary by Play language code, from a second call so a
# failed translation never costs the English summary.
echo '{}' > "$out/ai-answer.json"
# || true: no translations yet means nothing to translate.
languages="$(cd "$dir/../play/listing" && ls -- *.json | sed 's/\.json$//' \
  | { grep -vxE 'en-US|translation_sources' || true; } | paste -sd, -)"
if [ "$source" = "$out/ai-notes.txt" ] && [ -n "$languages" ]; then
  jq -n --arg model "$model" --arg languages "$languages" \
    --rawfile notes "$out/play-notes.txt" '{
    model: $model, stream: false, temperature: 0.2, max_tokens: 4000,
    thinking: {type: "disabled"},
    response_format: {type: "json_object"},
    messages: [
      {role: "system", content: ("You translate Google Play release notes of Simple Math Tester, a math practice app for children, from English into each of these Google Play languages: " + $languages + ". Keep the same lines, each starting with \"- \", in simple words a child understands. Keep the name Simple Math Tester. Digits are always Western 0-9. At most 450 characters per language. Answer with one JSON object that maps each language code to its notes, nothing else.")},
      {role: "user", content: $notes}
    ]}' > "$out/ai-translate-request.json"
  if curl -sS --fail-with-body --max-time 120 https://api.deepseek.com/chat/completions \
      -H "Authorization: Bearer $DEEPSEEK_API_KEY" -H 'Content-Type: application/json' \
      --data @"$out/ai-translate-request.json" > "$out/ai-translate-response.json" \
    && jq -e '.choices[0].message.content | fromjson | objects' "$out/ai-translate-response.json" \
      > "$out/ai-translations.json"; then
    cp "$out/ai-translations.json" "$out/ai-answer.json"
  else
    reason="$(jq -r '.error.message // .choices[0].finish_reason // empty' "$out/ai-translate-response.json" 2>/dev/null || true)"
    echo "::warning::DeepSeek translation of the notes failed (${reason:-no response}); Play gets English notes only"
  fi
fi
