_empty :=
_space := $(_empty) $(empty)

# Use this variable to specify a different make utility (e.g. remake --profile)
# Note: not using $(MAKE) here since that runs inside container (different OS)
DOCKER_MAKE ?= make

# List of base images, cannot have colons, replace with a bang
DOCKER_BASE_IMAGES ?= $(subst :,!,$(shell perl -Xlne 's/^FROM\s*(--platform=\S*)?\s*(\S*).*/$$2/ and print' Dockerfile))

# Use this variable to specify docker build options
DOCKER_BUILD_OPTIONS ?=
ifeq ($(CI),true)
	DOCKER_BUILD_OPTIONS += --no-cache --progress plain
endif

# Setup mount options for buildkit
ifneq ($(DOCKER_BUILDKIT),0)
	DOCKER_SSH_MOUNT   ?=
	DOCKER_NETRC_MOUNT ?=
	DOCKER_AWS_MOUNT   ?=
ifneq ($(DOCKER_SSH_MOUNT),)
	DOCKER_BUILD_OPTIONS += --ssh default
endif
ifneq ($(DOCKER_NETRC_MOUNT),)
	DOCKER_BUILD_OPTIONS += --secret id=netrc,src=$(HOME)/.netrc
endif
ifneq ($(DOCKER_AWS_MOUNT),)
	DOCKER_BUILD_OPTIONS += --secret id=aws,src=$(HOME)/.aws/credentials
endif
endif

# Image Name
IMAGE_NAME ?= unknown
ifeq ($(IMAGE_NAME),unknown)
$(error IMAGE_NAME must be set)
endif

# Image Version
#  If we're on CI and a release branch, build with the bumped version
ifeq ($(CI),true)
ifneq ($(RELEASE_BRANCH),$(_empty))
IMAGE_VERSION ?= $(BUMPED_VERSION)
else
IMAGE_VERSION ?= $(VERSION)
endif
else
IMAGE_VERSION ?= $(VERSION)
endif
IMAGE_VERSION_NO_V := $(shell echo $(IMAGE_VERSION) | sed -e 's/^v//')

# Extract the individual semver tags (ex: v1, v1.2, v1.2.3)
IMAGE_VERSION_PARTS ?= $(subst -, ,$(subst ., ,$(IMAGE_VERSION)))
IMAGE_VERSION_MAJOR ?= $(word 1,$(IMAGE_VERSION_PARTS))
IMAGE_VERSION_MINOR ?= $(IMAGE_VERSION_MAJOR).$(word 2,$(IMAGE_VERSION_PARTS))
IMAGE_VERSION_PATCH ?= $(IMAGE_VERSION_MINOR).$(word 3,$(IMAGE_VERSION_PARTS))

IMAGE_REPO ?= confluentinc
ifeq ($(IMAGE_REPO),$(_empty))
BUILD_PATH ?= $(IMAGE_NAME)
else
BUILD_PATH ?= $(IMAGE_REPO)/$(IMAGE_NAME)
endif
BUILD_TAG ?= $(BUILD_PATH):$(IMAGE_VERSION)
BUILD_TAG_LATEST ?= $(BUILD_PATH):latest

# Set targets for standard commands
CACHE_DOCKER_BASE_IMAGES ?= true
ifeq ($(CACHE_DOCKER_BASE_IMAGES),true)
INIT_CI_TARGETS += cache-docker-base-images
endif

RELEASE_POSTCOMMIT += push-docker
BUILD_TARGETS += build-docker
CLEAN_TARGETS += clean-images

DOCKER_BUILD_PRE ?=
DOCKER_BUILD_POST ?=

.PHONY: show-docker
## Show docker variables
show-docker:
	@echo "DOCKER_BASE_IMAGES: $(DOCKER_BASE_IMAGES)"
	@echo "IMAGE_NAME: $(IMAGE_NAME)"
	@echo "IMAGE_VERSION: $(IMAGE_VERSION)"
	@echo "IMAGE_REPO: $(IMAGE_REPO)"
	@echo "BUILD_TAG: $(BUILD_TAG)"
	@echo "BUILD_TAG_LATEST: $(BUILD_TAG_LATEST)"
	@echo "DOCKER_REPO: $(DOCKER_REPO)"
	@echo "DOCKER_BUILD_OPTIONS: $(DOCKER_BUILD_OPTIONS)"

.PHONY: cache-docker-base-images $(DOCKER_BASE_IMAGES:%=docker-cache.%)
## On Semaphore, use the cache to store/restore docker image to reduce transfer costs.
## - use gzip --no-name so the bits are deterministic,
## - always pull, this checks for updates, e.g. 'latest' tag could have been updated,
## - update cache if bits are different.
cache-docker-base-images: $(DOCKER_BASE_IMAGES:%=docker-cache.%)
$(DOCKER_BASE_IMAGES:%=docker-cache.%):
	$(eval image := $(subst !,:,$(@:docker-cache.%=%)))
	cache restore $(image)
	test ! -f base-image.tgz || docker load -i base-image.tgz
	mv base-image.tgz base-image-prev.tgz || echo dummy > base-image-prev.tgz

	# Pull Docker image and check if it's up to date
	docker pull $(image) 2>&1 | tee /tmp/cached-docker-base.log
	cat /tmp/cached-docker-base.log | grep -q "up to date" || echo "outdated" > /tmp/cached-docker-base.log

	# Only cache image and make tarball if we pulled a newer version
	if [ "$$(cat /tmp/cached-docker-base.log)" == "outdated" ]; then \
		docker save $(image) | gzip --no-name > base-image.tgz; \
		cache delete $(image) && cache store $(image) base-image.tgz; \
	fi
	rm -f base-image*.tgz

.PHONY: cache-restore-docker-base-images $(DOCKER_BASE_IMAGES:%=docker-cache.%)
cache-restore-docker-base-images: $(DOCKER_BASE_IMAGES:%=restore-docker-cache.%)
$(DOCKER_BASE_IMAGES:%=restore-docker-cache.%):
	$(eval image := $(subst !,:,$(@:restore-docker-cache.%=%)))
	cache restore $(image)

.PHONY: ssh-add
ssh-add:
ifneq ($(DOCKER_SSH_MOUNT),)
	@echo "Adding keys to agent for ssh support"
	@ssh-add -l | grep -q '@confluent.io' || ssh-add || (echo "Unable to add default identities. Manually add keys to the agent using ssh-add."; exit 1)
endif

.PHONY: build-docker
ifeq ($(BUILD_DOCKER_OVERRIDE),)
## Build just the docker image
build-docker: ssh-add .gitconfig .netrc .ssh $(DOCKER_BUILD_PRE)
ifeq ($(GO_USE_VENDOR),-mod=vendor)
ifneq ($(CI),true)
	@$(MAKE) deps
endif
endif
	docker build $(DOCKER_BUILD_OPTIONS) \
		--label version.$(IMAGE_REPO).$(IMAGE_NAME)=$(IMAGE_VERSION) \
		--build-arg version=$(IMAGE_VERSION) \
		-t $(BUILD_TAG) .
	rm -rf .netrc .ssh .aws .config .gitconfig
ifeq ($(CI),true)
	docker image save $(BUILD_TAG) | gzip | \
		artifact push project /dev/stdin -d docker/$(BRANCH_NAME)/$(IMAGE_VERSION).tgz --force
endif
ifneq ($(DOCKER_BUILD_POST),)
	$(MAKE) $(MAKE_ARGS) $(DOCKER_BUILD_POST)
endif
else
build-docker: ssh-add $(BUILD_DOCKER_OVERRIDE)
endif

.PHONY: restore-docker-version
ifeq ($(RESTORE_DOCKER_OVERRIDE),)
restore-docker-version:
ifeq ($(CI),true)
	artifact pull project docker/$(BRANCH_NAME)/$(IMAGE_VERSION).tgz -d /dev/stdout --force | \
		gunzip | docker image load
endif
else
restore-docker-version: $(RESTORE_DOCKER_OVERRIDE)
endif

.PHONY: tag-docker
tag-docker: tag-docker-version tag-docker-semver tag-docker-latest 

.PHONY: tag-docker-version
tag-docker-version:
	@echo 'create docker tag $(BUILD_PATH):$(IMAGE_VERSION)'
	docker tag $(BUILD_TAG) $(DOCKER_REPO)/$(BUILD_PATH):$(IMAGE_VERSION)

.PHONY: tag-docker-semver
tag-docker-semver:
	@echo 'create docker tag $(BUILD_PATH):$(IMAGE_VERSION_MINOR)'
	docker tag $(BUILD_TAG) $(DOCKER_REPO)/$(BUILD_PATH):$(IMAGE_VERSION_MINOR)
	@echo 'create docker tag $(BUILD_PATH):$(IMAGE_VERSION_MAJOR)'
	docker tag $(BUILD_TAG) $(DOCKER_REPO)/$(BUILD_PATH):$(IMAGE_VERSION_MAJOR)

.PHONY: tag-docker-latest
tag-docker-latest:
	@echo 'create docker tag $(BUILD_TAG_LATEST)'
	docker tag $(BUILD_TAG) $(DOCKER_REPO)/$(BUILD_TAG_LATEST)

.PHONY: push-docker
ifeq ($(PUSH_DOCKER_OVERRIDE),)
ifeq ($(CI),true)
push-docker: push-docker-version push-docker-semver push-docker-latest
else
push-docker: push-docker-version
endif
else
push-docker: $(PUSH_DOCKER_OVERRIDE)
endif

.PHONY: push-docker-latest
push-docker-latest: tag-docker-latest
	@echo 'push latest to $(DOCKER_REPO)'
	docker push $(DOCKER_REPO)/$(BUILD_TAG_LATEST) || docker push $(DOCKER_REPO)/$(BUILD_TAG_LATEST)

.PHONY: push-docker-version
## Push the current version of docker to artifactory
push-docker-version: restore-docker-version tag-docker-version
	@echo 'push $(BUILD_TAG) to $(DOCKER_REPO)'
	docker push $(DOCKER_REPO)/$(BUILD_TAG) || docker push $(DOCKER_REPO)/$(BUILD_TAG)

.PHONY: push-docker-semver
push-docker-semver: restore-docker-version tag-docker-semver
	@echo 'push $(BUILD_PATH):$(IMAGE_VERSION_MINOR) to $(DOCKER_REPO)'
	docker push $(DOCKER_REPO)/$(BUILD_PATH):$(IMAGE_VERSION_MINOR) || docker push $(DOCKER_REPO)/$(BUILD_PATH):$(IMAGE_VERSION_MINOR)
	@echo 'push $(BUILD_PATH):$(IMAGE_VERSION_MAJOR) to $(DOCKER_REPO)'
	docker push $(DOCKER_REPO)/$(BUILD_PATH):$(IMAGE_VERSION_MAJOR) || docker push $(DOCKER_REPO)/$(BUILD_PATH):$(IMAGE_VERSION_MAJOR)

.PHONY: sox-log-docker-sha
sox-log-docker-sha:
ifeq ($(CI),true)
	pip3 install confluent-ci-tools
	$(eval IMAGE_SHA := $(shell docker inspect --format="{{index .RepoDigests 0}}" "$(DOCKER_REPO)/$(BUILD_TAG)"))
	@echo "Reporting docker image information event for $(DOCKER_REPO)/$(BUILD_TAG), image sha: $(IMAGE_SHA)"
	ci-docker-image-semaphore-event --topic 'sox-sdlc-audit-automation' --version-tag $(IMAGE_VERSION) --sha256 $(IMAGE_SHA) --config-file $(HOME)/.sox-semaphore-build-info.ini
endif

.PHONY: clean-images
clean-images:
	docker images -q -f label=io.confluent.caas=true -f reference='*$(IMAGE_NAME)' | uniq | $(XARGS) docker rmi -f

.PHONY: clean-all
clean-all:
	docker images -q -f label=io.confluent.caas=true | uniq | $(XARGS) docker rmi -f
