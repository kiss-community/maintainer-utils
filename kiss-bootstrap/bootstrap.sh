#!/bin/sh

BASEDIR="${0%/*}"

. "$BASEDIR/conf"

set -eu

: "${KBOOTSTRAP_KISS_PATH:?}"
: "${KBOOTSTRAP_PACKAGES:?}"
: "${KBOOTSTRAP_CFLAGS:=-march=x86-64 -mtune=generic -pipe -Os}"
: "${KBOOTSTRAP_CXXFLAGS:=-march=x86-64 -mtune=generic -pipe -Os}"
: "${KBOOTSTRAP_MAKEFLAGS:=-j$(nproc)}"

for cmd in kiss bwrap; do
	command -v "$cmd" >/dev/null || {
		echo "Command '$cmd' not found!" >&2
		exit 1
	}
done

OUTFILE="${1:-$PWD/kiss-chroot-$(date +'%y.%m.%d').tar}"
:>> "$OUTFILE"
OUTFILE="$(realpath "$OUTFILE")"

TMPDIR="$(mktemp -d)"

STAGE1="stage1"
STAGE2="stage2"
DUMMY_PACKAGE_DIR="$TMPDIR/repo/__dummy-bootstrap"

trap 'rm -rf "$TMPDIR"' INT

setenv() {
	export AR=ar
	export CC=cc
	export CXX=c++
	export NM=nm
	export RANLIB=ranlib
	export CFLAGS="$KBOOTSTRAP_CFLAGS"
	export CXXFLAGS="$KBOOTSTRAP_CXXFLAGS"
	export MAKEFLAGS="$KBOOTSTRAP_MAKEFLAGS"

	unset CPPFLAGS

	export KISS_ROOT="$1"
	export KISS_PATH="$KBOOTSTRAP_KISS_PATH"

	cac_dir=${XDG_CACHE_HOME:-"${HOME%"${HOME##*[!/]}"}/.cache"}
	cac_dir=${cac_dir%"${cac_dir##*[!/]}"}/kiss/sources

	mkdir -p "$cac_dir"

	# Don't use host binary cache, just sources
	XDG_CACHE_HOME="$TMPDIR/$(date +%s)"
	export XDG_CACHE_HOME

	mkdir -p "$XDG_CACHE_HOME/kiss"

	ln -sf "$cac_dir" "$XDG_CACHE_HOME/kiss/sources"
}

ret=0

cat <<EOF
KBOOTSTRAP_KISS_PATH = $KBOOTSTRAP_KISS_PATH
KBOOTSTRAP_PACKAGES = $KBOOTSTRAP_PACKAGES
KBOOTSTRAP_CFLAGS = $KBOOTSTRAP_CFLAGS
KBOOTSTRAP_CXXFLAGS = $KBOOTSTRAP_CXXFLAGS
KBOOTSTRAP_MAKEFLAGS = $KBOOTSTRAP_MAKEFLAGS

OUTFILE = $OUTFILE
EOF

set +e

(
	set -e

	echo "Ctrl + C to cancel building"
	read -r _

	mkdir -p "$TMPDIR/$STAGE1"
	mkdir -p "$TMPDIR/$STAGE2"

	kiss new "$DUMMY_PACKAGE_DIR" 1

	# shellcheck disable=2086
	set -- $KBOOTSTRAP_PACKAGES

	[ "$1" = "baselayout" ] || {
		echo "First package to build must be 'baselayout'!" >&2
		return 1
	}

	printf '%s\n' "$@" > "$DUMMY_PACKAGE_DIR/depends"

	# Initial build using host toolchain
	(
		setenv "$TMPDIR/$STAGE1"
		# shellcheck disable=2030
		export LD_LIBRARY_PATH="$TMPDIR/$STAGE1/lib"
		# shellcheck disable=2030
		export PATH="$TMPDIR/$STAGE1/bin:$PATH"

		cd "$DUMMY_PACKAGE_DIR"
		KISS_PROMPT=0 kiss build
	)

	# Rebuild using libraries and toolchain built above
	(
		setenv "$TMPDIR/$STAGE2"
		# shellcheck disable=2031
		export LD_LIBRARY_PATH="$TMPDIR/$STAGE2/lib:$TMPDIR/$STAGE1/lib"
		# shellcheck disable=2031
		export PATH="$TMPDIR/$STAGE2/bin:$TMPDIR/$STAGE1/bin"

		cmd_path="$(realpath "$(command -v cc)")"
		cmd_expected="$(realpath "$TMPDIR/$STAGE1/bin/cc")"

		[ "$cmd_path" = "$cmd_expected" ] || {
			cat <<EOF
Actual path of compiler binary differs!

Expected: $cmd_expected
Actual: $cmd_path
EOF

			return 1
		}

		cd "$DUMMY_PACKAGE_DIR"

		CFLAGS="$CFLAGS --sysroot=$TMPDIR/$STAGE1" \
		CXXFLAGS="$CXXFLAGS --sysroot=$TMPDIR/$STAGE1" \
		KISS_PROMPT=0 \
			kiss build
	)

	rm -rf "${TMPDIR:?}/$STAGE1"

	setenv ""

	srcdir_real="$(realpath "$XDG_CACHE_HOME/kiss/sources")"
	rm -f "$XDG_CACHE_HOME/kiss/sources"
	# Rebuild stage2 using itself
	# /etc/resolv.conf is mounted for openssl's post-install
	bwrap \
		--bind "$TMPDIR/$STAGE2" / \
		--dev /dev \
		--proc /proc \
		--tmpfs /tmp \
		--bind "$TMPDIR" "$TMPDIR" \
		--bind "$XDG_CACHE_HOME" "$XDG_CACHE_HOME" \
		--ro-bind "$srcdir_real" "$XDG_CACHE_HOME/kiss/sources" \
		--ro-bind "$BASEDIR/rebuild.sh" /tmp/rebuild.sh \
		--ro-bind /etc/resolv.conf /etc/resolv.conf \
		--uid 0 \
		--gid 0 \
		--die-with-parent \
		/bin/env -i \
			HOME="$XDG_CACHE_HOME" \
			SHELL=/bin/sh \
			USER=root \
			LOGNAME=root \
			AR="$AR" \
			CC="$CC" \
			CXX="$CXX" \
			NM="$NM" \
			RANLIB="$RANLIB" \
			CFLAGS="$CFLAGS" \
			CXXFLAGS="$CXXFLAGS" \
			MAKEFLAGS="$MAKEFLAGS" \
			XDG_CACHE_HOME="$XDG_CACHE_HOME" \
			PATH="/usr/bin" \
			/bin/sh /tmp/rebuild.sh

	rm -f "$TMPDIR/$STAGE2/etc/resolv.conf"

	bwrap \
		--uid 0 \
		--gid 0 \
		--bind / / \
		--chdir "$TMPDIR/$STAGE2" \
		tar cf "$OUTFILE" .

	echo "Successfully built tarball at '$OUTFILE'"
)

ret="$?"

[ "$ret" = 0 ] || echo "Build failed!" >&2

echo "Cleaning up '$TMPDIR'"
rm -rf "$TMPDIR"

exit "$ret"
