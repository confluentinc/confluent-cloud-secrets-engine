INIT_CI_TARGETS += linter-metrics-deps
BUILD_TARGETS += openapi api-docs
TEST_TARGETS += api-lint
CLEAN_TARGETS += api-clean

REDOC_VERSION ?= v2.0.0-rc.18
REDOC_CLI_VERSION ?= 0.9.12
PRISM_VERSION ?= 3.1.1
OPENAPI_LINTER_VERSION ?= v0.86.0
SPECCY_VERSION ?= 0.11.0
YAMLLINT_VERSION ?= 1.20
 # no tags in dockerhub for this one, but latest in github is v0.2.8
OPENAPI_SPEC_VALIDATOR_VERSION ?= latest
OPENAPI_GENERATOR_VERSION ?= v5.6.2
MINISPEC_VERSION ?= v0.3.0
 # or "editable" to not use docker, looks for MINISPEC_HOME
MINISPEC_HOME ?= .

JFROG_DOCKER_REPO := confluent-docker.jfrog.io

_docker_opts := --user $(shell id -u):$(shell id -g) --rm
_docker_opts += --volume $(CURDIR):/local

MINISPEC = docker run $(_docker_opts) $(JFROG_DOCKER_REPO)/confluentinc/minispec:$(MINISPEC_VERSION)
MINISPEC_ARGS ?= -vvv

YAMLLINT = docker run $(_docker_opts) cytopia/yamllint:$(YAMLLINT_VERSION)
YAMLLINT_CONF ?= .yamllint

OPENAPI_SPEC_VALIDATOR = docker run $(_docker_opts) p1c2u/openapi-spec-validator:$(OPENAPI_SPEC_VALIDATOR_VERSION)

SPECCY = docker run $(_docker_opts) --workdir /local wework/speccy:$(SPECCY_VERSION)

OPENAPI_LINTER = docker run $(_docker_opts) --workdir /local $(JFROG_DOCKER_REPO)/confluentinc/openapi-linter:$(OPENAPI_LINTER_VERSION)
OPENAPI_LINTER_CONF ?= .spectral.yaml

REDOC = docker run $(_docker_opts) $(JFROG_DOCKER_REPO)/confluentinc/redoc-cli:$(REDOC_CLI_VERSION)
REDOC_THEME_OPTIONS ?= \
	--options.theme.colors.primary.main='\#191924' \
	--options.theme.typography.fontSize='16px' \
	--options.theme.typography.fontWeightRegular='300' \
	--options.theme.typography.fontWeightBold='500' \
	--options.theme.typography.fontWeightLight='200' \
	--options.theme.typography.fontFamily='SF Pro Display, sans-serif' \
	--options.theme.typography.headings.fontFamily='SF Pro Display, sans-serif' \
	--options.theme.typography.headings.fontWeight='bold' \
	--options.theme.typography.headings.lineHeight='22px' \
	--options.theme.typography.headings.color='\#191924' \
	--options.theme.typography.headings.fontSize='32px' \
	--options.theme.typography.code.fontSize='12px' \
	--options.theme.typography.code.fontFamily='SF Mono, monospace, sans-serif' \
	--options.theme.typography.code.lineHeight='18px' \
	--options.theme.typography.code.color='\#142B52' \
	--options.theme.typography.code.backgroundColor='\#F8F8FA' \
	--options.theme.typography.links.color='\#006B95' \
	--options.theme.sidebar.width='287px' \
	--options.theme.sidebar.textColor='\#191924' \
	--options.theme.sidebar.activeTextColor='\#242446' \
	--options.theme.sidebar.arrow.color='\#A8A8B8' \
	--options.theme.sidebar.logo.maxHeight='28.66px' \
	--options.theme.sidebar.logo.maxWidth='28.66px' \
	--options.theme.rightPanel.backgroundColor='\#142B52' \
	--options.theme.schema.nestedBackground='\#FFFFFF' \
	--options.theme.spacing.sectionVertical=20
API_DOC_TITLE ?= API Reference Documentation
REDOC_TEMPLATE ?= mk-include/resources/redoc.hbs
REDOC_OPTIONS ?= --title "$(API_DOC_TITLE)" --template /local/$(REDOC_TEMPLATE) --templateOptions.segmentWriteKey "$(REDOC_SEGMENT_KEY)" $(REDOC_THEME_OPTIONS) 
API_SPEC_FILENAME ?= openapi.yaml
API_NAME ?= $(shell basename $(CURDIR))

PRISM = docker run $(_docker_opts) stoplight/prism:$(PRISM_VERSION)

OPENAPI_GENERATOR = docker run $(_docker_opts) $(JFROG_DOCKER_REPO)/confluentinc/openapi-generator:$(OPENAPI_GENERATOR_VERSION)

.SECONDEXPANSION:

 # $(H) helper to hide the command being run using @, except on CI or if DEBUG is set. Usage: $(H)$(CMD)...
ifneq ($(CI),true)
H := @
endif
ifeq ($(DEBUG),true)
H :=
endif

 # $(OPEN) helper to automatically open a window
ifeq ($(HOST_OS),linux)
OPEN := xdg-open
else
OPEN := open
endif
ifeq ($(shell which $(OPEN)),)
OPEN := @echo Browse to
endif

 # Note: divider blocks and non-doc comments must be indented
 # to avoid showing up in `mmake help` output: https://github.com/tj/mmake

.PHONY: api-resources
api-resources:
	cp mk-include/resources/.yamllint ./.yamllint

.PHONY: api-clean
## Clean all generated artifacts that aren't maintained in Git
api-clean:
	rm -rf $(addsuffix /sdk,$(API_SPEC_DIRS))
	rm -rf $(addsuffix /postman.json,$(API_SPEC_DIRS))
	rm -rf $(addsuffix /loadtest,$(API_SPEC_DIRS))

 #############
 ## OPENAPI ##
 #############

.PHONY: openapi
## Generate OpenAPI from Minispec for all APIs
openapi: $$(addsuffix /$(API_SPEC_FILENAME),$$(API_SPEC_DIRS))

.PHONY: api-spec
## Generate OpenAPI from Minispec for all APIs (alias: 'openapi')
api-spec: openapi

.PRECIOUS: %/$(API_SPEC_FILENAME)
## Generate OpenAPI from Minispec for an API
%/$(API_SPEC_FILENAME): %/minispec.yaml
ifeq ($(MINISPEC_VERSION),editable)
	$(H)cd $(MINISPEC_HOME) && pipenv run ./generator.py $(CURDIR)/$< $(MINISPEC_ARGS) --out $(CURDIR)/$@
else
	$(H)$(MINISPEC) /local/$< $(MINISPEC_ARGS) --out /local/$@
endif

.PHONY: api-lint
## Lint all API specifications with all linters
api-lint: api-lint-yaml api-lint-openapi

.PHONY: api-lint-openapi
## Lint the OpenAPI spec with all linters
api-lint-openapi: api-lint-openapi-spec-validator api-lint-openapi-linter api-lint-break

.PHONY: api-lint-openapi-spec-validator
## Lint the OpenAPI spec using openapi-spec-validator
api-lint-openapi-spec-validator: $$(addsuffix /openapi-spec-validator,$$(API_SPEC_DIRS))

.PHONY: api-lint-yaml
## Lint the OpenAPI spec using yamllint
api-lint-yaml: $$(addsuffix /yamllint,$$(API_SPEC_DIRS))

.PHONY: api-lint-openapi-linter
## Lint the OpenAPI spec using Spectral and custom design guide rules
api-lint-openapi-linter: $$(addsuffix /openapi-linter,$$(API_SPEC_DIRS)) post-openapi-linter-warnings

.PHONY: api-lint-speccy
## (POC) Lint the OpenAPI spec using speccy
api-lint-speccy: $$(addsuffix /speccy,$$(API_SPEC_DIRS))

.PHONY: api-lint-break
ifeq ($(API_LINT_BREAK_OVERRIDE),)
## (POC) Lint the OpenAPI spec for breaking changes
api-lint-break: $$(addsuffix /break,$$(API_SPEC_DIRS))
else
api-lint-break: $(API_LINT_BREAK_OVERRIDE)
endif

.PHONY: %/lint
## Lint an API specification with all linters
%/lint:
	make $*/yamllint $*/openapi-linter $*/break

.PHONY: %/yamllint
## Lint the API against yamllint
%/yamllint:
ifneq ($(wildcard $(YAMLLINT_CONF)),)
	$(YAMLLINT) \
		-f colored \
		-c /local/$(YAMLLINT_CONF) \
		/local/$*
else
	$(warning Create a $(YAMLLINT_CONF) file to enable YAML linting of OpenAPI spec)
endif

.PHONY: %/openapi-spec-validator
## Lint the API against openapi-spec-validation
%/openapi-spec-validator:
	$(OPENAPI_SPEC_VALIDATOR) "/local/$*/$(API_SPEC_FILENAME)"

.PHONY: %/openapi-linter
## Lint the API against Spectral and custom design guide rules
%/openapi-linter: %/$$(API_SPEC_FILENAME) %/$(OPENAPI_LINTER_CONF)
	set -eo pipefail; \
	$(OPENAPI_LINTER) lint \
		-s use-standard-field-types-and-formats \
		-r /local/$*/$(OPENAPI_LINTER_CONF) -f json -q \
		"/local/$*/$(API_SPEC_FILENAME)" | python3 $(MK_INCLUDE_BIN)/linter_metrics.py $(API_NAME) $*/$(API_SPEC_FILENAME) -e $*/$(OPENAPI_LINTER_CONF) | $(MK_INCLUDE_BIN)/openapi-linter-warnings.sh $*/$(API_SPEC_FILENAME)

%/openapi-linter: %/$$(API_SPEC_FILENAME)
ifneq ($(wildcard $(OPENAPI_LINTER_CONF)),)
	set -eo pipefail; \
	$(OPENAPI_LINTER) lint \
		-s use-standard-field-types-and-formats \
		-r /local/$(OPENAPI_LINTER_CONF) -f json -q \
		"/local/$*/$(API_SPEC_FILENAME)" | python3 $(MK_INCLUDE_BIN)/linter_metrics.py $(API_NAME) $*/$(API_SPEC_FILENAME) -e $(OPENAPI_LINTER_CONF) | $(MK_INCLUDE_BIN)/openapi-linter-warnings.sh $*/$(API_SPEC_FILENAME)
else
	set -eo pipefail; \
	$(OPENAPI_LINTER) lint \
		-s use-standard-field-types-and-formats \
		-r /base_rules/base.yml -f json -q \
		"/local/$*/$(API_SPEC_FILENAME)" | python3 $(MK_INCLUDE_BIN)/linter_metrics.py $(API_NAME) $*/$(API_SPEC_FILENAME) | $(MK_INCLUDE_BIN)/openapi-linter-warnings.sh $*/$(API_SPEC_FILENAME)
endif

.PHONY: linter-metrics-deps
linter-metrics-deps:
	pip3 install datadog==0.42.0
	pip3 install pyyaml==5.4.1

.PHONY: post-openapi-linter-warnings
post-openapi-linter-warnings:
ifeq ($(CI),true)
	set -e; \
	if [ ! -f ~/openapi-linter-warnings.txt ]; then \
		exit 0; \
	fi; \
	COMMENT=`cat ~/openapi-linter-warnings.txt`; \
	curl -XPOST https://api.github.com/repos/$${SEMAPHORE_GIT_REPO_SLUG}/issues/$${SEMAPHORE_GIT_PR_NUMBER}/comments \
	-d '{"body": "'"$$COMMENT"'"}' -n -s -H 'Content-type:application/json' > /dev/null; \
	rm ~/openapi-linter-warnings.txt
endif

.PHONY: %/break
%/break: %/$$(API_SPEC_FILENAME)
	$(MK_INCLUDE_BIN)/openapi_break_check.sh $<

 ###########
 ## REDOC ##
 ###########

.PHONY: api-docs
## Generate ReDoc docs for all APIs
api-docs: $$(addsuffix /openapi.html,$$(API_SPEC_DIRS))

## Generate API docs from OpenAPI using ReDoc
## Example: make ccloud/openapi.html API_DOC_TITLE="My HTML Page Title" REDOC_SEGMENT_KEY=ABC123
%/openapi.html: %/$$(API_SPEC_FILENAME) $(REDOC_TEMPLATE)
	$(REDOC) bundle /local/$< \
		--output /local/$@ \
		--cdn \
		$(REDOC_OPTIONS)
ifeq ($(CI),true)
ifeq ($(BRANCH_NAME),$(MASTER_BRANCH))
	artifact push project --force $@
else
	artifact push workflow --force $@
endif
endif

.PHONY: api-redoc-serve
## Serve the ReDoc docs
## This is useful for viewing the docs while iterating on spec development
api-redoc-serve: $$(addsuffix /redoc-serve,$$(lastword $$(API_SPEC_DIRS)))

.PHONY: %/redoc-serve
## Serve the ReDoc docs for an API (in the foreground)
## This is useful for viewing the docs while iterating on spec development
%/redoc-serve: _docker_opts += --init --publish 8080:8080
%/redoc-serve: %/$$(API_SPEC_FILENAME) $(REDOC_TEMPLATE)
	@sleep 3 && $(OPEN) http://localhost:8080
	$(REDOC) serve /local/$< \
		--watch \
		$(REDOC_OPTIONS)

.PHONY: %/redoc-start
## Start the ReDoc server for an API (in the background)
## This is useful for viewing the docs while iterating on spec development
%/redoc-start: _docker_opts += --detach --publish 8080:8080
%/redoc-start: %/$$(API_SPEC_FILENAME) $(REDOC_TEMPLATE)
	@sleep 3 && $(OPEN) http://localhost:8080
	$(REDOC) serve /local/$< $(REDOC_OPTIONS)

.PHONY: %/redoc-stop
## Stop the ReDoc server for an API (in the background)
%/redoc-stop:
	docker stop $(shell docker ps -q -f "ancestor=confluent-docker.jfrog.io/confluentinc/redoc-cli")

 ################
 ## MOCK (POC) ##
 ################

.PHONY: api-mock
## (POC) Run the Prism mock server for an API
api-mock: $$(addsuffix /prism,$$(lastword $$(API_SPEC_DIRS)))

.PHONY: %/prism
## (POC) Run the Prism mock server for an API
%/prism: _docker_opts += --init --publish 4010:4010
%/prism:
	$(PRISM) mock -h 0.0.0.0 "/local/$*/$(API_SPEC_FILENAME)"

 ################
 ## SDKs (POC) ##
 ################

.PHONY: sdk
## (POC) Generate SDKs for all APIs in all languages
sdk: sdk-go sdk-java

.PHONY: sdk-go
## (POC) Generate SDKs for all APIs in Golang
sdk-go: $$(addsuffix /sdk/go,$$(API_SPEC_DIRS))

.PHONY: sdk-java
## (POC) Generate SDKs for all APIs in Java
sdk-java: $$(addsuffix /sdk/java,$$(API_SPEC_DIRS))

## (POC) Generate Golang SDKs for an API
%/sdk/go: %/$$(API_SPEC_FILENAME)
	$(OPENAPI_GENERATOR) generate -g go \
		-i /local/$< -o /local/$@ \
		--package-name $$(sed -n 's,^ *x-api-group: *\(.*/\)*,,p' $<) \
		--generate-alias-as-model \
		--enable-post-process-file \
		--git-user-id confluentinc \
		--git-repo-id ccloud-sdk-go-v2 \
		--additional-properties=useOneOfDiscriminatorLookup=true

## (POC) Generate Java SDKs for an API
%/sdk/java: %/$$(API_SPEC_FILENAME)
	$(OPENAPI_GENERATOR) generate -g java \
		-i /local/$< -o /local/$@ \
		--api-package io.confluent.$*.api \
		--model-package io.confluent.$*.model \
		--invoker-package io.confluent.$*.client \
		--group-id io.confluent --artifact-id $*-java-client

 ###############################
 ## Postman collections (POC) ##
 ###############################

.PHONY: api-postman
## (POC) Generate Postman collection for all APIs
api-postman: $$(addsuffix /postman.json,$$(API_SPEC_DIRS))

## (POC) Generate Postman collection for an API
%/postman.json: %/$$(API_SPEC_FILENAME)
	cd postman && npm install && \
		node node_modules/openapi-to-postmanv2/bin/openapi2postmanv2.js -s ../$*/$(API_SPEC_FILENAME) -o ../$*/postman.json

 ################################
 ## Load Test in Gatling (POC) ##
 ################################

.PHONY: api-loadtest
## (POC) Generate Gatling load test for all APIs
api-loadtest: $$(addsuffix /loadtest,$$(API_SPEC_DIRS))

## (POC) Generate Gatling load test for an API
%/loadtest: %/$$(API_SPEC_FILENAME)
	$(OPENAPI_GENERATOR) generate -i /local/$*/$(API_SPEC_FILENAME) -g scala-gatling -o /local/$*/loadtest