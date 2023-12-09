### BEGIN MK-INCLUDE UPDATE ###
CURL ?= curl
FIND ?= find
TAR ?= tar

# Mount netrc so curl can work from inside a container
DOCKER_NETRC_MOUNT ?= 1

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
MK_INCLUDE_VERSION ?= v0.958.0

# Make sure we always have a copy of the latest cc-mk-include release less than $(MK_INCLUDE_TIMEOUT_MINS) old:
./$(MK_INCLUDE_DIR)/%.mk: .mk-include-check-FORCE
	@trap "rm -f $(MK_INCLUDE_LOCKFILE); exit" 0 2 3 15; \
	waitlock=0; while ! ( set -o noclobber; echo > $(MK_INCLUDE_LOCKFILE) ); do \
	   sleep $$waitlock; waitlock=`expr $$waitlock + 1`; \
	   test 14 -lt $$waitlock && { \
	      echo 'stealing stale lock after 105s' >&2; \
	      break; \
	   } \
	done; \
	test -s $(MK_INCLUDE_TIMESTAMP_FILE) || rm -f $(MK_INCLUDE_TIMESTAMP_FILE); \
	test -z "`$(FIND) $(MK_INCLUDE_TIMESTAMP_FILE) -mmin +$(MK_INCLUDE_TIMEOUT_MINS) 2>&1`" || { \
	   grep -q 'machine $(GITHUB_API)' ~/.netrc 2>/dev/null || { \
	      echo 'error: follow https://confluentinc.atlassian.net/l/cp/0WXXRLDh to fix your ~/.netrc'; \
	      exit 1; \
	   }; \
	   $(CURL) --fail --silent --netrc --location "$(GITHUB_API_CC_MK_INCLUDE_VERSION)" --output $(MK_INCLUDE_TIMESTAMP_FILE)T --write-out '$(GITHUB_API_CC_MK_INCLUDE_VERSION): %{errormsg}\n' >&2 \
	   && $(TAR) zxf $(MK_INCLUDE_TIMESTAMP_FILE)T \
	   && rm -rf $(MK_INCLUDE_DIR) \
	   && mv $(GITHUB_MK_INCLUDE_OWNER)-$(GITHUB_MK_INCLUDE_REPO)-* $(MK_INCLUDE_DIR) \
	   && mv -f $(MK_INCLUDE_TIMESTAMP_FILE)T $(MK_INCLUDE_TIMESTAMP_FILE) \
	   && echo 'installed cc-mk-include-$(MK_INCLUDE_VERSION) from $(GITHUB_MK_INCLUDE_REPO)' \
	   ; \
	} || { \
	   rm -f $(MK_INCLUDE_TIMESTAMP_FILE)T; \
	   if test -f $(MK_INCLUDE_TIMESTAMP_FILE); then \
	      touch $(MK_INCLUDE_TIMESTAMP_FILE); \
	      echo 'unable to access $(GITHUB_MK_INCLUDE_REPO) fetch API to check for latest release; next try in $(MK_INCLUDE_TIMEOUT_MINS) minutes' >&2; \
	   else \
	      echo 'unable to access $(GITHUB_MK_INCLUDE_REPO) fetch API to bootstrap mk-include subdirectory' >&2 && false; \
	   fi; \
	}

.PHONY: .mk-include-check-FORCE
.mk-include-check-FORCE:
	@test -z "`git ls-files $(MK_INCLUDE_DIR)`" || { \
		echo 'fatal: checked in $(MK_INCLUDE_DIR)/ directory is preventing make from fetching recent cc-mk-include releases for CI' >&2; \
		exit 1; \
	}
### END MK-INCLUDE UPDATE ###
GOARCH = amd64
MASTER_BRANCH ?= main

UPDATE_MK_INCLUDE := true
UPDATE_MK_INCLUDE_AUTO_MERGE := true
SERVICE_NAME := pie-cc-hashicorp-vault-plugin
IMAGE_NAME := $(SERVICE_NAME)
BASE_IMAGE := golang

GO_BINS = github.com/confluentinc/pie-cc-hashicorp-vault-plugin/cmd/plugin=vault-ccloud-secrets-engine

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
include ./mk-include/cc-end.mk

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
