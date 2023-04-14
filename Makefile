GOARCH = amd64

UNAME = $(shell uname -s)

#Select the os based off the machine the user is using to run the command
ifndef OS
	ifeq ($(UNAME), Linux)
		OS = linux
		shavalue = sha256sum
	else ifeq ($(UNAME), Darwin)
		OS = darwin
		shavalue = shasum -a 256
	endif
endif

.DEFAULT_GOAL := all

#todo come back to this when the user can run this command
all: fmt build test start

build:
	GOOS=$(OS) GOARCH="$(GOARCH)" go build -o bin/hashicorp-vault-ccloud-secrets-engine ./cmd/plugin/main.go

test:
	go test -v ./pkg/plugin

start:
	vault server -dev -dev-root-token-id=root -dev-plugin-dir=./vault/plugins -log-level=DEBUG

# Export vault test address and vault test token then the command for the sha 256 sum if different for mac and linux, used a variable to interchange.
enable:
    export VAULT_ADDR=http://0.0.0.0:8200
    export VAULT_TOKEN=12345
	vault plugin register -sha256="$$($(shavalue) bin/hashicorp-vault-ccloud-secrets-engine | cut -d ' ' -f1)" -command="hashicorp-vault-ccloud-secrets-engine" secret ccloud-secrets-engine
	vault secrets enable -path="ccloud" -plugin-name="ccloud-secrets-engine" plugin

setup: enable
	vault write ccloud/config ccloud_api_key_id=${CONFLUENT_KEY} ccloud_api_key_secret=${CONFLUENT_SECRET} url="https://api.confluent.cloud"
	vault write ccloud/role/test name="test" owner=${CONFLUENT_OWNER_ID} owner_env=${CONFLUENT_ENVIRONMENT_ID} resource=${CONFLUENT_RESOURCE_ID} resource_env=${CONFLUENT_ENVIRONMENT_ID}


UPDATE_MK_INCLUDE := true
UPDATE_MK_INCLUDE_AUTO_MERGE := true

GO_BINS = github.com/confluentinc/pie-cc-hashicorp-vault-plugin/cmd/plugin=hashicorp-vault-ccloud-secrets-engine
#GO_USE_VENDOR ?= -mod=vendor


include ./mk-include/cc-begin.mk
include ./mk-include/cc-semaphore.mk
include ./mk-include/cc-semver.mk
include ./mk-include/cc-go.mk
include ./mk-include/cc-end.mk

# Disable CGO by default, to allow static binaries
export CGO_ENABLED := 0
