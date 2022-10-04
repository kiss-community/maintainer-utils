#!/bin/sh

set -eu

rm -f ./*.gz

OUT="cert-$(date +%s).pem.gz"

curl -L https://curl.haxx.se/ca/cacert.pem | gzip > "$OUT"
sha256sum "$OUT"
