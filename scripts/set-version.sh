#!/usr/bin/env bash

set -euo pipefail

update_lua_globals_version() {
  local tmp
  tmp=$(mktemp)
  sed -e "s/VERSION = \".*\"/VERSION = \"$VERSION\"/" ./lua/kikao/globals/init.lua > "$tmp" && mv "$tmp" ./lua/kikao/globals/init.lua
}

update_lua_globals_version
