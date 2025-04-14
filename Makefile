GOARCH = amd64
SERVICE_NAME := confluent-cloud-secrets-engine
IMAGE_NAME := $(SERVICE_NAME)
BASE_IMAGE := golang

# Disable CGO by default, to allow static binaries
export CGO_ENABLED := 0

UNAME = $(shell uname -s)

# Select the os based off the machine the user is using to run the command
ifndef OS
	ifeq ($(UNAME), Linux)
		export OS = linux
		export SHA256 = $(shell sha256sum bin/vault-ccloud-secrets-engine | cut -d' ' -f1)
	else ifeq ($(UNAME), Darwin)
		export OS = darwin
		export SHA256 = $(shell shasum -a 256 bin/vault-ccloud-secrets-engine | cut -d' ' -f1)
	endif
endif

.DEFAULT_GOAL := all

all: fmt build test start

create:
	GOOS=linux GOARCH=amd64 make build

fmt:
	go fmt ./...

build:
	mkdir -p bin
	go build -o bin/vault-ccloud-secrets-engine -ldflags "-X main.version=v0.7.0" -tags static_all -buildmode=exe github.com/confluentinc/confluent-cloud-secrets-engine/cmd/plugin

test:
	go test -v ./pkg/plugin

start:
	vault server -dev -dev-root-token-id=root -dev-plugin-dir=./vault/plugins -log-level=DEBUG

enable:
	vault plugin register -sha256="${SHA256}" -command="vault-ccloud-secrets-engine" secret ccloud-secrets-engine
	vault secrets enable -path="ccloud" -plugin-name="ccloud-secrets-engine" plugin

setup:
	vault write ccloud/config ccloud_api_key_id=${CONFLUENT_KEY} ccloud_api_key_secret=${CONFLUENT_SECRET} url="https://api.confluent.cloud"
	vault write ccloud/role/test1 name="test1" owner=${CONFLUENT_OWNER_ID} owner_env=${CONFLUENT_ENVIRONMENT_ID} resource=${CONFLUENT_RESOURCE_ID} resource_env=${CONFLUENT_ENVIRONMENT_ID} key_description=${CONFLUENT_KEY_DESCRIPTION}

setupMulti:
	vault write ccloud/config ccloud_api_key_id=${CONFLUENT_KEY} ccloud_api_key_secret=${CONFLUENT_SECRET} url="https://api.confluent.cloud"
	vault write ccloud/role/test name="test" owner=${CONFLUENT_OWNER_ID} owner_env=${CONFLUENT_ENVIRONMENT_ID} resource=${CONFLUENT_RESOURCE_ID} resource_env=${CONFLUENT_ENVIRONMENT_ID} multi_use_key="true" key_description=${CONFLUENT_KEY_DESCRIPTION}
