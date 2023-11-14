# pact tools need to be installed for make build to work.
INIT_CI_TARGETS += pact-install

test-pyramid-pre-steps:
test-pyramid-code-quality:
test-pyramid-unit-tests:
test-pyramid-local-mode-tests:
test-pyramid-component-tests:
test-pyramid-contract-tests: pact-consumer-test
test-pyramid-integration-tests:
test-pyramid-e2e-tests:
test-pyramid-post-steps:

# Any target that publishes data to the pact broker should run in CI after the artifact has been released,
# so that a pact always corresponds to an existing artifact.
# pact-consumer-publish publishes a consumer pact to the broker
# test-pact-provider tests the provider against a consumer pact and publishes the result to the broker
# both of these publish data to the broker, so must run after the release.
RELEASE_POSTCOMMIT += pact-consumer-publish pact-provider-test

# Run can-i-deploy before we actually deploy a service and record the deployment afterwards.
HALYARD_PRE_DEPLOY += pact-can-i-deploy-halyard
HALYARD_POST_DEPLOY += pact-deploy-halyard

export PACT_DO_NOT_TRACK ?= true

# TODO: change this if required by DPTFI-330 or DPTFI-158
export PACT_BROKER_URL ?= https://pact.aws.stag.cpdev.cloud
# pact cli hardcodes the path where the binaries are installed as ${CURDIR}/pact
# so let's install the rest of the tooling there too
PACT_BIN_PATH ?= $(CURDIR)/pact/bin
PACT_TEST_DIR ?= $(CURDIR)/test/pact
PACTS_DIR ?= $(CURDIR)/test/pact/pacts
PACT_TESTS_ENABLED ?= true
PACT_REPORT_SUMMARY_FILE ?= $(BUILD_DIR)/pact-summary.txt
ifeq ($(CI),true)
PACT_CONSUMER_TEST_REPORT_FILE ?= $(BUILD_DIR)/$(SEMAPHORE_PIPELINE_ID)-PACT-CONSUMER-TEST-result.xml
PACT_PROVIDER_TEST_REPORT_FILE ?= $(BUILD_DIR)/$(SEMAPHORE_PIPELINE_ID)-PACT-PROVIDER-TEST-result.xml
else
PACT_CONSUMER_TEST_REPORT_FILE ?= $(BUILD_DIR)/PACT-CONSUMER-TEST-result.xml
PACT_PROVIDER_TEST_REPORT_FILE ?= $(BUILD_DIR)/PACT-PROVIDER-TEST-result.xml
endif
export PATH := $(CURDIR)/node_modules/.bin:$(PATH):$(PACT_BIN_PATH)
PACT_VERIFIER_VERSION ?= 0.10.6
PACT_PLUGIN_CLI_VERSION ?= 0.1.0
PACT_PROTOBUF_PLUGIN_VERSION ?= 0.3.6
PACT_PROTOC_VERSION ?= 3.20.3

# Setting this to true will allow deploying a service even if can-i-deploy fails.
# This makes can-i-deploy command always return success, even if verifications failed.
PACT_BROKER_CAN_I_DEPLOY_DRY_RUN ?= false

# Set this to a list of pacticipants to ignore during can-i-deploy command.
# Should only be used in either "break-glass" situations or when you're rolling back to a version
# that doesn't have a contract with that specific pacticipant yet (but has contracts with other services)
# Comma-separated list of pacticipant names.
PACT_BROKER_CAN_I_DEPLOY_IGNORE ?=

# PACT_VERSION is the version to use when publishing pacts to the pact broker.
# It should be set to BUMPED_VERSION when running in normal CI and to VERSION when running a webhook job.
# The goal here is to have the PACT_VERSION to correspond to the actual artifact version for which the pact is
# published or verified.
# - In normal CI job, pact verification is run during `make release-ci` step. `release-ci` is called in the middle 
# of the CI build and it makes a commit and releases the artifact under $(BUMPED_VERSION), 
# so that's the version we use when publishing too.
# - Webhook job is run from a specific commit and does not do a version bump, 
# so VERSION corresponds to the version for which we're publishing results.
# - We're not using $(PACT_VERSION) for `can-i-deploy` and `deploy`, those use a different variable altogether
PACT_IS_WEBHOOK ?= $(_empty)
ifeq ($(PACT_IS_WEBHOOK),true)
PACT_VERSION := $(VERSION)
else
PACT_VERSION := $(BUMPED_VERSION)
endif

.PHONY: show-pact
show-pact:
	@echo "GIT_ROOT:                       $(GIT_ROOT)"
	@echo "CURDIR:                         $(CURDIR)"
	@echo "PACT_TESTS_ENABLED:             $(PACT_TESTS_ENABLED)"
	@echo "PACT_VERSION:                   $(PACT_VERSION)"
	@echo "PACT_IS_WEBHOOK:                $(PACT_IS_WEBHOOK)"
	@echo "PACT_BROKER_URL:                $(PACT_BROKER_URL)"
	@echo "PACT_BIN_PATH:                  $(PACT_BIN_PATH)"
	@echo "PACT_TEST_DIR:                  $(PACT_TEST_DIR)"
	@echo "PACTS_DIR:                      $(PACTS_DIR)"
	@echo "PACT_DO_NOT_TRACK:              $(PACT_DO_NOT_TRACK)"
	@echo "PACT_REPORT_SUMMARY_FILE:       $(PACT_REPORT_SUMMARY_FILE)"
	@echo "PACT_CONSUMER_TEST_REPORT_FILE: $(PACT_CONSUMER_TEST_REPORT_FILE)"
	@echo "PACT_PROVIDER_TEST_REPORT_FILE: $(PACT_PROVIDER_TEST_REPORT_FILE)"
	@echo "PACT_VERIFIER_VERSION:          $(PACT_VERIFIER_VERSION)"
	@echo "PACT_PLUGIN_CLI_VERSION:        $(PACT_PLUGIN_CLI_VERSION)"
	@echo "PACT_PROTOBUF_PLUGIN_VERSION:   $(PACT_PROTOBUF_PLUGIN_VERSION)"
	@echo "PACT_PROTOC_VERSION:            $(PACT_PROTOC_VERSION)"


.PHONY: pact-cli-install
## Installs main pact CLI
pact-cli-install:
	@echo "Installing pact ruby CLI (latest)"
	curl -fsSL https://raw.githubusercontent.com/pact-foundation/pact-ruby-standalone/master/install.sh | bash


.PHONY: pact-tools-install
## Installs additional pact tools and libs
## Will fail if the project is in go and doesn't depend on pact-go/v2.
# - rust pact verifier CLI
# - pact plugin manager CLI
# - pact-go (same version as in project's go.mod file)
# - pact-protobuf-plugin (via plugin manager CLI)
pact-tools-install: pact-cli-install
	@CI=$(CI) GIT_ROOT=$(GIT_ROOT) PACT_BIN_PATH=$(PACT_BIN_PATH) \
	PACT_VERIFIER_VERSION=$(PACT_VERIFIER_VERSION) PACT_PLUGIN_CLI_VERSION=$(PACT_PLUGIN_CLI_VERSION) \
	PACT_PROTOBUF_PLUGIN_VERSION=$(PACT_PROTOBUF_PLUGIN_VERSION) \
	PACT_PROTOC_VERSION=$(PACT_PROTOC_VERSION) \
	$(MK_INCLUDE_BIN)/install-pact-tools.sh


.PHONY: pact-install
## Install Pact libs, CLIs and tooling. 
## Will fail if the project is in go and doesn't depend on pact-go/v2.
pact-install: pact-cli-install pact-tools-install


.PHONY: pact-test
## Run all pact tests (provider and consumer both).
## Mostly intended for local testing.
## Provider tests might also publish their verification results to pact broker.
## Results will be published under $(PACT_VERSION).
pact-test: pact-consumer-test pact-provider-test

.PHONY: pact-consumer-test
## Run pact consumer tests. Consumer tests generate pact files, but don't publish them.
pact-consumer-test:
ifeq ($(PACT_TESTS_ENABLED),true)
# Unlike the provider tests (see below), it's a good idea to break the build on consumer tests.
# Because if your consumer test failed, this is most likely a programming error local to your codebase.
	@echo "--- Running Consumer Pact tests "
	set -o pipefail && \
	$(GO) test -v -count=1 -tags=pact.consumer $(PACT_TEST_DIR) -json | \
	TEST_REPORT_FILE=$(PACT_CONSUMER_TEST_REPORT_FILE) \
	$(MK_INCLUDE_BIN)/decode_test2json.py
else
	@echo "--- Skipping pact tests"
endif

# We're using `if` condition here to check if there's at least one .json file under $PACTS_DIR
# cause if there are none, `pact-broker publish` would return an error.
# We have no other way of knowing if there are any consumer pacts that require publishing.
.PHONY: pact-consumer-publish
## Publish a consumer pact to the pact broker.
## Pact will be published with $(PACT_VERSION).
pact-consumer-publish:
ifeq ($(CI),true)
ifeq ($(BRANCH_NAME),$(MASTER_BRANCH))
	if ls $(PACTS_DIR)/*.json &>/dev/null; then \
		echo "--- Publishing Consumer Pacts to the Pact Broker"; \
		$(PACT_BIN_PATH)/pact-broker publish $(PACTS_DIR) \
			--consumer-app-version $(PACT_VERSION) \
			--branch $(BRANCH_NAME) \
			--broker-base-url $(PACT_BROKER_URL); \
	else \
		echo "--- No pacts found under $(PACTS_DIR); skip publishing"; \
	fi
else
	@echo "--- not on $(MASTER_BRANCH) branch, skip publishing pacts. Actual branch name is $(BRANCH_NAME)"
endif
else
	@echo "--- not running in CI, skip publishing pacts"
endif

.PHONY: pact-provider-test
## Run pact provider tests.
## Provider tests might also publish their verification results to pact broker.
## Results will be published under $(PACT_VERSION).
pact-provider-test: pact-broker-connectivity-check
ifeq ($(PACT_TESTS_ENABLED),true)
# We intentionally don't set -o pipefail here
# because we don't want provider tests to break builds in CI (unlike the consumer ones).
# Provider tests will test against all consumers deployed across environments + master
# and we don't know which consumer broke the test.
# So instead we record the results to the broker, display them to the user
# and use those results when actually trying to deploy to a specific environment.
# See https://confluentinc.atlassian.net/wiki/spaces/ENV/pages/3157558462/Pact+in+CI
	@echo "--- Running Provider Pact tests"
	VERSION=$(PACT_VERSION) BRANCH_NAME=$(BRANCH_NAME) CI=$(CI) RELEASE_BRANCH=$(RELEASE_BRANCH) \
	PACT_BROKER_URL=$(PACT_BROKER_URL) \
	$(GO) test -v -count=1 -tags=pact.provider $(PACT_TEST_DIR) -json | \
	TEST_REPORT_FILE=$(PACT_PROVIDER_TEST_REPORT_FILE) \
	$(MK_INCLUDE_BIN)/decode_test2json.py

	$(MK_INCLUDE_BIN)/extract_pact_provider_summary.py \
	$(PACT_PROVIDER_TEST_REPORT_FILE) \
	-o $(PACT_REPORT_SUMMARY_FILE)

ifeq ($(CI),true)
	$(MK_INCLUDE_BIN)/comment-pr.sh $(PACT_REPORT_SUMMARY_FILE)
endif
else
	@echo "--- Skipping pact tests"
endif

.PHONY: pact-webhook
pact-webhook: pact-provider-test

.PHONY: pact-broker-connectivity-check
## Check if pact broker is reachable. Only runs in CI.
pact-broker-connectivity-check:
ifeq ($(CI),true)
	@echo "--- Checking connectivity to Pact Broker"
	@(curl -sS $(PACT_BROKER_URL) >/dev/null && echo "Pact Broker is reachable") || (echo "Pact Broker is not reachable."; exit 1)
endif

.PHONY: pact-require-environment
pact-require-environment:
# built-in `ifndef` is evaluated at parse-time
# so if PACT_RELEASE_ENVIRONMENT is defined in a different make file or simply below this target
# it would not see it.
# Shell `if` is evaluated at execution time, after all make files have been parsed,
# so doesn't matter if you define PACT_RELEASE_ENVIRONMENT before or after this target
	@if [ -z $(PACT_RELEASE_ENVIRONMENT) ]; then \
		echo "PACT_RELEASE_ENVIRONMENT is empty or not defined"; \
		exit 1; \
	fi

.PHONY: pact-require-version
pact-require-version:
	@if [ -z $(PACT_DEPLOY_VERSION) ]; then \
		echo "PACT_DEPLOY_VERSION is empty or not defined"; \
		exit 1; \
	fi

.PHONY: pact-deploy
## Record deployment of a service to $(PACT_RELEASE_ENVIRONMENT). Requires $(PACT_RELEASE_ENVIRONMENT) 
## and $(PACT_DEPLOY_VERSION) to be set.
pact-deploy: pact-require-environment pact-require-version
ifeq ($(CI),true)
	@echo "--- Pact Broker: record deployment of $(PACTICIPANT_NAME) @ $(PACT_DEPLOY_VERSION) to $(PACT_RELEASE_ENVIRONMENT)"
	$(PACT_BIN_PATH)/pact-broker create-or-update-version \
		--pacticipant=$(PACTICIPANT_NAME) \
		--version=$(PACT_DEPLOY_VERSION) \
		--broker-base-url=$(PACT_BROKER_URL)
	$(PACT_BIN_PATH)/pact-broker record-deployment \
		--pacticipant=$(PACTICIPANT_NAME) \
		--version=$(PACT_DEPLOY_VERSION) \
		--environment=$(PACT_RELEASE_ENVIRONMENT) \
		--broker-base-url=$(PACT_BROKER_URL)
else
	@echo "--- Can only record deployments from CI"
	@echo "--- Exiting"
endif

.PHONY: pact-can-i-deploy
## Check if you can deploy a service to $(PACT_RELEASE_ENVIRONMENT). 
## Requires $(PACT_RELEASE_ENVIRONMENT) and $(PACT_DEPLOY_VERSION) to be set.
## Will retry 30 times with 30 seconds intervals if verification results are not yet available.
## Will allow deployment if the given version does not exist in the broker. 
## This is to allow rollbacks to older service versions.
## Will allow deployment if the given version does not exist in the broker. 
## This is to allow rollbacks to older service versions.
pact-can-i-deploy: pact-require-environment pact-require-version
	@PACT_BIN_PATH=$(PACT_BIN_PATH) PACTICIPANT_NAME=$(PACTICIPANT_NAME) PACT_DEPLOY_VERSION=$(PACT_DEPLOY_VERSION) \
	PACT_BROKER_URL=$(PACT_BROKER_URL) PACT_RELEASE_ENVIRONMENT=$(PACT_RELEASE_ENVIRONMENT) \
	PACT_BROKER_CAN_I_DEPLOY_DRY_RUN=$(PACT_BROKER_CAN_I_DEPLOY_DRY_RUN) \
	PACT_BROKER_CAN_I_DEPLOY_IGNORE=$(PACT_BROKER_CAN_I_DEPLOY_IGNORE) \
	$(MK_INCLUDE_BIN)/pact-can-i-deploy.sh

# Important: halyard will report version as 1.0.0, but pact operates with v-version, like v1.0.0
.PHONY: pact-can-i-deploy-halyard
pact-can-i-deploy-halyard:
	PACT_DEPLOY_VERSION=v$(src_version) PACT_RELEASE_ENVIRONMENT=$(env) PACTICIPANT_NAME=$(svc) $(MAKE) $(MAKE_ARGS) pact-can-i-deploy

.PHONY: pact-deploy-halyard
pact-deploy-halyard:
	PACT_DEPLOY_VERSION=v$(src_version) PACT_RELEASE_ENVIRONMENT=$(env) PACTICIPANT_NAME=$(svc) $(MAKE) $(MAKE_ARGS) pact-deploy
