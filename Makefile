GOARCH = amd64
MASTER_BRANCH ?= main

UPDATE_MK_INCLUDE := true
UPDATE_MK_INCLUDE_AUTO_MERGE := true
SERVICE_NAME := pie-cc-hashicorp-vault-plugin
IMAGE_NAME := $(SERVICE_NAME)
BASE_IMAGE := golang

GO_BINS = github.com/confluentinc/pie-cc-hashicorp-vault-plugin/cmd/plugin=vault-ccloud-secrets-engine

GITHUB_API = api.github.com
GITHUB_MK_INCLUDE_OWNER := confluentinc
GITHUB_MK_INCLUDE_REPO := cc-mk-include
GITHUB_API_CC_MK_INCLUDE := https://$(GITHUB_API)/repos/$(GITHUB_MK_INCLUDE_OWNER)/$(GITHUB_MK_INCLUDE_REPO)
GITHUB_API_CC_MK_INCLUDE_TARBALL := $(GITHUB_API_CC_MK_INCLUDE)/tarball
GITHUB_API_CC_MK_INCLUDE_VERSION ?= $(GITHUB_API_CC_MK_INCLUDE_TARBALL)/$(MK_INCLUDE_VERSION)

MK_INCLUDE_DIR := mk-include
MK_INCLUDE_LOCKFILE := .mk-include-lockfile
MK_INCLUDE_TIMESTAMP_FILE := .mk-include-timestamp
# For optimum performance, you should override MK_INCLUDE_TIMEOUT_MINS above the managed section headers to be
# a little longer than the worst case cold build time for this repo.
MK_INCLUDE_TIMEOUT_MINS ?= 240
# If this latest validated release is breaking you, please file a ticket with DevProd describing the issue, and
# if necessary you can temporarily override MK_INCLUDE_VERSION above the managed section headers until the bad
# release is yanked.
MK_INCLUDE_VERSION ?= v0.971.0

include ./mk-include/cc-begin.mk
include ./mk-include/cc-vault.mk
include ./mk-include/cc-semaphore.mk
include ./mk-include/cc-semver.mk
include ./mk-include/cc-go.mk
include ./mk-include/cc-cpd.mk
include ./mk-include/halyard.mk
include ./mk-include/cc-api.mk
include ./mk-include/cc-ci-metrics.mk
include ./mk-include/cc-sonarqube.mk

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
	vault write ccloud/role/test name="test" owner=${CONFLUENT_OWNER_ID} owner_env=${CONFLUENT_ENVIRONMENT_ID} resource=${CONFLUENT_RESOURCE_ID} resource_env=${CONFLUENT_ENVIRONMENT_ID}

