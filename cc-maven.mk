BUILD_TARGETS += mvn-install build-mvn-sbom
CLEAN_TARGETS += mvn-clean
TEST_TARGETS +=  test-mvn-malware mvn-verify
RELEASE_PRECOMMIT += mvn-set-bumped-version
RELEASE_POSTCOMMIT += mvn-deploy

MAVEN_RETRY_COUNT = 3
MAVEN_RETRY_OPTS = -Dmaven.wagon.http.retryHandler.count=$(MAVEN_RETRY_COUNT)
MAVEN_ARGS ?= --no-transfer-progress
MAVEN_ADDITIONAL_ARGS ?=
MAVEN_ARGS += $(MAVEN_ADDITIONAL_ARGS)
MAVEN_NANO_VERSION ?= false
ifeq ($(CI),true)
MAVEN_ARGS += --batch-mode
MAVEN_ARGS += -Dmaven.artifact.threads=10
MAVEN_ARGS += $(MAVEN_RETRY_OPTS)
#disable OWASP dependency checks ~2 minutes shaved, no one looks at them anyways
MAVEN_ARGS += -Ddependency-check.skip=true
# enable CI profile for spotbugs, test-coverage, and dependency analysis
MAVEN_PROFILES += jenkins
endif

# Use predefine MVN or local `mvnw` if present in the repo, else fallback to globally installed `mvn`
ifeq ($(wildcard $(MVN)),)
MVN := $(GIT_ROOT)/mvnw
endif
ifeq ($(wildcard $(MVN)),)
MVN := mvn
endif
MVN += $(MAVEN_ARGS)
MVN += $(foreach profile,$(MAVEN_PROFILES),-P$(profile))

MAVEN_SKIP_CHECKS=-DskipTests=true \
        -Dcheckstyle.skip=true \
        -Dspotbugs.skip=true \
        -Djacoco.skip=true \
        -Ddependency-check.skip=true

MAVEN_INSTALL_OPTS ?= --update-snapshots $(MAVEN_SKIP_CHECKS)
MAVEN_INSTALL_ARGS = $(MAVEN_INSTALL_OPTS) install

MAVEN_DEPLOY_REPO_ID ?= confluent-codeartifact-internal
MAVEN_DEPLOY_REPO_NAME ?= maven-releases
MAVEN_DEPLOY_REPO_URL ?= https://confluent-519856050701.d.codeartifact.us-west-2.amazonaws.com/maven/$(MAVEN_DEPLOY_REPO_NAME)/

BUILD_FULLNAME = $(IMAGE_NAME)-$(HOST_OS)-$(ARCH)
JIRA_TOKEN =$(shell echo $(JIRA_B64_TOKEN) |tr -d '[:space:]')

.PHONY: mvn-install
mvn-install:
ifneq ($(MAVEN_INSTALL_PROFILES),)
	$(MVN) $(foreach profile,$(MAVEN_INSTALL_PROFILES),-P$(profile)) $(MAVEN_INSTALL_ARGS)
else
	$(MVN) $(MAVEN_INSTALL_ARGS)
endif

ifeq ($(CI),true)
mvn-install: mvn-set-bumped-version
endif

.PHONY: build-mvn-sbom
build-mvn-sbom:
ifeq ($(CI),true)
	echo "Building the SBOM in ./target directory of $(BUILD_FULLNAME)"
	mvn -Daether.dependencyCollector.impl=bf -Dmaven.artifact.threads=8  org.cyclonedx:cyclonedx-maven-plugin:2.7.9:makeAggregateBom -DskipTests --no-transfer-progress
	cp target/bom.json $(BUILD_FULLNAME)-maven.json
	trivy fs --skip-dirs mk-include . --format cyclonedx -o $(BUILD_FULLNAME)-trivy-sbom.json
	. assume-iam-role arn:aws:iam::368821881613:role/semaphore-access ;\
	aws s3 cp $(BUILD_FULLNAME)-maven.json s3://confluent-buildtime-sboms/$(IMAGE_NAME)/$(BUMPED_VERSION)/$(BUILD_FULLNAME)-maven.json ;\
	aws s3 cp $(BUILD_FULLNAME)-trivy-sbom.json s3://confluent-buildtime-sboms/$(IMAGE_NAME)/$(BUMPED_VERSION)/$(BUILD_FULLNAME)-trivy-sbom.json
else
	@echo "SBOM generation is only invoked in CI builds"
endif

.PHONY: mvn-verify
mvn-verify:
	$(MVN) $(MAVEN_VERIFY_OPTS) verify

.PHONY: test-mvn-malware
test-mvn-malware:
ifeq ($(CI),true)
	echo "Malware scan for $(BUILD_FULLNAME)"
	@clamscan -d /tmp/clamav-db --max-scansize=1024M --max-filesize=1024M -ir .  > $(BUILD_FULLNAME)-malware-scan.txt \
	|| ( . assume-iam-role arn:aws:iam::368821881613:role/semaphore-access ;\
	aws s3 cp $(BUILD_FULLNAME)-malware-scan.txt s3://malware-scan-results/$(IMAGE_NAME)/$(BUMPED_VERSION)/$(BUILD_FULLNAME)-malware-scan.txt ;\
	echo '{"fields":{"project":{"key":"APPSEC"},"summary":"Malware scan failed for: $(BUILD_FULLNAME)-$(BUMPED_VERSION).","description":"Check the build $(BUILD_FULLNAME)-$(BUMPED_VERSION)","issuetype":{"name":"Task"}}}' > data.json ;\
	curl  -H "Authorization: Basic $(JIRA_TOKEN)"  -H "Content-Type: application/json"  -X POST --data "@data.json" https://confluentinc.atlassian.net/rest/api/2/issue/ &> /dev/null ;\
	echo "Job has failed due to the malware scan failure please notify #appsec"; false)
## we always need to upload the malware scan results
	. assume-iam-role arn:aws:iam::368821881613:role/semaphore-access ;\
	aws s3 cp $(BUILD_FULLNAME)-malware-scan.txt s3://malware-scan-results/$(IMAGE_NAME)/$(BUMPED_VERSION)/$(BUILD_FULLNAME)-malware-scan.txt
else
	@echo "Malware scan is only invoked in CI builds"
endif

.PHONY: mvn-clean
mvn-clean:
	$(MVN) clean

# Alternatively, set <maven.deploy.skip>true</maven.deploy.skip> in your pom.xml to skip deployment
.PHONY: mvn-deploy
mvn-deploy:
	$(MVN) deploy $(MAVEN_SKIP_CHECKS) -DaltDeploymentRepository=$(MAVEN_DEPLOY_REPO_ID)::default::$(MAVEN_DEPLOY_REPO_URL) -DrepositoryId=$(MAVEN_DEPLOY_REPO_ID)

# Set the version in pom.xml to the bumped version
.PHONY: mvn-set-bumped-version
ifeq ($(MAVEN_NANO_VERSION),false)
mvn-set-bumped-version:
	$(MVN) versions:set \
		-DnewVersion=$(BUMPED_CLEAN_VERSION) \
		-DgenerateBackupPoms=false
	$(GIT) add --verbose $(shell find . -name pom.xml -maxdepth 2)
else
mvn-set-bumped-version: mvn-bump-nanoversion
endif

# Other projects have a superstitious dependency on docker-pull-base here
# instead of letting `docker build` just automatically pull the base image.
# If we start seeing build issues on MacOS we can resurrect this dependency.
# https://confluent.slack.com/archives/C6KU9M23A/p1559867903037100
#
#BASE_IMAGE := 519856050701.dkr.ecr.us-west-2.amazonaws.com/docker/prod/confluentinc/cc-base
#BASE_VERSION := v3.2.0
#mvn-docker-package: docker-pull-base
.PHONY: mvn-docker-package
mvn-docker-package:
	$(MVN) package \
	        $(MAVEN_SKIP_CHECKS) \
		--activate-profiles docker \
		-Ddocker.tag=$(IMAGE_VERSION) \
		-Ddocker.registry=$(DOCKER_REPO)/ \
		-DGIT_COMMIT=$(shell git describe --always --dirty) \
		-DBUILD_NUMBER=$(BUILD_NUMBER)
	docker tag $(DOCKER_REPO)/confluentinc/$(IMAGE_NAME):$(IMAGE_VERSION) \
		confluentinc/$(IMAGE_NAME):$(IMAGE_VERSION)

ifeq ($(CI),true)
	docker image save confluentinc/$(IMAGE_NAME):$(IMAGE_VERSION) | gzip | \
		artifact push project /dev/stdin -d docker/$(BRANCH_NAME)/$(IMAGE_VERSION).tgz --force
endif

.PHONY: show-maven
show-maven:
	@echo "MVN:                     $(MVN)"
	@echo "MAVEN_OPTS:              $(MAVEN_OPTS)"
	@echo "MAVEN_ARGS:              $(MAVEN_ARGS)"
	@echo "MAVEN_INSTALL_PROFILES:  $(MAVEN_INSTALL_PROFILES)"
	@echo "MAVEN_DEPLOY_REPO_URL: 	$(MAVEN_DEPLOY_REPO_URL)"

.PHONY: mvn-nanoversion-pip-deps
mvn-nanoversion-pip-deps:
	pip3 show confluent-ci-tools > /dev/null || pip3 install -U confluent-ci-tools

ifeq ($(CI),true)
.PHONY: mvn-bump-nanoversion
## use ci-tools to bump nanoversion
mvn-bump-nanoversion: mvn-nanoversion-pip-deps
	ci-update-version . $(SEMAPHORE_GIT_DIR) --no-update-dependency-versions --update-project-version

mvn-bump-dependency-nanoversion: mvn-nanoversion-pip-deps
## use ci-tools to update dependency nanoversion(mvn versions:use-latest-versions)
	ci-update-version . $(SEMAPHORE_GIT_DIR) --pinned-nano-versions --update-dependency-versions --no-update-project-version

.PHONY: mvn-push-nanoversion-tag
## use ci-tools to push the newest nanoversion tag
mvn-push-nanoversion-tag: mvn-nanoversion-pip-deps
	ci-push-tag . $(SEMAPHORE_GIT_DIR)

.PHONY: mvn-bump-nanoversion-and-push-tag
mvn-bump-nanoversion-and-push-tag: mvn-bump-nanoversion mvn-push-nanoversion-tag
endif
