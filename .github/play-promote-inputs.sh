#!/usr/bin/env bash
# Checks the play-promote.yml inputs: $1 version (v1.2.3), $2 rollout percent (1 to 100).
# Prints the version name without the v (1.2.3).
set -euo pipefail
if [[ ! "$1" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  echo "::error::Version '$1' is not v1.2.3"
  exit 1
fi
name="${BASH_REMATCH[1]}"
# 10# so a leading zero is not read as octal.
if [[ ! "$2" =~ ^[0-9]{1,3}$ ]] || (( 10#$2 < 1 || 10#$2 > 100 )); then
  echo "::error::Rollout '$2' is not a whole percent from 1 to 100"
  exit 1
fi
echo "$name"
