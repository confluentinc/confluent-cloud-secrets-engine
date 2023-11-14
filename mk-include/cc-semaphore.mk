TEST_RESULT_FILE_NAME ?= *TEST-result.xml
TEST_RESULT_FILE ?= $(BUILD_DIR)/$(TEST_RESULT_FILE_NAME)

GO_COVERAGE_HTML ?= coverage.html
COVERAGE_REPORT_URL := $(SEMAPHORE_ORGANIZATION_URL)/jobs/$(SEMAPHORE_JOB_ID)/artifacts/$(GO_COVERAGE_HTML)

ifeq ($(SEMAPHORE_2),true)
# In Semaphore 2, the cache must be manually managed.
# References:
#   https://docs.semaphoreci.com/article/68-caching-dependencies
#   https://docs.semaphoreci.com/article/54-toolbox-reference#cache

INIT_CI_TARGETS += ci-bin-sem-cache-restore
EPILOGUE_TARGETS += ci-bin-sem-cache-store store-test-results-to-semaphore
DEB_CACHE_DIR ?= $(SEMAPHORE_CACHE_DIR)/.deb-cache
PIP_CACHE_DIR ?= $(shell pip3 cache dir)
CI_BIN_CACHE_KEY = $(CI_BIN)
current_time := $(shell date +"%s")

.PHONY: ci-bin-sem-cache-store
ci-bin-sem-cache-store:
ifneq ($(SEMAPHORE_GIT_REF_TYPE),pull-request)
	@echo "Storing semaphore caches"
	# cache restore allows fuzzy matching. When it finds multiple matches, it will select the most recent cache archive.
	# Additionally, it will not overwrite an existing cache archive with the same key.
	# Therefore, we store the cache with a timestamp in the key to avoid collisions.
	cache store $(CI_BIN_CACHE_KEY)_$(current_time) $(CI_BIN)
	cache store gocache_$(current_time) $(GOPATH)/pkg/mod
	cache store pip3_cache_$(current_time) $(PIP_CACHE_DIR)
	cache store install_package_cache_$(current_time) $(DEB_CACHE_DIR)
	cache store maven_cache_$(current_time) $(HOME)/.m2/repository
endif

.PHONY: ci-bin-sem-cache-restore
ci-bin-sem-cache-restore:
	@echo "Restoring semaphore caches"
	cache restore $(CI_BIN_CACHE_KEY)
	cache restore gocache
	cache restore pip3_cache
	cache restore install_package_cache
	cache restore maven_cache

.PHONY: ci-bin-sem-cache-delete
ci-bin-sem-cache-delete:
	@echo "Deleting semaphore caches"
	cache delete $(CI_BIN_CACHE_KEY)
endif

.PHONY: ci-generate-and-store-coverage-data
ci-generate-and-store-coverage-data: $(GO_COVERAGE_HTML) print-coverage-out
	artifact push job $(GO_COVERAGE_HTML)

.PHONY: ci-coverage
ci-coverage: ci-generate-and-store-coverage-data go-gate-coverage
	@echo "find coverate report at: $(COVERAGE_REPORT_URL)"

.PHONY: store-test-results-to-semaphore
store-test-results-to-semaphore:
ifneq ($(wildcard $(TEST_RESULT_FILE)),)
ifeq ($(TEST_RESULT_NAME),)
	test-results publish $(TEST_RESULT_FILE) --force
else
	test-results publish $(TEST_RESULT_FILE) --name "$(TEST_RESULT_NAME)"
endif
else
	@echo "test results not found at $(TEST_RESULT_FILE)"
endif
