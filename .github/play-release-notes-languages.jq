# Builds releaseNotes for edits.tracks.update. Args: $english (the en-US notes,
# already made plain by play-release-notes.jq), $answer (--slurpfile of DeepSeek's
# JSON object keyed by Play language code) and $listed (the languages of the app's
# store listings, edits.listings.list). Play rejects notes in a language without a
# listing, so only listed languages are sent. A translation that is not a non-empty
# text of 500 characters at most with Western digits is left out; en-US is always
# there. Used by play-bundle.yml; tested by play-release-notes.test.sh.
(if ($answer[0] | type) == "object" then $answer[0] else {} end) as $translations
| [{language: "en-US", text: $english}]
  + [$listed[] | select(. != "en-US") as $language
     | $translations[$language] | strings
     | gsub("\r"; "") | sub("^\\s+"; "") | sub("\\s+$"; "")
     | select(length > 0 and length <= 500 and (test("(?![0-9])\\p{Nd}") | not))
     | {language: $language, text: .}]
