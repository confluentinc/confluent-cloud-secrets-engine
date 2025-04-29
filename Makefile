### BEGIN MK-INCLUDE UPDATE ###
### This section is managed by service-bot and should not be edited here.
### You can make changes upstream in https://github.com/confluentinc/cc-service-bot

CURL ?= curl
FIND ?= find
TAR ?= tar

# Mount netrc so curl can work from inside a container
DOCKER_NETRC_MOUNT ?= 1

GITHUB_API = api.github.com

GOARCH = amd64
MASTER_BRANCH ?= main

SERVICE_NAME := confluent-cloud-secrets-engine
IMAGE_NAME := $(SERVICE_NAME)
BASE_IMAGE := golang

# Variables
WORKSPACE := $(shell pwd)
BIN_DIR := $(WORKSPACE)/bin
APP_NAME := vault-ccloud-secrets-engine
SRC := $(WORKSPACE)/cmd/plugin/main.go
BIN_NAME := vault-ccloud-secrets-engine

# Default target
.PHONY: all
all: build

# Create bin directory
$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Build the Go binary
.PHONY: build
build: $(BIN_DIR)
		go build -o $(BIN_DIR)/$(BIN_NAME) $(SRC)

# Clean up the build
.PHONY: clean
clean:
	rm -rf $(BIN_DIR)

# Disable CGO by default, to allow static binaries
export CGO_ENABLED := 0

UNAME = $(shell uname -s)

#Select the os based off the machine the user is using to run the command
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

#todo come back to this when the user can run this command

all: fmt build test start

create:
	GOOS=linux GOARCH=amd64  make build

test:
	go test -v ./pkg/plugin

start:
	vault server -dev -dev-root-token-id=root -dev-plugin-dir=./vault/plugins -log-level=DEBUG

# Export vault test address and vault test token then the command for the sha 256 sum if different for mac and linux, used a variable to interchange.
enable:
	vault plugin register -sha256="${SHA256}" -command="vault-ccloud-secrets-engine" secret ccloud-secrets-engine
	vault secrets enable -path="ccloud" -plugin-name="ccloud-secrets-engine" plugin

setup:
	vault write ccloud/config ccloud_api_key_id=${CONFLUENT_KEY} ccloud_api_key_secret=${CONFLUENT_SECRET} url="https://api.confluent.cloud"
	vault write ccloud/role/singleUse name="singleUse" owner=${CONFLUENT_OWNER_ID} owner_env=${CONFLUENT_ENVIRONMENT_ID} resource=${CONFLUENT_RESOURCE_ID} resource_env=${CONFLUENT_ENVIRONMENT_ID} key_description=${CONFLUENT_KEY_DESCRIPTION}

setupMulti:
	vault write ccloud/config ccloud_api_key_id=${CONFLUENT_KEY} ccloud_api_key_secret=${CONFLUENT_SECRET} url="https://api.confluent.cloud"
	vault write ccloud/role/multiUse name="multiUse" owner=${CONFLUENT_OWNER_ID} owner_env=${CONFLUENT_ENVIRONMENT_ID} resource=${CONFLUENT_RESOURCE_ID} resource_env=${CONFLUENT_ENVIRONMENT_ID} multi_use_key="true" key_description=${CONFLUENT_KEY_DESCRIPTION}

