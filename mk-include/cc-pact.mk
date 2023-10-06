INIT_CI_TARGETS += pact-install
TEST_TARGETS += pact-consumer-test
# Any target that publishes data to the pact broker should run in CI after the artifact has been released,
# so that a pact always corresponds to an existing artifact.
# pact-consumer-publish publishes a consumer pact to the broker
# test-pact-provider tests the provider against a consumer pact and publishes the result to the broker
# both of these publish data to the broker, so must run after the release.
RELEASE_POSTCOMMIT += pact-consumer-publish pact-provider-test

export PATH := $(PWD)/node_modules/.bin:$(PATH):$(PWD)/pact/bin
export PACT_DO_NOT_TRACK := true
# TODO: change this if required by DPTFI-330 or DPTFI-158
export PACT_BROKER_URL := https://pact.aws.stag.cpdev.cloud
# pact cli hardcodes the path where the binaries are installed as ${pwd}/pact
# so let's install the rest of the tooling there too
export PACT_BIN_PATH ?= $(PWD)/pact/bin
PACT_TEST_DIR ?= $(PWD)/test/pact
PACTS_DIR ?= $(PWD)/test/pact/pacts
PACT_TESTS_ENABLED ?= true
PACT_REPORT_SUMMARY_FILE ?= $(BUILD_DIR)/pact-summary.txt
PACT_CONSUMER_TEST_REPORT_FILE ?= $(BUILD_DIR)/PACT-CONSUMER-TEST-result.xml
PACT_PROVIDER_TEST_REPORT_FILE ?= $(BUILD_DIR)/PACT-PROVIDER-TEST-result.xml

export PACT_VERIFIER_VERSION ?= 0.10.6
export PACT_PLUGIN_CLI_VERSION ?= 0.1.0

# PACT_VERSION is the version to use when publishing pacts to the pact broker.
# It should be set to BUMPED_VERSION when running in normal CI and to VERSION when running a webhook job.
# The goal here is to have the PACT_VERSION to correspond to the actual artifact version for which the pact is
# published or verified.
# - In normal CI job, pact verification is run during `make release-ci` step. `release-ci` is called in the middle 
# of the CI build and it makes a commit and releases the artifact under $(BUMPED_VERSION), 
# so that's the version we use when publishing too.
# - Webhook job is run from a specific commit and does not do a version bump, 
# so VERSION corresponds to the version for which we're publishing results.
# - We're not using $(PACT_VERSION) for `can-i-deploy` and `deploy`, because those always run after the release 
# has been done, so $(VERSION) is always the right value to use.
PACT_IS_WEBHOOK ?= $(_empty)
ifeq ($(PACT_IS_WEBHOOK),true)
PACT_VERSION := $(VERSION)
else
PACT_VERSION := $(BUMPED_VERSION)
endif

.PHONY: show-pact
show-pact:
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

# Installs various Pact CLIs and tools
# - ruby CLI
# - rust pact verifier CLI
# - pact plugin manager CLI
# - pact-go (same version as in project's go.mod file)
# - pact-protobuf-plugin (via plugin manager CLI)
.PHONY: pact-install
## Install Pact libs, CLIs and tooling. 
## Will fail if the project doesn't depend on pact-go/v2.
pact-install:
	@CI=$(CI) GIT_ROOT=$(GIT_ROOT) $(MK_INCLUDE_BIN)/install-pact-tools.sh


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
	$(GO) test -v -count=1 -tags=pact.consumer $(PACT_TEST_DIR)
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
pact-provider-test:
ifeq ($(PACT_TESTS_ENABLED),true)
# We intentionally don't set -o pipefail here
# because we don't want provider tests to break builds in CI (unlike the consumer ones).
# Provider tests will test against all consumers deployed across environments + master
# and we don't know which consumer broke the test.
# So instead we record the results to the broker, display them to the user
# and use those results when actually trying to deploy to a specific environment.
# See https://confluentinc.atlassian.net/wiki/spaces/ENV/pages/3157558462/Pact+in+CI
	@echo "--- Running Provider Pact tests"
	VERSION=$(PACT_VERSION) BRANCH_NAME=$(BRANCH_NAME) \
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

.PHONY: pact-deploy
## Record deployment of a service to $(PACT_RELEASE_ENVIRONMENT). Requires $(PACT_RELEASE_ENVIRONMENT) to be set.
pact-deploy: pact-require-environment
ifeq ($(CI),true)
	@echo "--- Pact Broker: record deployment of $(SERVICE_NAME) @ $(VERSION) to $(PACT_RELEASE_ENVIRONMENT)"
	$(PACT_BIN_PATH)/pact-broker create-or-update-version \
		--pacticipant=$(SERVICE_NAME) \
		--version=$(VERSION) \
		--broker-base-url=$(PACT_BROKER_URL)
	$(PACT_BIN_PATH)/pact-broker record-deployment \
		--pacticipant=$(SERVICE_NAME) \
		--version=$(VERSION) \
		--environment=$(PACT_RELEASE_ENVIRONMENT) \
		--broker-base-url=$(PACT_BROKER_URL)
else
	@echo "--- Can only record deployments from CI"
	@echo "--- Exiting"
endif

.PHONY: pact-can-i-deploy
## Check if you can deploy a service to $(PACT_RELEASE_ENVIRONMENT). Requires $(PACT_RELEASE_ENVIRONMENT) to be set.
## Will retry 30 times with 30 seconds intervals if verification results are not yet available.
pact-can-i-deploy: pact-require-environment
	@echo "--- Pact Broker: can-i-deploy $(SERVICE_NAME) @ $(VERSION) to $(PACT_RELEASE_ENVIRONMENT)"
	$(PACT_BIN_PATH)/pact-broker create-or-update-version \
		--pacticipant=$(SERVICE_NAME) \
		--version=$(VERSION) \
		--broker-base-url=$(PACT_BROKER_URL)
	$(PACT_BIN_PATH)/pact-broker can-i-deploy \
		--pacticipant=$(SERVICE_NAME) \
		--version=$(VERSION) \
		--to-environment=$(PACT_RELEASE_ENVIRONMENT) \
		--broker-base-url=$(PACT_BROKER_URL) \
		--retry-while-unknown=30 \
		--retry-interval=30
