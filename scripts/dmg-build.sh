#!/usr/bin/env bash

set -euv

export SCRIPT_BASE=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
export BUILD_BASE="${SCRIPT_BASE}/../.build"
export APP_JSON="${APP_JSON:-${SCRIPT_BASE}/octahe.app.json}"

# Install npm from brew.
brew install npm || (brew link --overwrite node && brew install npm)

# Install appdmg.
npm install -g appdmg

# Ensure the build directory exists.
if [ -d ./build ]; then
  mkdir -p "${BUILD_BASE}"
fi

# If the install dmg exists remove it before rebuilding.
if [ -f "${BUILD_BASE}/octahe-install.dmg" ]; then
  rm "${BUILD_BASE}/octahe-install.dmg"
fi

appdmg ${APP_JSON} "${BUILD_BASE}/octahe-install.dmg"
