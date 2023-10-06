#!/usr/bin/env bash
MK_INCLUDE_BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 1. need json output for adapter to work
# 2. go test2json output goes to our junit xml report adapter
# 3. show errors in color
"$@" \
    -json \
    1> >(${MK_INCLUDE_BIN}/decode_test2json.py) \
    2> >(${MK_INCLUDE_BIN}/color_errors.py >&2)

exit_code=$?

# wait for subshells
wait

exit ${exit_code}
