#!/usr/bin/env bash
# Writes the build stamp into a web build's service_worker.js, so browsers see a
# new worker for every build. Usage: tool/stamp_service_worker.sh app/build/web
set -euo pipefail
dir="$1"
stamp="$(sha256sum "$dir/precache_manifest.json" | cut -c1-8)"
sed -i "s/^const BUILD = .*/const BUILD = '$stamp';/" "$dir/service_worker.js"
grep -qx "const BUILD = '$stamp';" "$dir/service_worker.js"
echo "Stamped $dir/service_worker.js with build $stamp"
