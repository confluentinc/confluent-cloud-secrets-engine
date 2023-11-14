DOCKER_GO_TEST_LOCATION := tests/go-docker-build-test/
DOCKER_MULTIARCH_TEST_LOCATION := tests/multiarch-docker-build-test/
MAVEN_DOCKER_BUILD_TEST := tests/maven-docker-build-test/
MK_INCLUDE_SANITY_IMPORT_TEST_LOCATION := tests/sanity-import-test/
MK_INCLUDE := mk-include/
UPDATE_MK_INCLUDE := false
CC_MK_INCLUDE := cc-mk-include

include ./cc-begin.mk
include ./cc-vault.mk
include ./cc-semver.mk
include ./cc-ci-metrics.mk
include ./cc-pact.mk
include ./cc-sonarqube.mk
include ./cc-testbreak.mk
include ./cc-end.mk

.PHONY: copy-mk-include-install-pact-tools-script
copy-mk-include-install-pact-tools-script:
	cp ./bin/install-pact-tools.sh ${MK_INCLUDE}bin

.PHONY: copy-mk-include-multiarch-docker-build-test
copy-mk-include-multiarch-docker-build-test:
	find . -name '*.mk' | cpio -pdm "${DOCKER_MULTIARCH_TEST_LOCATION}""${MK_INCLUDE}"
	cp -R bin/. "${DOCKER_MULTIARCH_TEST_LOCATION}""${MK_INCLUDE}""bin"
	cp .gitignore "${DOCKER_MULTIARCH_TEST_LOCATION}"

.PHONY: copy-mk-include-go-docker-build-test
copy-mk-include-go-docker-build-test:
	find . -name '*.mk' | cpio -pdm "${DOCKER_GO_TEST_LOCATION}""${MK_INCLUDE}"
	cp -R bin/. "${DOCKER_GO_TEST_LOCATION}""${MK_INCLUDE}""bin"
	cp .gitignore "${DOCKER_GO_TEST_LOCATION}"

.PHONY: copy-mk-include-maven-docker-build-test
copy-mk-include-maven-docker-build-test:
	find . -name '*.mk' | cpio -pdm "${MAVEN_DOCKER_BUILD_TEST}""${MK_INCLUDE}"
	cp -R bin "${MAVEN_DOCKER_BUILD_TEST}""${MK_INCLUDE}"

.PHONY: copy-mk-include-sanity-import-test
copy-mk-include-sanity-import-test:
	find . -name '*.mk' | cpio -pdm "${MK_INCLUDE_SANITY_IMPORT_TEST_LOCATION}""${MK_INCLUDE}"
	cp -R bin "${MK_INCLUDE_SANITY_IMPORT_TEST_LOCATION}""${MK_INCLUDE}"
	cp .gitignore "${MK_INCLUDE_SANITY_IMPORT_TEST_LOCATION}"

.PHONY: copy-parent-mk-include
copy-parent-mk-include:
	find . -name '*.mk' | cpio -pdm "${MK_INCLUDE}"
	cp -R bin/. "${MK_INCLUDE}""bin"

.PHONY: upload-binary
upload-binary:
	. assume-iam-role arn:aws:iam::368821881613:role/semaphore-access ;\
	cd .. ;\
	tar --exclude='$(CC_MK_INCLUDE)/.git' --exclude='$(CC_MK_INCLUDE)/.semaphore' \
	--exclude='$(CC_MK_INCLUDE)/tests' --exclude='$(CC_MK_INCLUDE)/.DS_Store' \
	--exclude='$(CC_MK_INCLUDE)/mk-include' --exclude='$(CC_MK_INCLUDE)/ci-bin' \
	-zcvf $(CC_MK_INCLUDE)_$(BUMPED_VERSION).tar.gz $(CC_MK_INCLUDE) ;\
	aws s3 cp $(CC_MK_INCLUDE)_$(BUMPED_VERSION).tar.gz s3://$(CC_MK_INCLUDE) ;\
	cp $(CC_MK_INCLUDE)_$(BUMPED_VERSION).tar.gz $(CC_MK_INCLUDE)_master.tar.gz ;\
	aws s3 cp $(CC_MK_INCLUDE)_master.tar.gz s3://$(CC_MK_INCLUDE) ;

.PHONY: verify-version
verify-version:
	@[[ "$(VERSION)" =~ ^v[0-9]+\.[0-9]+\.([0-9]+$$|[0-9]+-[0-9]+-[a-zA-Z0-9]+$$) ]] && echo "version format verified"

## The following rules are used to do canary project builds from .semaphore/semaphore.yml
CURL = curl
JQ = jq
TAR = tar

CC_MK_INCLUDE := cc-mk-include

GITHUB_API = api.github.com
GITHUB_API_CC_MK_INCLUDE_RELEASES := https://$(GITHUB_API)/repos/confluentinc/cc-mk-include/releases
CURL_RELEASES := $(CURL) --fail --silent --netrc --location '$(GITHUB_API_CC_MK_INCLUDE_RELEASES)'
JQ_NEWEST_PRERELEASE := $(JQ) --raw-output 'sort_by(.published_at) | .[-1].tarball_url'
JQ_NEWEST_PRERELEASE_VERSION := $(JQ) --raw-output 'sort_by(.published_at) | .[-1].tag_name'

.PHONY: canary-mk-include-uninstall
canary-mk-include-uninstall:
	test -n '$(CANARY_REPO_NAME)'
	rm -rf '../$(CANARY_REPO_NAME)'
	git clone 'git@github.com:confluentinc/$(CANARY_REPO_NAME).git' '../$(CANARY_REPO_NAME)'
	rm -rf '../$(CANARY_REPO_NAME)/mk-include'

../cc-mk-include.tgz:
	@grep -q 'machine $(GITHUB_API)' ~/.netrc 2>/dev/null || { \
	  echo 'error: follow https://confluentinc.atlassian.net/l/cp/0WXXRLDh to fix your ~/.netrc'; \
	  exit 1; \
	}
	newest_prerelease_url=`$(CURL_RELEASES) |$(JQ_NEWEST_PRERELEASE)` || { \
	  echo 'unable to access $(CC_MK_INCLUDE) fetch API to check for latest prerelease' >&2; \
	  exit 1; \
	}; \
	$(CURL) --fail --silent --netrc --location "$$newest_prerelease_url" --output $@ || { \
	  echo "unable to access $$newest_prerelease_url fetch API to fetch latest prerelease" >&2; \
	  exit 1; \
	}

.PHONY: canary-prerelease-init
canary-prerelease-init: ../cc-mk-include.tgz
	$(TAR) -C '../$(CANARY_REPO_NAME)' -zxf $<
	mv '../$(CANARY_REPO_NAME)/confluentinc-cc-mk-include'-* '../$(CANARY_REPO_NAME)/mk-include'
	echo . > '../$(CANARY_REPO_NAME)/.mk-include-timestamp'
	@echo 'Installed cc-mk-include prerelease to $(CANARY_REPO_NAME)/mk-include'

.PHONY: canary-pr-init
canary-pr-init:
	@mkdir '../$(CANARY_REPO_NAME)/mk-include'
	cp -R * '../$(CANARY_REPO_NAME)/mk-include'
	echo . > '../$(CANARY_REPO_NAME)/.mk-include-timestamp'
	@echo 'Installed cc-mk-include from the PR to $(CANARY_REPO_NAME)/mk-include'

CANARY_UPGRADE_MK_INCLUDE = canary-mk-include-uninstall
ifeq ($(BRANCH_NAME), master)
CANARY_UPGRADE_MK_INCLUDE += canary-prerelease-init
else
CANARY_UPGRADE_MK_INCLUDE += canary-pr-init
endif

.PHONY: canary-prerelease-install
canary-prerelease-install: $(CANARY_UPGRADE_MK_INCLUDE)

.PHONY: promote-prerelease-version-tag
promote-prerelease-version-tag:
	newest_prerelease_version=`$(CURL_RELEASES) |$(JQ_NEWEST_PRERELEASE_VERSION)` || { \
	  echo 'unable to access $(CC_MK_INCLUDE) fetch API to check for latest prerelease' >&2; \
	  exit 1; \
	}; \
	gh release delete "$$newest_prerelease_version" --yes \
	&& gh release create "$$newest_prerelease_version" --title "$$newest_prerelease_version" --notes "full release for cc-mk-include users"
