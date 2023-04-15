# maintainer-utils

This repository contains a few scripts to make maintainer's lives easier

## kiss-bootstrap

Generates a KISS rootfs tarball rootlessly using `unshare` and `bubblewrap`. Usage:

```sh
cd kiss-bootstrap

# Create build config

cat > conf <<EOF
# Build Flags
KBOOTSTRAP_CFLAGS="-march=x86-64 -mtune=generic -pipe -O2"
KBOOTSTRAP_CXXFLAGS="-march=x86-64 -mtune=generic -pipe -O2"
# Change this to point to the repos containing the packages listed in KBOOTSTRAP_PACKAGES
KBOOTSTRAP_KISS_PATH="$HOME/Development/Repos/repo/core:$HOME/Development/Repos/repo/extra"
KBOOTSTRAP_PACKAGES="baselayout binutils bison busybox bzip2 curl flex gcc git musl kiss linux-headers m4 make openssl pigz xz zlib"
EOF

# Outputs the rootfs at ./kiss-chroot-YY.MM.DD.tar
./bootstrap.sh
```

## updater

Allows auto-updating packages by parsing the output of `kiss outdated`. Usage:

```sh
cd updater

# Get package versions from repology

kiss outdated > outdated

REPO="$HOME/KISS/community/community"

# Prompts for updating packages in $REPO
./update update "$REPO" < outdated

# The updated packages are copied to ./updated

# Regenerate checksums for new URLs
./update checksum

# Rebuild every changed package to test for build failures
# This command is resumable and doesn't rebuild already built packages
./update check

# The packages from ./updated/* can now be moved to the original repo and pushed to the remote repo
```
