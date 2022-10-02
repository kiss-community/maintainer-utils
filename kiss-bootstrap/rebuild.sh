#!/bin/sh

set -eu

DUMMY_PACKAGE_DIR="/tmp/pkg/__dummy"
export KISS_PATH="${DUMMY_PACKAGE_DIR%/*}"

cd /var/db/kiss/installed

set -- *

kiss new "$DUMMY_PACKAGE_DIR" 1
printf '%s\n' "$@" > "$DUMMY_PACKAGE_DIR/depends"

KISS_PROMPT=0 kiss build "${DUMMY_PACKAGE_DIR##*/}" "$@"
