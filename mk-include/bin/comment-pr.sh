#!/bin/bash
# comment on PRs(if exists) with the content of
# the file passed as an argument to the script.
#
# Will remove the file after comment has been done.

set -e
output_file=${1}

if [ ! -f "${output_file}" ]; then
    echo "No message provided, skip commenting on PRs."
    exit 0
fi

if [ -z "$SEMAPHORE_GIT_PR_NUMBER" ]; then
    if gh pr status | grep -E 'There is no pull request associated with|There is no current branch'; then
        echo "no PR found for this branch, abort commenting on PRs"
        rm "${output_file}"
        exit 0
    fi;
fi

if [ -z "$SEMAPHORE_GIT_PR_NUMBER" ]; then
    gh pr comment -F "${output_file}"
else
    gh pr comment $SEMAPHORE_GIT_PR_NUMBER -F "${output_file}"
fi

rm "${output_file}"

