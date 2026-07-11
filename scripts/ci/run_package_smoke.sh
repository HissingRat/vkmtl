#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture="$repo_root/tests/package_consumer"
cache_dir="$repo_root/.zig-cache"

cd "$fixture"
zig build --cache-dir "$cache_dir" --fetch
zig build --cache-dir "$cache_dir" test --summary all

echo "package_consumer_smoke=passed"
