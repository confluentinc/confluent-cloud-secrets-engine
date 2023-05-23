ENABLE_PARALLELISM ?= false
TESTS_TIMEOUT ?= 420m
ENABLE_MASTER_TO_STAG_PROMOTION ?= false
ENABLE_MASTER_TO_CPD_PROMOTION ?= false
BRANCH_TO_PROMOTE_FROM_MASTER ?=
TESTS_TO_RUN_ON_PR_BRANCH ?=


GO_TEST_ARGS = -timeout=$(TESTS_TIMEOUT) -count=1
ifeq ($(ENABLE_PARALLELISM),true)
# detect potential race condition caused by parallel test packages
GO_TEST_ARGS += -race
else
GO_TEST_ARGS += -p 1
endif
ifdef TESTS_TO_RUN
GO_TEST_ARGS += -run $(TESTS_TO_RUN)
endif

.PHONY: check-not-prod
# Checks that targets are not being run from the production environment. Prereq for system test related make targets.
check-not-prod:
ifeq ($(ENV),prod)
	@echo "Error: Attempted to run unsafe target in production environment"
	@echo "If you are trying to run synthetic tests in production, please use make test-go-synthetic" && exit 1
endif

# This can't be part of the normal init-ci setup because it's called from the bastion, via run_tests.sh, not from CI
.PHONY: init-env
init-env: check-not-prod
	go run cmd/init-env/*

.PHONY: ci-runner
ci-runner: check-not-prod
	@echo BUILD_DIR=$(BUILD_DIR)
	@echo ENABLE_MASTER_TO_STAG_PROMOTION=$(ENABLE_MASTER_TO_STAG_PROMOTION)
	@echo ENABLE_MASTER_TO_CPD_PROMOTION=$(ENABLE_MASTER_TO_CPD_PROMOTION)
	@echo EXTRA_BRANCH_TO_PROMOTE_FROM_MASTER=$(EXTRA_BRANCH_TO_PROMOTE_FROM_MASTER)
	ENABLE_MASTER_TO_STAG_PROMOTION=$(ENABLE_MASTER_TO_STAG_PROMOTION) \
	ENABLE_MASTER_TO_CPD_PROMOTION=$(ENABLE_MASTER_TO_CPD_PROMOTION) \
	EXTRA_BRANCH_TO_PROMOTE_FROM_MASTER="$(EXTRA_BRANCH_TO_PROMOTE_FROM_MASTER)" \
	TESTS_TO_RUN_ON_PR_BRANCH=$(TESTS_TO_RUN_ON_PR_BRANCH) \
		$(MK_INCLUDE_BIN)/cc-system-tests/ci_runner.sh

.PHONY: show-system-test-args
show-go: show-system-test-args
show-system-test-args:
	@echo "TESTS_TIMEOUT: $(TESTS_TIMEOUT)"
	@echo "TESTS_TO_RUN: $(TESTS_TO_RUN)"
	@echo "GO_TEST_ARGS: $(GO_TEST_ARGS)"
	@echo "ENABLE_MASTER_TO_STAG_PROMOTION: $(ENABLE_MASTER_TO_STAG_PROMOTION)"
	@echo "ENABLE_MASTER_TO_CPD_PROMOTION: $(ENABLE_MASTER_TO_CPD_PROMOTION)"
	@echo "EXTRA_BRANCH_TO_PROMOTE_FROM_MASTER: $(EXTRA_BRANCH_TO_PROMOTE_FROM_MASTER)"

# override target test-go in cc-go.mk
.PHONY: test-go
# Run Go Tests and Vet code
# Remove GO_MOD_DOWNLOAD_MODE_FLAG
test-go: check-not-prod vet
	@echo "Running make test-go target in $(ENV)"
	test -f coverage.txt && truncate -s 0 coverage.txt || true
ifeq ($(ENABLE_PARALLELISM),true)
	@echo "ENABLE_PARALLELISM set to true, system tests packages running in parallel..."
endif
	set -o pipefail && $(GO_TEST_SETUP_CMD) && $(GO) test -coverprofile=coverage.txt $(GO_TEST_ARGS) $(GO_TEST_PACKAGE_ARGS) -json | $(MK_INCLUDE_BIN)/decode_test2json.py

.PHONY: test-go-synthetic
# Run Synthetic Go Tests and Vet code
# Can run tests in PROD, DO NOT use to run system tests
test-go-synthetic: vet
ifeq (,$(findstring synthetic,$(GO_TEST_REPO_NAME) $(GO_TEST_PACKAGE_ARGS)))
	@echo "Error: Keyword 'synthetic' not found in either GO_TEST_REPO_NAME or GO_TEST_PACKAGE_ARGS"
	@echo "make test-go-synthetic can only be used to run synthetic tests, please make sure GO_TEST env vars are set \
	properly or that your synthetic test repo/package is named correctly" && exit 1
endif
	@echo "Running make test-go-synthetic in $(ENV)"
	set -o pipefail && $(GO_TEST_SETUP_CMD) && $(GO) test -coverprofile=coverage.txt $(GO_TEST_ARGS) $(GO_TEST_PACKAGE_ARGS) -json | $(MK_INCLUDE_BIN)/decode_test2json.py
