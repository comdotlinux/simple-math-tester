# Input: the internal track (edits.tracks.get). Args: $name (1.2.3), $track (alpha
# or production), $rollout (1 to 100). Output: the body for edits.tracks.update of
# $track with the internal release named "$name (<versionCode>)", its notes kept.
[.releases[]? | select(.name | startswith($name + " ("))]
| if length == 0 then error("No release named \"\($name) (...)\" on the internal track")
  # A re-run of the tag build uploads a second build with the same name: take the newest.
  else max_by(.versionCodes[0] | tonumber) end
| ($rollout | tonumber) as $percent
| {track: $track, releases: [
    {name, versionCodes}
    + (if $percent >= 100 then {status: "completed"}
       else {status: "inProgress", userFraction: ($percent / 100)} end)
    + (if .releaseNotes then {releaseNotes} else {} end)
  ]}
