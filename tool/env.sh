#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PATH="$ROOT/.tooling/flutter/bin:$PATH"
export PUB_CACHE="$ROOT/.tooling/pub-cache"

if [[ -d "$ROOT/.tmp_pub_cache" && ! -d "$PUB_CACHE" ]]; then
  mkdir -p "$(dirname "$PUB_CACHE")"
  mv "$ROOT/.tmp_pub_cache" "$PUB_CACHE"
fi

mkdir -p "$PUB_CACHE"

if [[ ! -e "$ROOT/.tmp_pub_cache" ]]; then
  ln -s "$PUB_CACHE" "$ROOT/.tmp_pub_cache"
fi

echo "DayPick Flutter env loaded:"
echo "  flutter:   $ROOT/.tooling/flutter/bin/flutter"
echo "  PUB_CACHE: $PUB_CACHE"
