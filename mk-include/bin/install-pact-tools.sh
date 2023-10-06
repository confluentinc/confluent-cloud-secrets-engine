#!/bin/bash
set -eu

ARCH=$(uname -m)
# pact binaries have lowercase OS name, while uname will return capitalized one
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# moreover, pact binaries have 'osx' as OS type while uname will return Darwin
if [[ $OS == "darwin" ]]; then
OS="osx"
fi

function install_cli() {
    local EXEC_NAME=$1
    local BASE_URL=$2

    local EXEC_PATH="${PACT_BIN_PATH}/${EXEC_NAME}"

    local EXEC_NAME_FULL="${EXEC_NAME}-${OS}-${ARCH}"
    local ARCHIVE_NAME=${EXEC_NAME_FULL}.gz

    curl -fsSLO "${BASE_URL}/${ARCHIVE_NAME}"
    gunzip "./${ARCHIVE_NAME}"
    mv "./${EXEC_NAME_FULL}" "${EXEC_PATH}"
    chmod +x "${EXEC_PATH}"
}

# install legacy pact ruby CLI (up to pact schema v2 only)
curl -fsSL https://raw.githubusercontent.com/pact-foundation/pact-ruby-standalone/master/install.sh | bash

# install rust pact verifier CLI (supports newest pact schemas including v4)
install_cli pact_verifier_cli "https://github.com/pact-foundation/pact-reference/releases/download/pact_verifier_cli-v${PACT_VERIFIER_VERSION}"


# install pact plugin manager CLI (to be able to install protobuf)
install_cli pact-plugin-cli "https://github.com/pact-foundation/pact-plugins/releases/download/pact-plugin-cli-v${PACT_PLUGIN_CLI_VERSION}"


# install pact protobuf plugin
pact-plugin-cli -y install https://github.com/pactflow/pact-protobuf-plugin/releases/latest

# install pact go
# check if go.mod is present - good indicator we're actually building a go project
if [ -f "${GIT_ROOT}/go.mod" ]; then
    # must be -mod=readonly, because it will use vendor mode by default
    # and will complain saying `module lookup disabled by -mod=vendor`
    # apparenly it can't use network in vendor mode and even though vendor folder might contain
    # the package we want, it cannot perform a lookup? Weird.
    echo "Running 'GOBIN=${PACT_BIN_PATH} go install -mod=readonly github.com/pact-foundation/pact-go/v2'"
    GOBIN=${PACT_BIN_PATH} go install -mod=readonly github.com/pact-foundation/pact-go/v2
    echo "Using pact-go at ${PACT_BIN_PATH}/pact-go"
    # TODO: maybe move the lib to the folder under ./pact/lib, but need to resolve how to link to it correctly
    if [[ -n "$CI" ]]; then
        sudo "${PACT_BIN_PATH}/pact-go" -l DEBUG install
    else
        "${PACT_BIN_PATH}/pact-go" -l DEBUG install
    fi
    if [[ $OS == "osx" ]]; then
        # Hack around an issue with MacOS 13.6: https://github.com/pact-foundation/pact-go/issues/345
        echo "Running 'install_name_tool -id /usr/local/lib/libpact_ffi.dylib /usr/local/lib/libpact_ffi.dylib'"
        install_name_tool -id /usr/local/lib/libpact_ffi.dylib /usr/local/lib/libpact_ffi.dylib
    fi
fi

