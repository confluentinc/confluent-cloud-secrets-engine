#!/bin/bash

export SOCK="/tmp/spire-agent/public/api.sock"
socat TCP-LISTEN:8081,reuseaddr,fork "UNIX-CLIENT:$SOCK" &
socat_pid=$!
trap "kill -- $socat_pid" EXIT

echo $@

/opt/spire/bin/spire-agent run $@