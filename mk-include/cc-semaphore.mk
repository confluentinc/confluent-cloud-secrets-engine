ifeq ($(SEMAPHORE_2),true)
# In Semaphore 2, the cache must be manually managed.
# References:
#   https://docs.semaphoreci.com/article/68-caching-dependencies
#   https://docs.semaphoreci.com/article/54-toolbox-reference#cache

INIT_CI_TARGETS += ci-bin-sem-cache-restore
EPILOGUE_TARGETS += ci-bin-sem-cache-store
DEB_CACHE_DIR ?= $(SEMAPHORE_CACHE_DIR)/.deb-cache
PIP_CACHE_DIR ?= $(shell pip3 cache dir)

ifeq ($(SEMAPHORE_GIT_PR_BRANCH),)
    CACHE_KEY = ci-bin_$(SEMAPHORE_GIT_BRANCH)
else
    CACHE_KEY = ci-bin_$(SEMAPHORE_GIT_PR_BRANCH)
endif

.PHONY: ci-bin-sem-cache-store
ci-bin-sem-cache-store:
	@echo "Storing semaphore caches"
	cache delete $(CACHE_KEY) \
		&& cache store $(CACHE_KEY) ci-bin
	# For most repos, the gocache is very large, so don't delete
	# and restore it. In the (rare) case that the gocache is corrupted 
	# we should just clear it manually in semaphore 
	cache store gocache $(GOPATH)/pkg/mod
	cache delete pip3_cache \
	  	&& cache store pip3_cache $(PIP_CACHE_DIR)
	cache delete install_package_cache \
		&& cache store install_package_cache $(DEB_CACHE_DIR)

.PHONY: ci-bin-sem-cache-restore
ci-bin-sem-cache-restore:
	@echo "Restoring semaphore caches"
	cache restore $(CACHE_KEY),ci-bin_master,ci-bin
	cache restore gocache
	cache restore pip3_cache
	cache restore install_package_cache

.PHONY: ci-bin-sem-cache-delete
ci-bin-sem-cache-delete:
	@echo "Deleting semaphore caches"
	cache delete $(CACHE_KEY)
endif

store-test-results-to-semaphore:
	test-results publish $(BUILD_DIR)/TEST-result.xml

