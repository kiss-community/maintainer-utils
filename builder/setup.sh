#!/bin/sh

set -eu

/busybox tar xf /rootfs.tar

echo "nameserver 9.9.9.9" > /etc/resolv.conf

export KISS_PROMPT=0

kiss u && kiss u

kiss b "$1"
