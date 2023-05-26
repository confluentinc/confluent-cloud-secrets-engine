# Addresses to halyard services
HALYARD_DEPLOYER_ADDRESS ?= halyard-deployer.prod.halyard.confluent.cloud:9090
HALYARD_RELEASE_ADDRESS ?= halyard-release.prod.halyard.confluent.cloud:9090
HALYARD_RENDERER_ADDRESS ?= halyard-renderer.prod.halyard.confluent.cloud:9090

# Determine which halyard services to auto bump source version
# List of halyard service files, default all.  All environments in these files will be bumped
HALYARD_SERVICE_FILES ?= $(wildcard .halyard/*.yaml)
# List of halyard service files with environments, defaults none.
# NOTE: This disables HALYARD_SERVICE_FILES, it's either full auto or full manual.
# NOTE: Apply always applies all files in HALYARD_SERVICE_FILES since it won't create new env
#       versions if there's nothing changed.
# Format: .halyard/service.yaml=env1 .halyard/service.yaml=env2 etc.
HALYARD_SERVICE_FILES_ENVS ?=
# Version to set source version to, defaults to current clean version without a v.
HALYARD_SOURCE_VERSION ?= $(BUMPED_CLEAN_VERSION)
# List of service/environments to automatically install on release, defaults none.
# Format: service=env service=env2 service2=env
HALYARD_INSTALL_SERVICE_ENVS ?=
# Cluster type to deploy services via halyard. Value must be be one of 'satellite' or 'mothership'
# If value not specified halyard will traverse thru all clusters which is very inefficient for mothersip services deployment.
HALYARD_INSTALL_CLUSTER_TYPE ?=

# Only create a tmpdir on CI
ifeq ($(CI),true)
# we need ?= to allow overridding HAL_TMPDIR for CPD gating
HAL_TMPDIR ?= $(shell mktemp -d 2>/dev/null || mktemp -d -t 'halyard')
else
# when we aren't running CI, just put output in a temporary directory
HAL_TMPDIR ?= .halctl/tmp
endif
# we need := for immediate assignment rather than deferred.
HAL_TMPDIR := $(HAL_TMPDIR)

# setup halctl cmd
HALYARD_VERSION ?= latest
HALCTL_ARGS ?=
HALYARD_IMAGE ?= confluent-docker.jfrog.io/confluentinc/halyard:$(HALYARD_VERSION)
_halctl_opts := --deployer-address $(HALYARD_DEPLOYER_ADDRESS)
_halctl_opts += --release-address $(HALYARD_RELEASE_ADDRESS)
_halctl_opts += --renderer-address $(HALYARD_RENDERER_ADDRESS)
_halctl_opts += $(HALCTL_ARGS)
_halctl_docker_opts := --user $(shell id -u):$(shell id -g) --rm -t
_halctl_docker_opts += -v $(PWD):/work -v $(HOME)/.halctl:/.halctl -w /work
ifeq ($(CI),true)
_halctl_docker_opts += -v $(HAL_TMPDIR):$(HAL_TMPDIR)
_halctl_docker_opts += --env-file ~/.halyard_secrets
else
_halctl_docker_opts += -e VAULT_TOKEN=$(shell cat $(HOME)/.vault-token)
endif
HALCTL ?= docker run $(_halctl_docker_opts) $(HALYARD_IMAGE) $(_halctl_opts)

# YQ docker image. Inspired by cc-releases
YQ ?= docker run --rm -i -v "${PWD}":/workdir mikefarah/yq

# deploy.sh docker image. Inspired by cc-releases
DEPLOY_SH ?= docker run $(_halctl_docker_opts)  --entrypoint /etc/halyard/scripts/deploy.sh $(HALYARD_IMAGE) -size 100 -apply -retries 6

# variables that allow various makefile targets to be configurable.
#
# HALYARD_AUTO_DEPLOY_ENV => a synonym to HALYARD_INSTALL_SERVICE_ENVS. The reason why we want to define a new synonym is
# to avoid the failure mode where overloading results in unintended side effect due to HALYARD_INSTALL_SERVICE_ENVS being used in other makefile targets
HALYARD_AUTO_DEPLOY_ENV ?=# Defaults to empty str.

# The only Clusters where we want to auto deploy. Cluster IDs should be separated by comma.
HALYARD_AUTO_DEPLOY_CLUSTER_LIST ?=# Defaults to empty str

# HALYARD_STABLE_PREPROD_ENV => a synonym of stag in the current state of the world and in future for control plane, would be stag and for data plane
# would be devel owing to the split pre prod initiative.
# Unlike HALYARD_AUTO_DEPLOY_ENV, this variable is the name of a yaml file corresponding to the stable preprod env within .deployed-services folder.
# This contains contents similar to cc-releases yaml artifact. Developers who want to avoid building new docker images/helm charts are advised to
# use change_in semaphoreci target similar to https://github.com/confluentinc/cc-test-service/pull/52 and https://github.com/confluentinc/cc-spec-connect/pull/301
# Assumes by definition the file is called stag.yaml but the user is free to customize it for multiple targets emanating off .halyard
HALYARD_STABLE_PREPROD_ENV ?= stag.yaml

# The only Clusters where we want to deploy on pre prod. Cluster IDs should be separated by comma.
HALYARD_STABLE_PREPROD_CLUSTER_LIST ?=# Defaults to empty str

# HALYARD_PROD_ENV => Same as above. Except this offers a hook to customize the name prod.yaml and provide the option to define multiple service specs in one repo { monorepo }
HALYARD_PROD_ENV ?= prod.yaml

# The only Clusters where we want to deploy on prod. Cluster IDs should be separated by comma.
HALYARD_PROD_CLUSTER_LIST ?=# Defaults to empty str

# Define a target specific variable that allows us to reuse the implementation for fetching and deploying stable_preprod and prod
HALYARD_ENV_TO_DEPLOY ?=# Empty variable.

# Empty variable that can be hooked into by cc-cpd.mk to set the path to the cpd.yaml
HALYARD_ENV_TO_SET_DEFAULT_VER ?=# Empty variable.

HALYARD_DEPLOYED_VERSIONS_DIR ?= .deployed-versions

INIT_CI_TARGETS += halyard-cache-image
RELEASE_PRECOMMIT += halyard-set-source-version
RELEASE_POSTCOMMIT += halyard-apply-services halyard-install-services

.PHONY: show-halyard
## Show Halyard Variables
show-halyard:
	@echo "HALYARD_SERVICE_FILES:        $(HALYARD_SERVICE_FILES)"
	@echo "HALYARD_SERVICE_FILES_ENVS:   $(HALYARD_SERVICE_FILES_ENVS)"
	@echo "HALYARD_INSTALL_SERVICE_ENVS: $(HALYARD_INSTALL_SERVICE_ENVS)"
	@echo "HALYARD_SOURCE_VERSION:       $(HALYARD_SOURCE_VERSION)"
	@echo "HALCTL:                       $(HALCTL)"
	@echo "HALYARD_AUTO_DEPLOY_ENV:      $(HALYARD_AUTO_DEPLOY_ENV)"
	@echo "HALYARD_STABLE_PREPROD_ENV:   $(HALYARD_STABLE_PREPROD_ENV)"
	@echo "HALYARD_PROD_ENV:             $(HALYARD_PROD_ENV)"
	@echo "HAL_TMPDIR:                   $(HAL_TMPDIR)"
	@echo "DEPLOY_SH:                    $(DEPLOY_SH)"
	@echo "YQ:                           $(YQ)"


# target for caching the halyard docker image on semaphore
.PHONY: halyard-cache-image
halyard-cache-image:
	cache restore $(HALYARD_IMAGE)
	test ! -f halyard-image.tgz || docker load -i halyard-image.tgz
	mv halyard-image.tgz halyard-image-prev.tgz || echo dummy > halyard-image-prev.tgz
	docker pull $(HALYARD_IMAGE) 2>&1 | tee /tmp/cached-halyard-base.log
	cat /tmp/cached-halyard-base.log | grep -q "up to date" || echo "outdated" > /tmp/cached-halyard-base.log

	if [ "$$(cat /tmp/cached-halyard-base.log)" == "outdated" ]; then \
		docker save $(HALYARD_IMAGE) | gzip --no-name > halyard-image.tgz; \
		cache delete $(HALYARD_IMAGE) && cache store $(HALYARD_IMAGE) halyard-image.tgz; \
	fi
	rm -f halyard-image*.tgz

$(HOME)/.halctl:
	mkdir $(HOME)/.halctl

.PHONY: halctl
## Run halctl in the halyard docker image
halctl: $(HOME)/.halctl
	@$(HALCTL) $(HALCTL_ARGS)

.PHONY: halyard-set-source-version
ifeq ($(HALYARD_SERVICE_FILES_ENVS),)
halyard-set-source-version: $(HALYARD_SERVICE_FILES:%=set.%)
else
halyard-set-source-version: $(HALYARD_SERVICE_FILES_ENVS:%=set.%)
endif

.PHONY: $(HALYARD_SERVICE_FILES:%=set.%)
$(HALYARD_SERVICE_FILES:%=set.%): $(HOME)/.halctl
	$(HALCTL) release set-file-version -v $(HALYARD_SOURCE_VERSION) -f $(@:set.%=%)
	git add $(@:set.%=%)

.PHONY: $(HALYARD_SERVICE_FILES_ENVS:%=set.%)
$(HALYARD_SERVICE_FILES_ENVS:%=set.%): $(HOME)/.halctl
	@$(eval fpath := $(word 1,$(subst =, ,$(@:set.%=%))))
	@$(eval env := $(word 2,$(subst =, ,$(@:set.%=%))))
	$(HALCTL) release set-file-version -v $(HALYARD_SOURCE_VERSION) -f $(fpath) -e $(env)
	git add $(fpath)

.PHONY: halyard-apply-services
halyard-apply-services: $(HALYARD_SERVICE_FILES:%=apply.%)

.PHONY: $(HALYARD_SERVICE_FILES:%=apply.%)
$(HALYARD_SERVICE_FILES:%=apply.%): $(HOME)/.halctl
	$(HALCTL) release apply -f $(@:apply.%=%) --output-dir $(HAL_TMPDIR)

cc-releases:
	git clone git@github.com:confluentinc/cc-releases.git

.PHONY: update-cc-releases
update-cc-releases:
	git -C cc-releases checkout master
	git -C cc-releases pull

commit-cc-releases:
	git -C cc-releases diff --exit-code --cached --name-status || \
	(git -C cc-releases commit -m "chore: auto update" && \
	git -C cc-releases push)
	rm -rf cc-releases

.PHONY: halyard-list-service-version
halyard-list-service-version: $(HALYARD_INSTALL_SERVICE_ENVS:%=list.%)

# Retrieve the current running halyard version, for the service/env specified in 'HALYARD_INSTALL_SERVICE_ENVS'.
# The service source version is deteremined by 'git describe --contains', and the retrieved halyard version is saved into $(HAL_TMPDIR)/$(svc)/$(env)
# This target can be used together with halyard-install-services to install service version corresponding to a specific commit.
# E.g. `HALYARD_INSTALL_SERVICE_ENVS=cc-pipeline-service=stag make halyard-list-service-version halyard-install-services` during CI will install the
# current in-release cc-pipeline-service version onto stag environment
.PHONY: $(HALYARD_INSTALL_SERVICE_ENVS:%=list.%)
$(HALYARD_INSTALL_SERVICE_ENVS:%=list.%): $(HOME)/.halctl
	$(eval svc := $(word 1,$(subst =, ,$(@:list.%=%))))
	$(eval env := $(word 2,$(subst =, ,$(@:list.%=%))))
	$(eval src_ver := $(shell git rev-parse --is-inside-work-tree > /dev/null && git describe --contains | grep '^v[0-9]\+.[0-9]\+.[0-9]\+\(~1\)\?$$' | cut -d'~' -f1 | cut -c 2-) )
	@echo "Found source version: $(src_ver)"
	@[[ ! -z "$(src_ver)" ]] || exit 1
	$(eval halyard_ver := $(shell set -o pipefail && $(HALCTL) release service env ver list $(svc) $(env) | grep $(src_ver) | tr -s ' ' | cut -d ' ' -f 2 | tail -1))
	@echo "Found halyard version: $(halyard_ver)"
	@[[ ! -z "$(halyard_ver)" ]] || exit 1
	@mkdir -p $(HAL_TMPDIR)/$(svc)
	echo $(halyard_ver) >> $(HAL_TMPDIR)/$(svc)/$(env)

.PHONY: halyard-wait-service-version
halyard-wait-service-version: halyard-list-service-version $(HALYARD_INSTALL_SERVICE_ENVS:%=wait.%)

# Wait for the source version to be installed, for the service/env specified in 'HALYARD_INSTALL_SERVICE_ENVS'.
# The service source version is deteremined by 'git describe --contains', representing the new version tag commited after a successful 'release-ci'
# If the source version is identified, it periodically queries halyard to wait for the version being succesffully installed on all relevant k8s clusters,
# otherwise it fails after a timeout, currently default to 20 iteration with 30 seconds interval, equals to 10 mins.
# E.g. `HALYARD_INSTALL_SERVICE_ENVS=cc-pipeline-service=devel make halyard-wait-service-version` will wait for current in-release verion to be installed on devel.
.PHONY: $(HALYARD_INSTALL_SERVICE_ENVS:%=wait.%)
$(HALYARD_INSTALL_SERVICE_ENVS:%=wait.%): $(HOME)/.halctl
	$(eval svc := $(word 1,$(subst =, ,$(@:wait.%=%))))
	$(eval env := $(word 2,$(subst =, ,$(@:wait.%=%))))
	$(eval halyard_ver := $(shell cat $(HAL_TMPDIR)/$(svc)/$(env)))
	@LOOP_COUNT=0; LOOP_TOTAL=20; LOOP_INTERVAL=30; \
	until [ $$LOOP_COUNT -eq $$LOOP_TOTAL ] || (echo "waiting halyard version $(halyard_ver) to be installed..." && $(HALCTL) release service env ver get $(svc) $(env) $(halyard_ver) -o json | jq -r .installStatus[].status 2>&1 | grep -v DONE | wc -l | tr -d ' ' | grep '^0$$'); \
	do $(HALCTL) release service env ver get $(svc) $(env) $(halyard_ver) -o json | jq -r .installStatus; (( LOOP_COUNT=LOOP_COUNT+1 )); [ $$LOOP_COUNT -lt $$LOOP_TOTAL ] && echo "still waiting..." && sleep $$LOOP_INTERVAL; done; \
	[ $$LOOP_COUNT -lt $$LOOP_TOTAL ] || (echo "Time out on waiting for version to be installed..." && exit 1)
	@echo "Halyard version $(halyard_ver) is installed"

.PHONY: halyard-install-services
halyard-install-services: cc-releases update-cc-releases $(HALYARD_INSTALL_SERVICE_ENVS:%=install.%) commit-cc-releases

.PHONY: $(HALYARD_INSTALL_SERVICE_ENVS:%=install.%)
$(HALYARD_INSTALL_SERVICE_ENVS:%=install.%): $(HOME)/.halctl
	$(eval svc := $(word 1,$(subst =, ,$(@:install.%=%))))
	$(eval env := $(word 2,$(subst =, ,$(@:install.%=%))))
	$(eval ver := $(shell cat $(HAL_TMPDIR)/$(svc)/$(env)))
	$(HALCTL) release set-file-install-version -v $(ver) -f cc-releases/services/$(svc)/$(env).yaml
	git -C cc-releases add services/$(svc)/$(env).yaml

.PHONY: halyard-cpd-publish-dirty
halyard-cpd-publish-dirty: halyard-set-source-version halyard-apply-services

.PHONY: halyard-cpd-install-dirty
halyard-cpd-install-dirty: $(HALYARD_INSTALL_SERVICE_ENVS:%=cpd.%)

.PHONY: $(HALYARD_INSTALL_SERVICE_ENVS:%=cpd.%)
$(HALYARD_INSTALL_SERVICE_ENVS:%=cpd.%): $(HOME)/.halctl
	@echo "## Ensure the cluster is healthy. Verify the health of all services used to provision a pkc by system tests";
	$(HALCTL) release cluster wait-until-healthy --cluster-id $(CPD_CLUSTER_ID) --services "cc-auth-service,cc-billing-worker,cc-fe,cc-flow-service,cc-gateway-service,cc-marketplace-service,cc-org-service,cc-scheduler-service,mcm-orchestrator,mothership-kafka,ratelimit,spec-kafka,support-service,sync-service" --wait 20m
	@echo "## Installing service in CPD cluster with halyard ⏳⏳⌛️";
	$(eval svc := $(word 1,$(subst =, ,$(@:cpd.%=%))))
	$(eval env := $(word 2,$(subst =, ,$(@:cpd.%=%))))
	@if [ ! -d $(HAL_TMPDIR)/$(svc) ]; then \
		echo "Service name $(svc) is incorrect. By default, SERVICE_NAME in Makefile is used. Pass the correct one by overriding CPD_HALYARD_INSTALL_SERVICE_ENVS"; \
		exit 1; \
	fi
	$(eval ver := $(shell cat $(HAL_TMPDIR)/$(svc)/$(env)))
	$(HALCTL) release service environment version install $(svc) $(env) $(ver) -c $(CPD_CLUSTER_ID)
	@echo "## Checking service status in halyard";
	$(HALCTL) release cluster wait-until-healthy --cluster-id $(CPD_CLUSTER_ID) --services "$(svc)" --wait 15m

.PHONY: halyard-deploy-service
halyard-deploy-service: $(HOME)/.halctl
ifeq ($(HALYARD_INSTALL_CLUSTER_TYPE), )
	@echo "deploy to all clusters, excluding vip clusters"
	$(DEPLOY_SH) -sleep $(sleep) -service $(svc) -env $(env) -version $(ver)
	@svc=$(svc) env=$(env) ver=$(ver) sleep=$(sleep) $(MAKE) $(MAKE_ARGS) halyard-deploy-service-vip
else ifeq ($(HALYARD_INSTALL_CLUSTER_TYPE), "satellite")
	@echo "deploy to satellite clusters, excluding vip clusters"
	$(DEPLOY_SH) -sleep $(sleep) -service $(svc) -env $(env) -version $(ver) -cluster-type satellite
	@svc=$(svc) env=$(env) ver=$(ver) sleep=$(sleep) $(MAKE) $(MAKE_ARGS) halyard-deploy-service-vip
else ifeq ($(HALYARD_INSTALL_CLUSTER_TYPE), "mothership")
	@echo "deploy to mothership clusters"
	$(DEPLOY_SH) -sleep $(sleep) -service $(svc) -env $(env) -version $(ver) -cluster-type mothership
else
	@echo "Invalid cluster type $(HALYARD_INSTALL_CLUSTER_TYPE)"
endif

.PHONY: halyard-deploy-service-vip
halyard-deploy-service-vip: $(HOME)/.halctl
ifeq ($(env),prod)
	@echo "deploy to vip clusters"
	$(DEPLOY_SH) -sleep $(sleep) -service $(svc) -env $(env) -version $(ver) -vip
endif

.PHONY: halyard-auto-deploy-service
halyard-auto-deploy-service: $(HOME)/.halctl
	$(eval localSvc := $(word 1,$(subst =, ,$(HALYARD_AUTO_DEPLOY_ENV))))
	$(eval localEnv := $(word 2,$(subst =, ,$(HALYARD_AUTO_DEPLOY_ENV))))
	$(eval halyard_ver := $(shell set -o pipefail && $(HALCTL) release service env ver list $(localSvc) $(localEnv) | tr -s ' ' | cut -d ' ' -f 2 | tail -n 3 | head -n 1))
	@if [ -z $(HALYARD_AUTO_DEPLOY_CLUSTER_LIST) ]; then \
		echo "Going to deploy $(localSvc) $(localEnv) $(localVer)"; \
		svc=$(localSvc) env=$(localEnv) ver=$(halyard_ver) sleep=0 $(MAKE) $(MAKE_ARGS) halyard-deploy-service; \
	else \
 		echo "Going to deploy $(localSvc) $(localEnv) $(localVer) on clusters $(HALYARD_AUTO_DEPLOY_CLUSTER_LIST)"; \
		svc=$(localSvc) env=$(localEnv) ver=$(halyard_ver) cluster=$(HALYARD_AUTO_DEPLOY_CLUSTER_LIST) $(MAKE) $(MAKE_ARGS) halyard-targeted-deploy; \
	fi;

.PHONY: halyard-deploy-stable-preprod
halyard-deploy-stable-preprod:
	HALYARD_ENV_TO_DEPLOY=$(HALYARD_STABLE_PREPROD_ENV) HALYARD_CLUSTER_TO_DEPLOY=$(HALYARD_STABLE_PREPROD_CLUSTER_LIST) $(MAKE) $(MAKE_ARGS) halyard-deploy-service-from-yaml-artifact

.PHONY: halyard-deploy-prod
halyard-deploy-prod:
	HALYARD_ENV_TO_DEPLOY=$(HALYARD_PROD_ENV) HALYARD_CLUSTER_TO_DEPLOY=$(HALYARD_PROD_CLUSTER_LIST) $(MAKE) $(MAKE_ARGS) halyard-deploy-service-from-yaml-artifact

.PHONY: halyard-deploy-service-from-yaml-artifact
halyard-deploy-service-from-yaml-artifact:
ifneq ($(CI),true)
	@echo "Cannot deploy the contents of $(HALYARD_ENV_TO_DEPLOY) outside of PR'd CI Jobs"
	exit 1
endif
	$(eval localSvc := $(shell cat $(HALYARD_DEPLOYED_VERSIONS_DIR)/$(HALYARD_ENV_TO_DEPLOY) | $(YQ) eval '.data.service' -))
	$(eval localEnv := $(shell cat $(HALYARD_DEPLOYED_VERSIONS_DIR)/$(HALYARD_ENV_TO_DEPLOY) | $(YQ) eval '.data.environment' -))
	$(eval localVer := $(shell cat $(HALYARD_DEPLOYED_VERSIONS_DIR)/$(HALYARD_ENV_TO_DEPLOY) | $(YQ) eval '.data.installedVersion' -))
	@if [ -z $(localVer) ]; then \
		echo "$(HALYARD_ENV_TO_DEPLOY) has empty InstalledVersion. Nothing to deploy. $(localSvc) $(localEnv) $(localVer)"; \
	elif [ -z $(HALYARD_CLUSTER_TO_DEPLOY) ]; then \
		echo "Going to deploy $(localSvc) $(localEnv) $(localVer)"; \
		svc=$(localSvc) env=$(localEnv) ver=$(localVer) sleep=0 $(MAKE) $(MAKE_ARGS) halyard-deploy-service; \
	else \
 		echo "Going to deploy $(localSvc) $(localEnv) $(localVer) on clusters $(HALYARD_ENV_TO_DEPLOY)"; \
		svc=$(localSvc) env=$(localEnv) ver=$(localVer) cluster=$(HALYARD_CLUSTER_TO_DEPLOY) $(MAKE) $(MAKE_ARGS) halyard-targeted-deploy; \
	fi;

.PHONY: halyard-targeted-deploy
halyard-targeted-deploy: $(HOME)/.halctl
	@echo "Deploy $(svc) version $(ver) to the $(env) clusters $(cluster)"
	$(HALCTL) release service environment version install $(svc) $(env) $(ver) -c $(cluster)
	@echo "Set $(svc) version $(ver) as the default version in $(env)"
	$(HALCTL) release service environment version set-default $(svc) $(env) $(ver)

.PHONY: halyard-deploy-cpd
halyard-deploy-cpd:
	$(MAKE) $(MAKE_ARGS) halyard-set-default-version-cpd

.PHONY: halyard-set-default-version
halyard-set-default-version: $(HOME)/.halctl
	$(eval localSvc := $(shell cat $(HALYARD_DEPLOYED_VERSIONS_DIR)/$(HALYARD_ENV_TO_SET_DEFAULT_VER) | $(YQ) eval '.data.service' -))
	$(eval localEnv := $(shell cat $(HALYARD_DEPLOYED_VERSIONS_DIR)/$(HALYARD_ENV_TO_SET_DEFAULT_VER) | $(YQ) eval '.data.environment' -))
	$(eval localVer := $(shell cat $(HALYARD_DEPLOYED_VERSIONS_DIR)/$(HALYARD_ENV_TO_SET_DEFAULT_VER) | $(YQ) eval '.data.installedVersion' -))
	@if [ ! -z $(localVer) ]; then \
		echo "Going to set $(localSvc) $(localVer) as default version on $(localEnv) "; \
		$(HALCTL) release service environment version set-default $(localSvc) $(localEnv) $(localVer); \
	else \
		echo "$(HALYARD_DEPLOYED_VERSIONS_DIR)/$(HALYARD_ENV_TO_SET_DEFAULT_VER) has empty InstalledVersion. Nothing to set as default version for $(localSvc) on $(localEnv)"; \
	fi;
