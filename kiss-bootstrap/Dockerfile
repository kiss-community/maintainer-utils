# Perform an initial (tainted) build of all packages, using the host distro's
# header files and libraries
FROM alpine:3.18.4 AS stage0

# Setup the base image, this is a bit hacky but saves us from creating separate
# builder images for musl & glibc
RUN <<EOF
# case ... esac
exec apk add build-base
EOF

ARG KISS_COMMIT=7740c929a3aa46be08876d744a472eb4c558bea2

RUN wget -O /usr/bin/kiss \
        https://codeberg.org/kiss-community/kiss/raw/commit/$KISS_COMMIT/kiss && \
            chmod +x /usr/bin/kiss

ARG CACHE_BASE=/cache
# Re-use the shared cache for source tarballs
ARG SOURCE_CACHE_MOUNT=$CACHE_BASE/kiss/sources
ARG BUILD_REPOS_MOUNT=/shared/repos
ARG STAGE1=/stage1
# The meta package is a temporary package that depends on all bootstrap packages
# allowing us to build all of them in dependency order with a single command
ARG BOOTSTRAP_META_PACKAGE=bootstrap_meta

ARG CFLAGS=-march=x86-64 -mtune=generic -pipe -O2
ARG CXXFLAGS=-march=x86-64 -mtune=generic -pipe -O2
ARG REPOS_PATH
ARG BOOTSTRAP_PACKAGES

WORKDIR /tmp
RUN --mount=type=cache,target=$SOURCE_CACHE_MOUNT \
    --mount=type=bind,source=repos,target=$BUILD_REPOS_MOUNT \
    --mount=type=tmpfs,target=/tmp \
    <<EOF
set -eux

export KISS_PATH=

export LOGNAME=root

# Doesn't really matter, can be any temp dir
export KISS_TMPDIR=/tmp/kiss

# Don't prompt for user input
export KISS_PROMPT=0

# This is where all the built packages will be installed
export KISS_ROOT="$STAGE1"

# Re-use the mounted cache for tarballs
export XDG_CACHE_HOME="$CACHE_BASE"

# Add the new rootfs's binaries and libraries to our PATH in-case a build
# dependency is missing from the host builder
# This is hacky but the final binaries are not tainted due to a multi-stage
# bootstrap
export PATH="$PATH:$KISS_ROOT/bin"
export LD_LIBRARY_PATH="/lib:$KISS_ROOT/lib"

# Same thing, but for the compiler toolchain. We can't pass a sysroot as it
# is partially built, so we use the bootstrap packages if something is not
# present on the host
export C_INCLUDE_PATH="$KISS_ROOT/usr/include"
export LIBRARY_PATH="$KISS_ROOT/lib"
export PKG_CONFIG_SYSROOT_DIR="$KISS_ROOT"
export PKG_CONFIG_LIBDIR="$KISS_ROOT/usr/lib/pkgconfig:$KISS_ROOT/usr/share/pkgconfig"

# Add the specified repos in KISS_PATH to use them for building all the
# bootstrap packages
for repo in $REPOS_PATH; do
	KISS_PATH="$KISS_PATH:$BUILD_REPOS_MOUNT/$repo"
done

set -- $BOOTSTRAP_PACKAGES

[ "$1" = "baselayout" ] || {
    echo "First package to build must be 'baselayout'!" >&2
    return 1
}

# Create the meta package
mkdir $BOOTSTRAP_META_PACKAGE
cd $BOOTSTRAP_META_PACKAGE

install -Dm755 /dev/null build
printf '%s\n' "$@" > depends
echo 1 1 > version

cat depends

# Build and install all transitive dependencies
kiss build

# Install the meta package itself so we can share the dependency list
# with further stages
kiss install
EOF
