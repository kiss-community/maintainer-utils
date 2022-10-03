#!/bin/sh

set -eu

get_depends() {
	echo "$1"

	DEPFILE="/var/db/kiss/installed/$1/depends"

	[ -f "$DEPFILE" ] || return

	while read -r dep deptype; do
    	[ ! "$deptype" = "make" ] && get_depends "$dep"
    done < "$DEPFILE"
}

DUMMY_PACKAGE_DIR="/tmp/pkg/__dummy"
FINAL_PKGS_FILE="/tmp/depends"

export KISS_PATH="${DUMMY_PACKAGE_DIR%/*}"

cd /var/db/kiss/installed

set -- *

kiss new "$DUMMY_PACKAGE_DIR" 1
printf '%s\n' "$@" > "$DUMMY_PACKAGE_DIR/depends"

KISS_PROMPT=0 kiss build "${DUMMY_PACKAGE_DIR##*/}" "$@"

final="$(
	while read -r pkg; do
		get_depends "$pkg"
	done < "$FINAL_PKGS_FILE" | sort -u
)"

# Remove unneeded packages, such as make deps
for pkg; do
	for search in $final; do
    	[ "$search" = "$pkg" ] && continue 2
	done

	KISS_FORCE=1 kiss remove "$pkg"
done
