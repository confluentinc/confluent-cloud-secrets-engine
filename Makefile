GOARCH = amd64
MASTER_BRANCH ?= main

UPDATE_MK_INCLUDE := false
UPDATE_MK_INCLUDE_AUTO_MERGE := false
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

### BEGIN MK-INCLUDE/ BOOTSTRAP ###
CURL = curl
FIND = find
JQ = jq
SED = sed
TAR = tar

CURL_LOCATION = $(CURL) --fail --silent --netrc --location
CURL_LATEST = $(CURL_LOCATION) $(GITHUB_API_CC_MK_INCLUDE_LATEST)
CURL_RELEASES = $(CURL_LOCATION) $(GITHUB_API_CC_MK_INCLUDE_RELEASES)

GITHUB_API = https://api.github.com
GITHUB_API_CC_MK_INCLUDE = $(GITHUB_API)/repos/$(GITHUB_OWNER)/$(GITHUB_REPO)
GITHUB_API_CC_MK_INCLUDE_LATEST = $(GITHUB_API_CC_MK_INCLUDE_RELEASES)/latest
GITHUB_API_CC_MK_INCLUDE_RELEASES = $(GITHUB_API_CC_MK_INCLUDE)/releases
GITHUB_OWNER = confluentinc
GITHUB_REPO = cc-mk-include

JQ_RELEASE_TARBALL = $(JQ) --raw-output '.tarball_url'
JQ_LATEST_TARBALL = $(JQ) --raw-output 'sort_by(.published_at) | .[-1].tarball_url'

MK_INCLUDE_DIR = mk-include
MK_INCLUDE_LOCKFILE = .mk-include-lockfile
# You should adjust MK_INCLUDE_TIMEOUT_MINS to a little longer than the worst case cold build time for this repo.
MK_INCLUDE_TIMEOUT_MINS = 240
MK_INCLUDE_TIMESTAMP_FILE = .mk-include-timestamp

SED_RELEASE_TARBALL = $(SED) -n '/"tarball_url"/{s/^.*: *"//;s/",*//;p;q;}'

# Make sure we always have a copy of the latest cc-mk-include release from
# less than $(MK_INCLUDE_TIMEOUT_MINS) ago:
./$(MK_INCLUDE_DIR)/%.mk: .mk-include-check-FORCE
	@grep -q 'machine api.github.com' ~/.netrc 2>/dev/null || { \
	   echo 'error: follow https://confluentinc.atlassian.net/l/cp/0WXXRLDh to fix your ~/.netrc'; \
	   exit 1; \
	}; \
	trap "rm -f $(MK_INCLUDE_LOCKFILE); exit" 0 2 3 15; \
	waitlock=0; while ! ( set -o noclobber; echo > $(MK_INCLUDE_LOCKFILE) ); do \
	   sleep $$waitlock; waitlock=`expr $$waitlock + 1`; \
	   test 14 -lt $$waitlock && { \
	      echo 'stealing stale lock after 105s' >&2; \
	      break; \
	   } \
	done; \
	test -s $(MK_INCLUDE_TIMESTAMP_FILE) || rm -f $(MK_INCLUDE_TIMESTAMP_FILE); \
	test -z "`$(FIND) $(MK_INCLUDE_TIMESTAMP_FILE) -mmin +$(MK_INCLUDE_TIMEOUT_MINS) 2>&1`" || { \
	   retries=0; while test 5 -gt $$retries; do \
	      sleep `expr $$retries '*' $$retries '*' $$retries`; \
	      tarball=`$(CURL_LATEST) | $(SED_RELEASE_TARBALL)`; \
	      $(CURL_LOCATION) "$$tarball" --output $(MK_INCLUDE_TIMESTAMP_FILE) && break; \
	      retries=`expr 1 + $$retries`; \
	   done; test 5 -gt $$retries \
	   && $(TAR) zxf $(MK_INCLUDE_TIMESTAMP_FILE) \
	   && rm -rf $(MK_INCLUDE_DIR) \
	   && mv $(GITHUB_OWNER)-$(GITHUB_REPO)-* $(MK_INCLUDE_DIR) \
	   && echo installed $$tarball from $(GITHUB_REPO) \
	   ; \
	} || { \
	   echo 'unable to access $(GITHUB_REPO) fetch API to check for latest release; next try in $(MK_INCLUDE_TIMEOUT_MINS) minutes'; \
	   test -f $(MK_INCLUDE_TIMESTAMP_FILE) && touch $(MK_INCLUDE_TIMESTAMP_FILE); \
	}

.mk-include-check-FORCE:
### END MK-INCLUDE/ BOOTSTRAP ###
