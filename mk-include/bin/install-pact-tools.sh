#!/bin/bash
set -eu

ARCH=$(uname -m)
# pact binaries have lowercase OS name, while uname will return capitalized one
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# moreover, pact binaries have 'osx' as OS type while uname will return Darwin
if [[ $OS == "darwin" ]]; then
OS="osx"
fi
# pact CLIs use "aarch64" in both linux and osx binaries' names
# while on a Mac uname would return "arm64"
if [[ $ARCH == "arm64" ]]; then
ARCH=aarch64
fi


function install_cli() {
    local EXEC_NAME=$1
    local BASE_URL=$2

    local EXEC_PATH="${PACT_BIN_PATH}/${EXEC_NAME}"
    local EXEC_NAME_FULL="${EXEC_NAME}-${OS}-${ARCH}"
    local ARCHIVE_NAME=${EXEC_NAME_FULL}.gz
    
    local FULL_URL="${BASE_URL}/${ARCHIVE_NAME}"

    echo "Downloading ${EXEC_NAME} from ${FULL_URL}"
    curl -fsSLO "${FULL_URL}"

    gunzip "./${ARCHIVE_NAME}"
    mv "./${EXEC_NAME_FULL}" "${EXEC_PATH}"
    chmod +x "${EXEC_PATH}"
}


echo "Installing pact verifier CLI ${PACT_VERIFIER_VERSION}"
install_cli pact_verifier_cli "https://github.com/pact-foundation/pact-reference/releases/download/pact_verifier_cli-v${PACT_VERIFIER_VERSION}"


echo "Installing pact plugin manager CLI ${PACT_PLUGIN_CLI_VERSION}"
install_cli pact-plugin-cli "https://github.com/pact-foundation/pact-plugins/releases/download/pact-plugin-cli-v${PACT_PLUGIN_CLI_VERSION}"


echo "Installing pact-protobuf-plugin ${PACT_PROTOBUF_PLUGIN_VERSION} via plugin manager CLI"
pact-plugin-cli -y install "https://github.com/pactflow/pact-protobuf-plugin/releases/tag/v-${PACT_PROTOBUF_PLUGIN_VERSION}"

PROTOBUF_PLUGIN_CONFIG_FILE="${HOME}/.pact/plugins/protobuf-${PACT_PROTOBUF_PLUGIN_VERSION}/pact-plugin.json"
# Update the value of pluginConfig.protocVersion in PROTOBUF_PLUGIN_CONFIG_FILE to 3.20.3 via jq
echo "Updating protocVersion in ${PROTOBUF_PLUGIN_CONFIG_FILE} to ${PACT_PROTOC_VERSION}"
jq --arg v "${PACT_PROTOC_VERSION}" '.pluginConfig.protocVersion = $v' "${PROTOBUF_PLUGIN_CONFIG_FILE}" > "${PROTOBUF_PLUGIN_CONFIG_FILE}.tmp"
mv "${PROTOBUF_PLUGIN_CONFIG_FILE}.tmp" "${PROTOBUF_PLUGIN_CONFIG_FILE}"



# install pact go
# check if go.mod is present - good indicator we're actually building a go project
if [ -f "${GIT_ROOT}/go.mod" ]; then
    # must be -mod=readonly, because it will use vendor mode by default
    # and will complain saying `module lookup disabled by -mod=vendor`
    # apparenly it can't use network in vendor mode and even though vendor folder might contain
    # the package we want, it cannot perform a lookup? Weird.
    echo "Installing pact-go CLI in ${PACT_BIN_PATH}"
    GOBIN=${PACT_BIN_PATH} go install -mod=readonly github.com/pact-foundation/pact-go/v2
    echo "Using pact-go at ${PACT_BIN_PATH}/pact-go"

    echo "Installing Pact FFI native library"
    if [[ $OS = "linux" ]] || [[ $OS = "osx" && $ARCH = "aarch64" ]]; then
        echo "SUDO REQUIRED"
        echo "This script will install a native Pact library under system location,"
        echo "which is not writable by default."
        echo "Please enter your password when prompted."
        run_as="sudo"
    else
        run_as=""
    fi 
    $run_as "${PACT_BIN_PATH}/pact-go" -l DEBUG install
    
    if [[ $OS = "osx" ]]; then
        echo "Updating install_name on Pact FFI library"
        echo "Running '$run_as install_name_tool -id /usr/local/lib/libpact_ffi.dylib /usr/local/lib/libpact_ffi.dylib'"
        # Hack around an issue with MacOS 13.6: https://github.com/pact-foundation/pact-go/issues/345
        $run_as install_name_tool -id /usr/local/lib/libpact_ffi.dylib /usr/local/lib/libpact_ffi.dylib
    fi
else
    echo "Skip installing pact-go since there's not ${GIT_ROOT}/go.mod file"
fi

