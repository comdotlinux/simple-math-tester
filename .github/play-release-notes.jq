# Turns a GitHub release text ($notes) into Play release notes: plain text,
# whole lines only, 500 characters at most (Play's limit per language).
# Used by play-bundle.yml; tested by play-release-notes.test.sh.
def plain:
  gsub("\r"; "")
  | gsub("<[^>]*>"; "")                                  # HTML tags and comments
  | gsub("\\[(?<text>[^\\]]*)\\]\\([^)]*\\)"; "\(.text)")  # [text](url) -> text
  | gsub(" by @[A-Za-z0-9-]+ in https?://[^ \\n]+"; "")     # "by @user in <PR>" from generated notes
  | gsub("https?://[^ \\n]+"; "")                           # bare links
  | gsub("\\*\\*|__|~~|`"; "");                          # bold, strike-through, code
def tidy:
  sub("^ *#+ *"; "")                                     # heading marks
  | sub("^ *[*+-] +"; "- ")                              # bullets
  | sub(" +$"; "");

[$notes | plain | split("\n")[] | tidy
 | select(length > 0 and (startswith("Full Changelog") | not))]
# Whole lines until the next one would pass 500 characters, then stop.
| reduce .[] as $line ({text: "", full: false};
    if .full then .
    else (if .text == "" then $line else .text + "\n" + $line end) as $next
      | if ($next | length) <= 500 then .text = $next else .full = true end
    end)
| .text
