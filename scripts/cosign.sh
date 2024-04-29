#!/bin/sh
set -e

# https://docs.sigstore.dev/cosign/installation/

test -z "$TMPDIR" && TMPDIR="$(mktemp -d)"
export COSIGN_FILE="$TMPDIR/cosign"

cd "$TMPDIR"

echo "Downloading cosign ..."
curl -sfLo "$COSIGN_FILE" "https://github.com/sigstore/cosign/releases/download/v1.6.0/cosign-linux-amd64"

echo "Setting permissions ..."
chmod +x "$COSIGN_FILE"