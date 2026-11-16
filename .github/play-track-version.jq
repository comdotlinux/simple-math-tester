# Input: a Play track (edits.tracks.get). Output: the version name (1.2.3) of the
# release its users have, from the release name "1.2.3 (<versionCode>)": the newest
# completed release, else the newest one in a staged rollout; "" when there is none.
# Used by play-promote.yml; tested by play-promote.test.sh.
[.releases[]? | select(.status == "completed" or .status == "inProgress")
 | {status, code: (.versionCodes[0] | tonumber), name: (.name | capture("^(?<v>[0-9]+\\.[0-9]+\\.[0-9]+) \\(").v? // null)}
 | select(.name)]
| (map(select(.status == "completed")) | if length > 0 then . else null end) // .
| if length == 0 then "" else max_by(.code).name end
